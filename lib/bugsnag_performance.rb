# frozen_string_literal: true

require "json"
require "time"
require "timeout"
require "net/http"
require "concurrent-ruby"
require "opentelemetry-sdk"

require_relative "bugsnag_performance/error"
require_relative "bugsnag_performance/version"
require_relative "bugsnag_performance/configuration"

require_relative "bugsnag_performance/internal/task"
require_relative "bugsnag_performance/internal/sampler"
require_relative "bugsnag_performance/internal/delivery"
require_relative "bugsnag_performance/internal/span_exporter"
require_relative "bugsnag_performance/internal/logger_wrapper"
require_relative "bugsnag_performance/internal/task_scheduler"
require_relative "bugsnag_performance/internal/payload_encoder"
require_relative "bugsnag_performance/internal/probability_fetcher"
require_relative "bugsnag_performance/internal/probability_manager"
require_relative "bugsnag_performance/internal/configuration_validator"
require_relative "bugsnag_performance/internal/sampling_header_encoder"
require_relative "bugsnag_performance/internal/nil_errors_configuration"

module BugsnagPerformance
  def self.configure(&block)
    unvalidated_configuration = Configuration.new(load_bugsnag_errors_configuration)

    block.call(unvalidated_configuration) unless block.nil?

    result = Internal::ConfigurationValidator.validate(unvalidated_configuration)
    configuration = result.configuration

    log_validation_messages(configuration.logger, result.messages) unless result.valid?

    delivery = Internal::Delivery.new(configuration)
    task_scheduler = Internal::TaskScheduler.new
    probability_fetcher = Internal::ProbabilityFetcher.new(configuration.logger, delivery, task_scheduler)
    probability_manager = Internal::ProbabilityManager.new(probability_fetcher)
    sampler = Internal::Sampler.new(probability_manager)

    exporter = Internal::SpanExporter.new(
      configuration.logger,
      probability_manager,
      delivery,
      Internal::PayloadEncoder.new(sampler),
      Internal::SamplingHeaderEncoder.new,
    )

    if configuration.enabled_release_stages && !configuration.enabled_release_stages.include?(configuration.release_stage)
      configuration.logger.info("Not exporting spans as the current release stage is not in the enabled release stages.")
      exporter.disable!
    end

    # return the result of the user's configuration block so we don't change
    # any existing behaviour
    return_value = nil

    OpenTelemetry::SDK.configure do |otel_configurator|
      # call the user's OTel configuration block
      return_value = configuration.open_telemetry_configure_block.call(otel_configurator)

      # add app version and release stage as the 'service.version' and
      # 'deployment.environment' resource attributes
      if app_version = configuration.app_version
        otel_configurator.service_version = app_version
      end

      otel_configurator.resource = OpenTelemetry::SDK::Resources::Resource.create(
        OpenTelemetry::SemanticConventions::Resource::DEPLOYMENT_ENVIRONMENT => configuration.release_stage
      )

      # add batch processor with bugsnag exporter to send payloads
      otel_configurator.add_span_processor(
        OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(exporter)
      )
    end

    # use our sampler
    OpenTelemetry.tracer_provider.sampler = sampler

    return_value
  end

  private

  def self.load_bugsnag_errors_configuration
    # try to require bugsnag errors and use its configuration
    require "bugsnag"

    Bugsnag.configuration
  rescue LoadError
    # bugsnag errors is not installed
    Internal::NilErrorsConfiguration.new
  end

  def self.log_validation_messages(logger, messages)
    if messages.length == 1
      logger.warn("Invalid configuration. #{messages.first}")
    else
      logger.warn(
        <<~MESSAGE
          Invalid configuration:
            - #{messages.join("\n  - ")}
        MESSAGE
      )
    end
  end
end
