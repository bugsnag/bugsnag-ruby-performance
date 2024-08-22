# frozen_string_literal: true

module BugsnagPerformance
  class Configuration
    attr_reader :open_telemetry_configure_block
    attr_reader :logger

    attr_accessor :api_key
    attr_accessor :app_version
    attr_accessor :release_stage
    attr_accessor :enabled_release_stages

    attr_writer :endpoint

    def initialize(errors_configuration)
      @open_telemetry_configure_block = proc { |c| }
      self.logger = errors_configuration.logger || OpenTelemetry.logger

      @api_key = fetch(errors_configuration, :api_key, env: "BUGSNAG_PERFORMANCE_API_KEY")
      @app_version = fetch(errors_configuration, :app_version)
      @release_stage = fetch(errors_configuration, :release_stage, env: "BUGSNAG_PERFORMANCE_RELEASE_STAGE", default: "production")

      @enabled_release_stages = fetch(errors_configuration, :enabled_release_stages, env: "BUGSNAG_PERFORMANCE_ENABLED_RELEASE_STAGES")

      # transform enabled release stages into an array if we read its value from
      # the environment
      if @enabled_release_stages.is_a?(String)
        @enabled_release_stages = @enabled_release_stages.split(",").map(&:strip)
      end
    end

    def logger=(logger)
      @logger =
        if logger.is_a?(Internal::LoggerWrapper)
          logger
        else
          Internal::LoggerWrapper.new(logger)
        end
    end

    def endpoint
      case
      when defined?(@endpoint)
        # if a custom endpoint has been set then use it directly
        @endpoint
      when @api_key.nil?
        # if there's no API key then we can't construct the default URL
        nil
      else
        "https://#{@api_key}.otlp.bugsnag.com/v1/traces"
      end
    end

    def configure_open_telemetry(&open_telemetry_configure_block)
      @open_telemetry_configure_block = open_telemetry_configure_block
    end

    private

    def fetch(
      errors_configuration,
      name,
      env: nil,
      default: nil
    )
      if env
        value = ENV[env]

        return value unless value.nil?
      end

      value = errors_configuration.send(name)
      return value unless value.nil?

      default
    end
  end
end
