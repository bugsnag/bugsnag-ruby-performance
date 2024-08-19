# frozen_string_literal: true

RSpec.describe BugsnagPerformance::ConfigurationValidator do
  subject { BugsnagPerformance::ConfigurationValidator }

  let(:configuration) do
    BugsnagPerformance::Configuration.new(BugsnagPerformance::NilErrorsConfiguration.new).tap do |configuration|
      configuration.api_key = "abcdef1234567890abcdef1234567890"
    end
  end

  it "is valid by default" do
    result = subject.validate(configuration)

    expect(result.messages).to be_empty
    expect(result.valid?).to be(true)
    expect(result.configuration.api_key).to be("abcdef1234567890abcdef1234567890")
  end

  context "open telemetry configure block" do
    it "passes validation when set to a valid value" do
      configuration_proc = proc { |c| 1 + 1 }

      configuration.configure_open_telemetry(&configuration_proc)
      result = subject.validate(configuration)

      expect(result.messages).to be_empty
      expect(result.valid?).to be(true)
      expect(result.configuration.open_telemetry_configure_block.call).to eq(2)
    end

    it "fails validation when set to an invalid value" do
      called = false

      configuration.configure_open_telemetry { |a, b| called = true }
      result = subject.validate(configuration)

      expect(result.messages).to eq(["configure_open_telemetry requires a callable with an arity of 1"])
      expect(result.valid?).to be(false)

      result.configuration.open_telemetry_configure_block.call
      expect(called).to be(false)
    end

    it "fails validation when set to an invalid type" do
      configuration.configure_open_telemetry
      result = subject.validate(configuration)

      expect(result.messages).to eq(["configure_open_telemetry requires a callable with an arity of 1"])
      expect(result.valid?).to be(false)
      expect(result.configuration.open_telemetry_configure_block).not_to be_nil
      expect { result.configuration.open_telemetry_configure_block.call }.not_to raise_error
    end
  end

  context "logger" do
    it "passes validation when set to a valid value" do
      logger = ::Logger.new($stdout)

      configuration.logger = logger
      result = subject.validate(configuration)

      expect(result.messages).to be_empty
      expect(result.valid?).to be(true)
      expect(result.configuration.logger).to be_a(BugsnagPerformance::LoggerWrapper)
      expect(result.configuration.logger.logger).to be(logger)
    end

    it "fails validation when set to an invalid type" do
      logger = Object.new

      configuration.logger = logger
      result = subject.validate(configuration)

      expect(result.messages.first).to match(/\Alogger should be a ::Logger, got #<Object:.+>\z/)
      expect(result.messages.length).to be(1)
      expect(result.valid?).to be(false)
      expect(result.configuration.logger).to be_a(BugsnagPerformance::LoggerWrapper)
      expect(result.configuration.logger.logger).to be(OpenTelemetry.logger)
    end
  end

  context "API key" do
    let(:configuration) { BugsnagPerformance::Configuration.new(BugsnagPerformance::NilErrorsConfiguration.new) }

    it "passes validation when set to a valid value" do
      configuration.api_key = "abcdef1234567890abcdef1234567890"
      result = subject.validate(configuration)

      expect(result.messages).to be_empty
      expect(result.valid?).to be(true)
      expect(result.configuration.api_key).to be("abcdef1234567890abcdef1234567890")
    end

    it "fails validation when set to an invalid value" do
      configuration.api_key = "oh no im not an api key :o"
      result = subject.validate(configuration)

      expect(result.messages).to eq([
        'api_key should be a 32 character hexadecimal string, got "oh no im not an api key :o"',
      ])

      expect(result.valid?).to be(false)
      expect(result.configuration.api_key).to be("oh no im not an api key :o")
    end

    it "fails validation when set to an invalid type" do
      configuration.api_key = 1234
      result = subject.validate(configuration)

      expect(result.messages).to eq([
        "api_key should be a 32 character hexadecimal string, got 1234",
      ])

      expect(result.valid?).to be(false)
      expect(result.configuration.api_key).to be(1234)
    end

    it "raises when not set" do
      expect { subject.validate(configuration) }.to raise_error(
        BugsnagPerformance::ConfigurationValidator::MissingApiKeyError,
        "No Bugsnag API Key set",
      )
    end
  end

  context "app version" do
    it "passes validation when set to a valid value" do
      configuration.app_version = "1.2.3"
      result = subject.validate(configuration)

      expect(result.messages).to be_empty
      expect(result.valid?).to be(true)
      expect(result.configuration.app_version).to be("1.2.3")
    end

    it "fails validation when set to an invalid value" do
      configuration.app_version = ""
      result = subject.validate(configuration)

      expect(result.messages).to eq([
        'app_version should be a non-empty string, got ""',
      ])

      expect(result.valid?).to be(false)
      expect(result.configuration.app_version).to be_nil
    end

    it "fails validation when set to an invalid type" do
      configuration.app_version = ["1", "2", "3"]
      result = subject.validate(configuration)

      expect(result.messages).to eq([
        'app_version should be a non-empty string, got ["1", "2", "3"]',
      ])

      expect(result.valid?).to be(false)
      expect(result.configuration.app_version).to be_nil
    end
  end

  context "release stage" do
    it "is optional" do
      expect(subject.validate(configuration).valid?).to be(true)

      configuration.release_stage = nil

      expect(subject.validate(configuration).valid?).to be(true)
    end

    it "passes validation when set to a valid value" do
      configuration.release_stage = "production"
      result = subject.validate(configuration)

      expect(result.messages).to be_empty
      expect(result.valid?).to be(true)
      expect(result.configuration.release_stage).to be("production")
    end

    it "fails validation when set to an invalid value" do
      configuration.release_stage = ""
      result = subject.validate(configuration)

      expect(result.messages).to eq([
        'release_stage should be a non-empty string, got ""',
      ])

      expect(result.valid?).to be(false)
      expect(result.configuration.release_stage).to be("production")
    end

    it "fails validation when set to an invalid type" do
      configuration.release_stage = ["p", "r", "o", "d"]
      result = subject.validate(configuration)

      expect(result.messages).to eq([
        'release_stage should be a non-empty string, got ["p", "r", "o", "d"]',
      ])

      expect(result.valid?).to be(false)
      expect(result.configuration.release_stage).to be("production")
    end
  end

  context "enabled release stages" do
    it "is optional" do
      expect(subject.validate(configuration).valid?).to be(true)

      configuration.enabled_release_stages = nil

      expect(subject.validate(configuration).valid?).to be(true)
    end

    it "passes validation when set to a valid value" do
      configuration.enabled_release_stages = ["production"]
      result = subject.validate(configuration)

      expect(result.messages).to be_empty
      expect(result.valid?).to be(true)
      expect(result.configuration.enabled_release_stages).to eq(["production"])
    end

    it "fails validation when set to an invalid type" do
      configuration.enabled_release_stages = true
      result = subject.validate(configuration)

      expect(result.messages).to eq([
        "enabled_release_stages should be an array of non-empty strings, got true",
      ])

      expect(result.valid?).to be(false)
      expect(result.configuration.enabled_release_stages).to be_nil
    end
  end

  context "use managed quota" do
    it "is required" do
      configuration.use_managed_quota = nil
      result = subject.validate(configuration)

      expect(result.messages).to eq([
        "use_managed_quota should be a boolean, got nil",
      ])

      expect(result.valid?).to be(false)
      expect(result.configuration.use_managed_quota).to be(true)
    end

    it "passes validation when set to a valid value" do
      configuration.use_managed_quota = false
      result = subject.validate(configuration)

      expect(result.messages).to be_empty
      expect(result.valid?).to be(true)
      expect(result.configuration.use_managed_quota).to be(false)
    end

    it "fails validation when set to an invalid type" do
      configuration.use_managed_quota = "falsey"
      result = subject.validate(configuration)

      expect(result.messages).to eq([
        'use_managed_quota should be a boolean, got "falsey"',
      ])

      expect(result.valid?).to be(false)
      expect(result.configuration.use_managed_quota).to be(true)
    end
  end

  context "endpoint" do
    it "is required" do
      configuration.endpoint = nil
      result = subject.validate(configuration)

      expect(result.messages).to eq([
        "endpoint should be a valid URL, got nil",
      ])

      expect(result.valid?).to be(false)
      expect(result.send_traces?).to be(false)
      expect(result.configuration.endpoint).to be_nil
    end

    it "passes validation when set to a valid value" do
      configuration.endpoint = "https://localhost:3000"
      result = subject.validate(configuration)

      expect(result.messages).to be_empty
      expect(result.valid?).to be(true)
      expect(result.send_traces?).to be(true)
      expect(result.configuration.endpoint).to be("https://localhost:3000")
    end

    it "fails validation when set to an invalid type" do
      configuration.endpoint = true
      result = subject.validate(configuration)

      expect(result.messages).to eq([
        "endpoint should be a valid URL, got true",
      ])

      expect(result.valid?).to be(false)
      expect(result.send_traces?).to be(false)
      expect(result.configuration.endpoint).to be(true)
    end

    it "fails validation when set to an invalid value" do
      configuration.endpoint = ""
      result = subject.validate(configuration)

      expect(result.messages).to eq([
        'endpoint should be a valid URL, got ""',
      ])

      expect(result.valid?).to be(false)
      expect(result.send_traces?).to be(false)
      expect(result.configuration.endpoint).to eq("")
    end
  end
end
