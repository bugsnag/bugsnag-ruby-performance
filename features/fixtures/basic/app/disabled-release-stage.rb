require "uri"
require "open-uri"
require "bugsnag_performance"
require "opentelemetry/sdk"

at_exit { OpenTelemetry.tracer_provider.shutdown }

BugsnagPerformance.configure do |configuration|
  configuration.api_key = "ffffffffffffffffffffffffffffffff"
  configuration.endpoint = "#{ENV.fetch('MAZE_RUNNER_ENDPOINT')}/traces"
  configuration.app_version = "1.22.333"
  configuration.enabled_release_stages = ["production", "staging"]
  configuration.release_stage = "development"

  configuration.configure_open_telemetry do |otel_configurator|
    otel_configurator.service_name = "basic app"

    otel_configurator.resource = OpenTelemetry::SDK::Resources::Resource.create({
      # these resource attributes are required for Maze Runner validation
      "device.id" => 1,
    })
  end
end

Tracer = OpenTelemetry.tracer_provider.tracer("maze tracer")

5.times do |i|
  Tracer.in_span("test span #{i + 1}") do |span|
    span.set_attribute("span.custom.age", i * 10)
  end
end
