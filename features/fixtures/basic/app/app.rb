require "uri"
require "open-uri"
require "bugsnag_performance"
require "opentelemetry/sdk"

configuration = BugsnagPerformance::Configuration.new(BugsnagPerformance::NilErrorsConfiguration.new)
configuration.api_key = "ffffffffffffffffffffffffffffffff"
configuration.endpoint = "#{ENV.fetch('MAZE_RUNNER_ENDPOINT')}/traces"

delivery = BugsnagPerformance::Delivery.new(configuration)
scheduler = BugsnagPerformance::TaskScheduler.new
fetcher = BugsnagPerformance::ProbabilityFetcher.new(configuration.logger, delivery, scheduler)
manager = BugsnagPerformance::ProbabilityManager.new(fetcher)
payload_encoder = BugsnagPerformance::PayloadEncoder.new
header_encoder = BugsnagPerformance::SamplingHeaderEncoder.new

batch_processor = OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(
  BugsnagPerformance::SpanExporter.new(configuration.logger, manager, delivery, payload_encoder, header_encoder)
)

OpenTelemetry::SDK.configure do |otel_configurator|
  otel_configurator.service_name = "basic app"

  otel_configurator.add_span_processor(batch_processor)
  otel_configurator.resource = OpenTelemetry::SDK::Resources::Resource.create({
    # these resource attributes are required for Maze Runner validation
    "device.id" => 1,
    "deployment.environment" => "production",
  })
end

OpenTelemetry.tracer_provider.sampler = BugsnagPerformance::Sampler.new(manager)
Tracer = OpenTelemetry.tracer_provider.tracer("maze tracer")

5.times do |i|
  Tracer.in_span("test span #{i + 1}") do |span|
    span.set_attribute("span.custom.age", i * 10)
  end
end

batch_processor.shutdown
