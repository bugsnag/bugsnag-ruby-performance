# frozen_string_literal: true

module BugsnagPerformance
  class ConfigurationValidator
    def self.validate(configuration)
      new(configuration).validate
    end

    def validate
      raise MissingApiKeyError.new if @configuration.api_key.nil?

      validate_open_telemetry_configure_block
      validate_logger
      validate_api_key
      validate_string(:app_version, optional: true)
      validate_string(:release_stage, optional: true)
      validate_array(:enabled_release_stages, "non-empty strings", optional: true, &method(:valid_string?))
      validate_boolean(:use_managed_quota, optional: false)
      valid_endpoint = validate_endpoint

      # if the endpoint is invalid then we shouldn't attempt to send traces
      Result.new(@messages, @valid_configuration, send_traces: valid_endpoint)
    end

    private

    def initialize(configuration)
      @configuration = configuration
      @valid_configuration = BugsnagPerformance::Configuration.new(BugsnagPerformance::NilErrorsConfiguration.new)
      @messages = []
    end

    def validate_open_telemetry_configure_block
      value = @configuration.open_telemetry_configure_block

      return if value.respond_to?(:call) && value.arity == 1

      @messages << "configure_open_telemetry requires a callable with an arity of 1"
    end

    def validate_logger
      value = @configuration.logger

      if value.is_a?(::Logger)
        @valid_configuration.logger = value
      else
        @messages << "logger should be a ::Logger, got #{value.inspect}"
      end
    end

    def validate_api_key
      value = @configuration.api_key

      # we always use the provided API key even if it's invalid
      @valid_configuration.api_key = value

      return if value.is_a?(String) && value =~ /\A[0-9a-f]{32}\z/i

      @messages << "api_key should be a 32 character hexadecimal string, got #{value.inspect}"
    end

    def validate_string(name, optional:)
      value = @configuration.send(name)

      if (value.nil? && optional) || valid_string?(value)
        @valid_configuration.send("#{name}=", value)
      else
        @messages << "#{name} should be a non-empty string, got #{value.inspect}"
      end
    end

    def validate_boolean(name, optional:)
      value = @configuration.send(name)

      if (value.nil? && optional) || value == true || value == false
        @valid_configuration.send("#{name}=", value)
      else
        @messages << "#{name} should be a boolean, got #{value.inspect}"
      end
    end

    def validate_array(name, description, optional:, &block)
      value = @configuration.send(name)

      if (value.nil? && optional) || value.is_a?(Array) && value.all?(&block)
        @valid_configuration.send("#{name}=", value)
      else
        @messages << "#{name} should be an array of #{description}, got #{value.inspect}"
      end
    end

    def validate_endpoint
      value = @configuration.endpoint

      # we always use the provided endpoint even if it's invalid to prevent
      # leaking data to the saas bugsnag instance
      @valid_configuration.endpoint = value

      if valid_string?(value)
        true
      else
        @messages << "endpoint should be a valid URL, got #{value.inspect}"

        false
      end
    end

    def valid_string?(value)
      value.is_a?(String) && !value.empty?
    end

    class MissingApiKeyError < Error
      def initialize
        super("No Bugsnag API Key set")
      end
    end

    class Result
      attr_reader :messages
      attr_reader :configuration

      def initialize(messages, configuration, send_traces:)
        @messages = messages
        @configuration = configuration.freeze
        @send_traces = send_traces
      end

      def valid?
        @messages.empty?
      end

      def send_traces?
        @send_traces
      end
    end
  end
end
