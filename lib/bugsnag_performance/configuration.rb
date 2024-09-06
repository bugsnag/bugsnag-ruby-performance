# frozen_string_literal: true

module BugsnagPerformance
  class Configuration
    # @api private
    attr_reader :open_telemetry_configure_block

    # The logger Bugsnag performance will write messages to
    #
    # If not set, this will default to the Bugsnag Errors logger or the Open
    # Telemetry SDK logger
    #
    # @return [Logger]
    attr_reader :logger

    # Your Bugsnag API Key
    #
    # If not set, this will be read from the "BUGSNAG_PERFORMANCE_API_KEY" and
    # "BUGSNAG_API_KEY" environment variables or Bugsnag Errors configuration.
    # If none of these returns an API key, a {MissingApiKeyError} will be raised
    #
    # @return [String, nil]
    attr_accessor :api_key

    # The current version of the application, for example "1.2.3"
    #
    # If not set, this will be read from the "BUGSNAG_PERFORMANCE_APP_VERSION"
    # and "BUGSNAG_APP_VERSION" environment variables or Bugsnag Errors
    # configuration
    #
    # @return [String]
    attr_accessor :app_version

    # The current stage of the release process, for example "development" or "production"
    #
    # If not set, this will be read from the "BUGSNAG_PERFORMANCE_RELEASE_STAGE"
    # and "BUGSNAG_RELEASE_STAGE" environment variables or Bugsnag Errors
    # configuration and defaults to "production"
    #
    # @return [String]
    attr_accessor :release_stage

    # Which release stages to send traces for, for example ["staging", production"]
    #
    # If not set, this will be read from the "BUGSNAG_PERFORMANCE_ENABLED_RELEASE_STAGES"
    # and "BUGSNAG_ENABLED_RELEASE_STAGES" environment variables or Bugsnag Errors
    # configuration and defaults to allow any release stage
    #
    # @return [Array<String>, nil]
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

    # The URL to send traces to
    #
    # If not set this defaults to "https://<api_key>/otlp.bugsnag.com/v1/traces"
    #
    # @return [String, nil]
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

    # Apply configuration for the Open Telemetry SDK
    #
    # This block should *replace* any calls to OpenTelemetry::SDK.configure
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
