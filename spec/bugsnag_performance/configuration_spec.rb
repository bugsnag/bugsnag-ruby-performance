# frozen_string_literal: true

class FakeBugsnagErrorsConfiguration < BugsnagPerformance::Internal::NilErrorsConfiguration
  def initialize(
    logger: nil,
    api_key: nil,
    app_version: nil,
    release_stage: nil,
    enabled_release_stages: nil
  )
    @logger = logger
    @api_key = api_key
    @app_version = app_version
    @release_stage = release_stage
    @enabled_release_stages = enabled_release_stages
  end
end

RSpec.describe BugsnagPerformance::Configuration do
  subject { BugsnagPerformance::Configuration.new(BugsnagPerformance::Internal::NilErrorsConfiguration.new) }

  context "configure_open_telemetry" do
    it "is callable by default" do
      expect(subject.open_telemetry_configure_block).to respond_to(:call)
      expect { subject.open_telemetry_configure_block.call }.not_to raise_error
    end

    it "can be configured" do
      block = spy('configure_open_telemetry block')

      # passing '&block' here raises an error so we wrap it in another block
      subject.configure_open_telemetry { block.call }
      expect(block).not_to have_received(:call)

      subject.open_telemetry_configure_block.call
      expect(block).to have_received(:call)
    end
  end

  context "logger" do
    it "is OpenTelemetry's logger by default" do
      expect(subject.logger).to be_a(BugsnagPerformance::Internal::LoggerWrapper)
      expect(subject.logger.logger).to be(OpenTelemetry.logger)
    end

    it "reads from bugsnag errors if present" do
      logger = ::Logger.new($stdout)

      configuration = BugsnagPerformance::Configuration.new(
        FakeBugsnagErrorsConfiguration.new(logger: logger)
      )

      expect(configuration.logger).to be_a(BugsnagPerformance::Internal::LoggerWrapper)
      expect(configuration.logger.logger).to be(logger)
    end

    it "doesn't wrap a logger that has already been wrapped" do
      logger = ::Logger.new($stdout)
      logger_wrapper = BugsnagPerformance::Internal::LoggerWrapper.new(logger)

      subject.logger = logger_wrapper

      expect(subject.logger).to be(logger_wrapper)
      expect(subject.logger.logger).to be(logger)
    end
  end

  context "API key" do
    it "is nil by default" do
      expect(subject.api_key).to be_nil
    end

    it "can be set to a valid value" do
      api_key = "abcdef1234567890abcdef1234567890"

      subject.api_key = api_key

      expect(subject.api_key).to eq(api_key)
    end

    it "reads from the performance environment variable" do
      api_key = "aacdef1234567890abcdef1234567890"

      with_environment_variable("BUGSNAG_PERFORMANCE_API_KEY", api_key) do
        expect(subject.api_key).to eq(api_key)
      end
    end

    it "reads from bugsnag errors if present" do
      api_key = "abcdef1234567890abcdef1234567899"

      configuration = BugsnagPerformance::Configuration.new(
        FakeBugsnagErrorsConfiguration.new(api_key: api_key)
      )

      expect(configuration.api_key).to eq(api_key)
    end

    it "reads from the performance environment variable before bugsnag errors" do
      environment_api_key = "00000000000000000000000000000000"
      errors_api_key = "abcdef1234567890abcdef1234567899"

      with_environment_variable("BUGSNAG_PERFORMANCE_API_KEY", environment_api_key) do
        configuration = BugsnagPerformance::Configuration.new(
          FakeBugsnagErrorsConfiguration.new(api_key: errors_api_key)
        )

        expect(configuration.api_key).to eq(environment_api_key)
      end
    end
  end

  context "app version" do
    it "is nil by default" do
      expect(subject.app_version).to be_nil
    end

    it "can be set to a valid value" do
      app_version = "1.2.3"

      subject.app_version = app_version

      expect(subject.app_version).to eq(app_version)
    end

    it "reads from bugsnag errors if present" do
      app_version = "9.1.2"

      configuration = BugsnagPerformance::Configuration.new(
        FakeBugsnagErrorsConfiguration.new(app_version: app_version)
      )

      expect(configuration.app_version).to eq(app_version)
    end
  end

  context "release stage" do
    it "is 'production' by default" do
      expect(subject.release_stage).to eq("production")
    end

    it "can be set to a valid value" do
      release_stage = "staging"

      subject.release_stage = release_stage

      expect(subject.release_stage).to eq(release_stage)
    end

    it "reads from the performance environment variable" do
      release_stage = "staging"

      with_environment_variable("BUGSNAG_PERFORMANCE_RELEASE_STAGE", release_stage) do
        expect(subject.release_stage).to eq(release_stage)
      end
    end

    it "reads from bugsnag errors if present" do
      release_stage = "development"

      configuration = BugsnagPerformance::Configuration.new(
        FakeBugsnagErrorsConfiguration.new(release_stage: release_stage)
      )

      expect(configuration.release_stage).to eq(release_stage)
    end

    it "reads from the performance environment variable before bugsnag errors" do
      environment_release_stage = "development"
      errors_release_stage = "staging"

      with_environment_variable("BUGSNAG_PERFORMANCE_RELEASE_STAGE", environment_release_stage) do
        configuration = BugsnagPerformance::Configuration.new(
          FakeBugsnagErrorsConfiguration.new(release_stage: errors_release_stage)
        )

        expect(configuration.release_stage).to eq(environment_release_stage)
      end
    end
  end

  context "enabled release stages" do
    it "is nil by default" do
      expect(subject.enabled_release_stages).to be_nil
    end

    it "can be set to a valid value" do
      enabled_release_stages = ["staging", "development"]

      subject.enabled_release_stages = enabled_release_stages

      expect(subject.enabled_release_stages).to eq(enabled_release_stages)
    end

    it "reads from the performance environment variable" do
      with_environment_variable("BUGSNAG_PERFORMANCE_ENABLED_RELEASE_STAGES", "staging,qa") do
        expect(subject.enabled_release_stages).to eq(["staging", "qa"])
      end
    end

    it "strips whitespace from the performance environment variable" do
      with_environment_variable("BUGSNAG_PERFORMANCE_ENABLED_RELEASE_STAGES", "  production,  staging ") do
        expect(subject.enabled_release_stages).to eq(["production", "staging"])
      end
    end

    it "reads from bugsnag errors if present" do
      enabled_release_stages = ["development", "test"]

      configuration = BugsnagPerformance::Configuration.new(
        FakeBugsnagErrorsConfiguration.new(enabled_release_stages: enabled_release_stages)
      )

      expect(configuration.enabled_release_stages).to eq(enabled_release_stages)
    end

    it "reads from the performance environment variable before bugsnag errors" do
      environment_release_stages = "development, staging, production"
      errors_release_stages = ["staging", "test"]

      with_environment_variable("BUGSNAG_PERFORMANCE_ENABLED_RELEASE_STAGES", environment_release_stages) do
        configuration = BugsnagPerformance::Configuration.new(
          FakeBugsnagErrorsConfiguration.new(enabled_release_stages: errors_release_stages)
        )

        expect(configuration.enabled_release_stages).to eq(["development", "staging", "production"])
      end
    end
  end

  context "endpoint" do
    it "is nil if API key is not set" do
      expect(subject.endpoint).to be_nil
    end

    it "is nil if set to nil" do
      subject.api_key = "1234567890abcdef1234567890abcdef"
      subject.endpoint = nil

      expect(subject.endpoint).to be_nil
    end

    it "is the default URL if API key is set" do
      subject.api_key = "1234567890abcdef1234567890abcdef"

      expect(subject.endpoint).to eq("https://#{subject.api_key}.otlp.bugsnag.com/v1/traces")
    end

    it "can be set to a valid value" do
      endpoint = "https://example.com/traces"

      subject.endpoint = endpoint

      expect(subject.endpoint).to eq(endpoint)
    end
  end

  context "use managed quota" do
    it "is 'true' by default" do
      expect(subject.use_managed_quota).to eq(true)
    end

    it "can be set to a valid value" do
      use_managed_quota = false

      subject.use_managed_quota = use_managed_quota

      expect(subject.use_managed_quota).to eq(use_managed_quota)
    end
  end
end
