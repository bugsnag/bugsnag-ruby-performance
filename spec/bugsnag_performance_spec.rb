# frozen_string_literal: true

RSpec.describe BugsnagPerformance do
  it "has a version number" do
    expect(BugsnagPerformance::VERSION).to be_a(String)
    expect(BugsnagPerformance::VERSION).not_to be_empty
  end

  context "#configure" do
    before do
      allow(open_telemetry_sdk).to receive(:configure).and_yield(open_telemetry_configurator)
      allow(open_telemetry_configurator).to receive(:resource=).with(an_instance_of(OpenTelemetry::SDK::Resources::Resource))
      allow(open_telemetry_configurator).to receive(:add_span_processor).with(an_instance_of(OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor))
      allow(open_telemetry_configurator).to receive(:add_span_processor).with(an_instance_of(BugsnagPerformance::Internal::ProbabilityAttributeSpanProcessor))

      allow(open_telemetry).to receive(:tracer_provider).and_return(open_telemetry_tracer_provider)
      allow(open_telemetry).to receive(:logger).and_return(logger)
      allow(open_telemetry_tracer_provider).to receive(:sampler=).with(an_instance_of(BugsnagPerformance::Internal::Sampler))

      stub_probability_request(1.0)
    end

    let(:open_telemetry) { class_double(OpenTelemetry).as_stubbed_const({ transfer_nested_constants: true }) }
    let(:open_telemetry_sdk) { class_double(OpenTelemetry::SDK).as_stubbed_const({ transfer_nested_constants: true }) }
    let(:open_telemetry_configurator) { instance_double(OpenTelemetry::SDK::Configurator) }
    let(:open_telemetry_tracer_provider) { instance_double(OpenTelemetry::SDK::Trace::TracerProvider) }

    let(:logger) { Logger.new(logger_io, level: Logger::DEBUG) }
    let(:logger_io) { StringIO.new(+"", "w+")}
    let(:logger_output) { logger_io.tap(&:rewind).read }

    it "sets the expected resource attributes to the configured values" do
      expect(open_telemetry_configurator).to receive(:service_version=).with("1.2.3")
      expect(open_telemetry_configurator).to receive(:resource=).with(
        satisfy { |resource| resource.attribute_enumerator.to_h == { "deployment.environment" => "prodevelopment" } }
      )

      BugsnagPerformance.configure do |configuration|
        configuration.api_key = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        configuration.app_version = "1.2.3"
        configuration.release_stage = "prodevelopment"
      end

      expect(logger_output).to be_empty
    end

    it "calls the user's open telemetry configuration block" do
      expect(open_telemetry_configurator).to receive(:service_name=).with("from my block")

      return_value = BugsnagPerformance.configure do |configuration|
        configuration.api_key = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        configuration.configure_open_telemetry do |configurator|
          expect(configurator).to be(open_telemetry_configurator)
          configurator.service_name = "from my block"
        end
      end

      expect(return_value).to eq("from my block")
      expect(logger_output).to be_empty
    end

    it "logs when the current release stage is disabled" do
      expect(open_telemetry_configurator).not_to receive(:service_version=)
      expect(open_telemetry_configurator).to receive(:resource=).with(
        satisfy { |resource| resource.attribute_enumerator.to_h == { "deployment.environment" => "prodevelopment" } }
      )

      BugsnagPerformance.configure do |configuration|
        configuration.api_key = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        configuration.release_stage = "prodevelopment"
        configuration.enabled_release_stages = ["developroduction"]
      end

      expect(logger_output).to include("[BugsnagPerformance] Not exporting spans as the current release stage is not in the enabled release stages.")
    end

    it "raises when no API key is given" do
      expect { BugsnagPerformance.configure }.to raise_error("No Bugsnag API Key set")
    end

    it "logs when a single configuration option is invalid" do
      BugsnagPerformance.configure do |configuration|
        configuration.api_key = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        configuration.release_stage = 1234
      end

      expect(logger_output).to include("[BugsnagPerformance] Invalid configuration. release_stage should be a non-empty string, got 1234")
    end

    it "logs when multiple configuration options are invalid" do
      BugsnagPerformance.configure do |configuration|
        configuration.api_key = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        configuration.release_stage = 1234
        configuration.enabled_release_stages = "yes indeedy"
        configuration.app_version = [1, 2, 3]
      end

      expect(logger_output).to include(
        <<~MESSAGE
          [BugsnagPerformance] Invalid configuration:
            - app_version should be a non-empty string, got [1, 2, 3]
            - release_stage should be a non-empty string, got 1234
            - enabled_release_stages should be an array of non-empty strings, got "yes indeedy"
        MESSAGE
      )
    end
  end
end
