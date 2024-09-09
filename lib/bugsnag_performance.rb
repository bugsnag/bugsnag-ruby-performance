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
require_relative "bugsnag_performance/internal/parsed_tracestate"
require_relative "bugsnag_performance/internal/tracestate_parser"
require_relative "bugsnag_performance/internal/probability_fetcher"
require_relative "bugsnag_performance/internal/probability_manager"
require_relative "bugsnag_performance/internal/configuration_validator"
require_relative "bugsnag_performance/internal/sampling_header_encoder"
require_relative "bugsnag_performance/internal/nil_errors_configuration"
require_relative "bugsnag_performance/internal/probability_attribute_span_processor"

module BugsnagPerformance
  # Configure BugSnag Performance
  #
  # Yields a {Configuration} object to use to set application settings.
  #
  # @yieldparam configuration [Configuration]
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
    sampler = Internal::Sampler.new(probability_manager, Internal::TracestateParser.new)

    exporter = Internal::SpanExporter.new(
      configuration.logger,
      probability_manager,
      delivery,
      sampler,
      Internal::PayloadEncoder.new,
      Internal::SamplingHeaderEncoder.new,
    )

    # enter unmanaged mode if the OTel sampler environment variable has been set
    # note: we assume any value means a non-default sampler will be used because
    #       we don't control what the valid values are
    user_has_custom_sampler = ENV.key?("OTEL_TRACES_SAMPLER")
    exporter.unmanaged_mode! if user_has_custom_sampler

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

      # ensure the "bugsnag.sampling.p" attribute is set on all spans even when
      # our sampler is not in use
      otel_configurator.add_span_processor(
        Internal::ProbabilityAttributeSpanProcessor.new(probability_manager)
      )
    end

    # don't use our sampler if the user has configured a sampler via the OTel
    # environment variable
    # note: the user can still replace our sampler with their own after this
    OpenTelemetry.tracer_provider.sampler = sampler unless user_has_custom_sampler

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
