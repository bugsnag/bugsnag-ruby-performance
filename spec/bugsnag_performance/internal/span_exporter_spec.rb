# frozen_string_literal: true

RSpec.describe BugsnagPerformance::Internal::SpanExporter do
  subject { BugsnagPerformance::Internal::SpanExporter.new(logger, probability_manager, delivery, sampler, payload_encoder, sampling_header_encoder) }

  let(:logger) { Logger.new(logger_io, level: Logger::DEBUG) }
  let(:logger_io) { StringIO.new(+"", "w+")}
  let(:logger_output) { logger_io.tap(&:rewind).read }

  let(:probability_manager) { BugsnagPerformance::Internal::ProbabilityManager.new(probability_fetcher) }
  let(:probability_fetcher) { instance_double(BugsnagPerformance::Internal::ProbabilityFetcher, { on_new_probability: nil, stale_in: nil }) }

  let(:delivery) { BugsnagPerformance::Internal::Delivery.new(configuration) }
  let(:configuration) do
    BugsnagPerformance::Configuration.new(BugsnagPerformance::Internal::NilErrorsConfiguration.new).tap do |config|
      config.api_key = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    end
  end

  let(:tracestate_parser) { BugsnagPerformance::Internal::TracestateParser.new }
  let(:sampler) { BugsnagPerformance::Internal::Sampler.new(probability_manager, tracestate_parser) }
  let(:payload_encoder) { BugsnagPerformance::Internal::PayloadEncoder.new }
  let(:sampling_header_encoder) { BugsnagPerformance::Internal::SamplingHeaderEncoder.new }

  let(:open_telemetry) { class_double(OpenTelemetry).as_stubbed_const({ transfer_nested_constants: true }) }
  let(:open_telemetry_tracer_provider) { instance_double(OpenTelemetry::SDK::Trace::TracerProvider) }

  before do
    allow(open_telemetry).to receive(:tracer_provider).and_return(open_telemetry_tracer_provider)
    allow(open_telemetry).to receive(:logger).and_return(logger)
    allow(open_telemetry_tracer_provider).to receive(:sampler).and_return(sampler)
  end

  it "sets the expected headers" do
    status = subject.export([make_span])

    expect(status).to be(OpenTelemetry::SDK::Trace::Export::SUCCESS)
    expect(subject).to have_sent_trace { |headers:, **|
      expect(headers["Bugsnag-Span-Sampling"]).to eq("1.0:1")
      expect(headers["Bugsnag-Api-Key"]).to eq("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
      expect(headers["Bugsnag-Sent-At"]).to match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z\z/)
      expect(headers["Content-Type"]).to eq("application/json")
      expect(headers["User-Agent"]).to eq("#{BugsnagPerformance::SDK_NAME} v#{BugsnagPerformance::VERSION}")
    }
    expect(logger_output).to include("Sending managed spans to https://aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.otlp.bugsnag.com/v1/traces")
  end

  it "updates the probability value from the response" do
    stub_probability_request(0.5)

    expect(probability_manager.probability).to be(1.0)

    status = subject.export([make_span])

    expect(status).to be(OpenTelemetry::SDK::Trace::Export::SUCCESS)
    expect(probability_manager.probability).to be(0.5)
    expect(logger_output).to include("Sending managed spans to https://aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.otlp.bugsnag.com/v1/traces")
  end

  it "can deliver a single minimal span" do
    status = subject.export([make_span])

    expect(status).to be(OpenTelemetry::SDK::Trace::Export::SUCCESS)
    expect(subject).to have_sent_trace { |spans:, **|
      expect(spans).to contain_exactly({
        "name" => "span",
        "kind" => 1,
        "attributes" => [{ "key" => "bugsnag.sampling.p", "value" => { "doubleValue" => 1.0 } }],
        "startTimeUnixNano" => "123456789",
        "endTimeUnixNano" => "234567890",
        "spanId" => be_a_hex_span_id,
        "traceId" => be_a_hex_trace_id,
        "status" => { "code" => 0, "message" => "" },
        "traceState" => "",
        "droppedAttributesCount" => 0,
        "droppedEventsCount" => 0,
        "droppedLinksCount" => 0,
      })
    }

    expect(logger_output).to include("Sending managed spans to https://aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.otlp.bugsnag.com/v1/traces")
  end

  it "can deliver a single complex span" do
    span_data = [
      make_span(
        kind: :client,
        status: OpenTelemetry::Trace::Status.error("bad"),
        parent_span_id: OpenTelemetry::Trace.generate_span_id,
        total_recorded_attributes: 1,
        total_recorded_events: 2,
        total_recorded_links: 3,
        attributes: { "a" => 1, "b" => "xyz", "c" => false, "d" => 2.3, "e" => [1, 2, 3] },
        links: [
          OpenTelemetry::Trace::Link.new(OpenTelemetry::Trace::SpanContext.new, { "x" => 9 }),
          OpenTelemetry::Trace::Link.new(OpenTelemetry::Trace::SpanContext.new, { "y" => true }),
          OpenTelemetry::Trace::Link.new(OpenTelemetry::Trace::SpanContext.new),
        ],
        events: [
          OpenTelemetry::SDK::Trace::Event.new("event 1", { "z" => "hihi" }, 192837465),
          OpenTelemetry::SDK::Trace::Event.new("event 2", { "g" => 5.6 }, 192837466),
        ],
        resource: OpenTelemetry::SDK::Resources::Resource.create, # TODO
        instrumentation_scope: OpenTelemetry::SDK::InstrumentationScope.new, # TODO
        tracestate: OpenTelemetry::Trace::Tracestate.from_string("a=1,b=2"),
      )
    ]

    status = subject.export(span_data)

    expect(status).to be(OpenTelemetry::SDK::Trace::Export::SUCCESS)
    expect(subject).to have_sent_trace { |spans:, **|
      expect(spans).to include({
        "name" => "span",
        "kind" => 3,
        "startTimeUnixNano" => "123456789",
        "endTimeUnixNano" => "234567890",
        "spanId" => be_a_hex_span_id,
        "traceId" => be_a_hex_trace_id,
        "parentSpanId" => be_a_hex_span_id,
        "attributes" => [
          { "key" => "a", "value" => { "intValue" => "1" } },
          { "key" => "b", "value" => { "stringValue" => "xyz" } },
          { "key" => "c", "value" => { "boolValue" => false } },
          { "key" => "d", "value" => { "doubleValue" => 2.3 } },
          { "key" => "e", "value" => { "arrayValue" => [{ "intValue" => "1" }, { "intValue" => "2" }, { "intValue" => "3" }] } },
        ],
        "events" => [
          {
            "attributes" => [{ "key" => "z", "value" => { "stringValue" => "hihi" } }],
            "name" => "event 1",
            "timeUnixNano" => "192837465",
          },
          {
            "attributes" => [{ "key" => "g", "value" => { "doubleValue" => 5.6 } }],
            "name" => "event 2",
            "timeUnixNano" => "192837466"
          },
        ],
        "status" => { "code" => 2, "message" => "bad" },
        "traceState" => "a=1,b=2",
        "links" => [
          {
            "attributes" => [{"key" => "x", "value" => {"intValue" => "9"}}],
            "spanId" => be_a_hex_span_id,
            "traceId" => be_a_hex_trace_id,
            "traceState" => ""
          },
          {
            "attributes" => [{"key" => "y", "value" => {"boolValue" => true}}],
            "spanId" => be_a_hex_span_id,
            "traceId" => be_a_hex_trace_id,
            "traceState" => ""
          },
          {
            "attributes" => [],
            "spanId" => be_a_hex_span_id,
            "traceId" => be_a_hex_trace_id,
            "traceState" => ""
          },
        ],
        "droppedAttributesCount" => 0,
        "droppedEventsCount" => 0,
        "droppedLinksCount" => 0,
      })
    }

    expect(logger_output).to include("One or more spans are missing the 'bugsnag.sampling.p' attribute. This trace will be sent as unmanaged")
    expect(logger_output).to include("Sending unmanaged spans to https://aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.otlp.bugsnag.com/v1/traces")
  end

  it "obeys the given timeout" do
    elapsed = measure do
      stub_request(:post, TRACES_URI).to_return do
        sleep(1)
      end

      status = subject.export([make_span], timeout: 0.1)
      expect(status).to be(OpenTelemetry::SDK::Trace::Export::TIMEOUT)
    end

    expect(elapsed).to be_within(0.1).of(0.1)
    expect(logger_output).to include("Failed to deliver trace to BugSnag.")
    expect(logger_output).to include("execution expired (Timeout::Error)")
  end

  it "returns FAILURE when the request fails" do
    stub_request(:post, TRACES_URI).to_return do
      raise "oh no :("
    end

    status = subject.export([make_span])
    expect(status).to be(OpenTelemetry::SDK::Trace::Export::FAILURE)

    expect(logger_output).to include("Failed to deliver trace to BugSnag.")
    expect(logger_output).to include("oh no :( (RuntimeError)")
  end

  it "does not export spans when disabled" do
    subject.disable!
    status = subject.export([make_span])

    expect(status).to be(OpenTelemetry::SDK::Trace::Export::SUCCESS)
    expect(subject).not_to have_sent_trace
    expect(logger_output).to be_empty
  end

  it "resamples spans against the current probability" do
    resource = OpenTelemetry::SDK::Resources::Resource.create
    scope = OpenTelemetry::SDK::InstrumentationScope.new

    make_span_with_probability = proc do |probability, trace_id:|
      make_span(
        name: "span #{probability}",
        trace_id: trace_id,
        attributes: { "bugsnag.sampling.p" => probability },
        resource: resource,
        instrumentation_scope: scope
      )
    end

    spans = [
      make_span_with_probability.(0.1, trace_id: "aaaaaaaaaaaaaaaa"), # should NOT be sampled
      make_span_with_probability.(0.2, trace_id: "aaaaaaaaaaaaaaab"), # should NOT be sampled
      make_span_with_probability.(0.3, trace_id: "aaaaaaaaaaaaaaac"), # should NOT be sampled
      make_span_with_probability.(0.4, trace_id: "aaaaaaaaaaaaaaad"),
      make_span_with_probability.(0.5, trace_id: "aaaaaaaaaaaaaaae"),
      make_span_with_probability.(0.6, trace_id: "aaaaaaaaaaaaaaaf"),
      make_span_with_probability.(0.7, trace_id: "aaaaaaaaaaaaaaag"),
      make_span_with_probability.(0.8, trace_id: "aaaaaaaaaaaaaaah"),
      make_span_with_probability.(0.9, trace_id: "aaaaaaaaaaaaaaai"),
      make_span_with_probability.(1.0, trace_id: "aaaaaaaaaaaaaaaj"),
    ]

    probability_manager.probability = 0.5

    status = subject.export(spans)
    expect(status).to be(OpenTelemetry::SDK::Trace::Export::SUCCESS)
    expect(logger_output).to include("Sending managed spans to https://aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.otlp.bugsnag.com/v1/traces")

    # spans 0.6-1.0 should have their 'bugsnag.sampling.p' attribute reduced to
    # '0.5' as the current probability is smaller
    expect(subject).to have_sent_trace { |spans:, headers:, **|
      expect(headers["Bugsnag-Span-Sampling"]).to eq("0.4:1;0.5:6")

      expect(spans).to match([
        include({ "name" => "span 0.4", "attributes" => [{ "key" => "bugsnag.sampling.p", "value" => { "doubleValue" => 0.4 }}] }),
        include({ "name" => "span 0.5", "attributes" => [{ "key" => "bugsnag.sampling.p", "value" => { "doubleValue" => 0.5 }}] }),
        include({ "name" => "span 0.6", "attributes" => [{ "key" => "bugsnag.sampling.p", "value" => { "doubleValue" => 0.5 }}] }),
        include({ "name" => "span 0.7", "attributes" => [{ "key" => "bugsnag.sampling.p", "value" => { "doubleValue" => 0.5 }}] }),
        include({ "name" => "span 0.8", "attributes" => [{ "key" => "bugsnag.sampling.p", "value" => { "doubleValue" => 0.5 }}] }),
        include({ "name" => "span 0.9", "attributes" => [{ "key" => "bugsnag.sampling.p", "value" => { "doubleValue" => 0.5 }}] }),
        include({ "name" => "span 1.0", "attributes" => [{ "key" => "bugsnag.sampling.p", "value" => { "doubleValue" => 0.5 }}] }),
      ])
    }
  end

  it "does not resample spans when in unmanaged mode" do
    resource = OpenTelemetry::SDK::Resources::Resource.create
    scope = OpenTelemetry::SDK::InstrumentationScope.new

    make_span_with_probability = proc do |probability, trace_id:|
      make_span(
        name: "span #{probability}",
        trace_id: trace_id,
        attributes: { "bugsnag.sampling.p" => probability },
        resource: resource,
        instrumentation_scope: scope
      )
    end

    spans = [
      make_span_with_probability.(0.1, trace_id: "aaaaaaaaaaaaaaaa"), # should NOT be sampled if sampling was enabled
      make_span_with_probability.(0.2, trace_id: "aaaaaaaaaaaaaaab"), # should NOT be sampled if sampling was enabled
      make_span_with_probability.(0.3, trace_id: "aaaaaaaaaaaaaaac"), # should NOT be sampled if sampling was enabled
      make_span_with_probability.(0.4, trace_id: "aaaaaaaaaaaaaaad"),
      make_span_with_probability.(0.5, trace_id: "aaaaaaaaaaaaaaae"),
      make_span_with_probability.(0.6, trace_id: "aaaaaaaaaaaaaaaf"),
      make_span_with_probability.(0.7, trace_id: "aaaaaaaaaaaaaaag"),
      make_span_with_probability.(0.8, trace_id: "aaaaaaaaaaaaaaah"),
      make_span_with_probability.(0.9, trace_id: "aaaaaaaaaaaaaaai"),
      make_span_with_probability.(1.0, trace_id: "aaaaaaaaaaaaaaaj"),
    ]

    probability_manager.probability = 0.5

    subject.unmanaged_mode!
    expect(subject.unmanaged_mode?).to be(true)

    status = subject.export(spans)
    expect(status).to be(OpenTelemetry::SDK::Trace::Export::SUCCESS)
    expect(logger_output).to include("Sending unmanaged spans to https://aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.otlp.bugsnag.com/v1/traces")

    # all spans should be encoded and their p values should remain unchanged as
    # we have disabled resampling
    expect(subject).to have_sent_trace { |spans:, headers:, **|
      expect(headers.key?("Bugsnag-Span-Sampling")).to be(false)

      expect(spans).to match([
        include({ "name" => "span 0.1", "attributes" => [{ "key" => "bugsnag.sampling.p", "value" => { "doubleValue" => 0.1 }}] }),
        include({ "name" => "span 0.2", "attributes" => [{ "key" => "bugsnag.sampling.p", "value" => { "doubleValue" => 0.2 }}] }),
        include({ "name" => "span 0.3", "attributes" => [{ "key" => "bugsnag.sampling.p", "value" => { "doubleValue" => 0.3 }}] }),
        include({ "name" => "span 0.4", "attributes" => [{ "key" => "bugsnag.sampling.p", "value" => { "doubleValue" => 0.4 }}] }),
        include({ "name" => "span 0.5", "attributes" => [{ "key" => "bugsnag.sampling.p", "value" => { "doubleValue" => 0.5 }}] }),
        include({ "name" => "span 0.6", "attributes" => [{ "key" => "bugsnag.sampling.p", "value" => { "doubleValue" => 0.6 }}] }),
        include({ "name" => "span 0.7", "attributes" => [{ "key" => "bugsnag.sampling.p", "value" => { "doubleValue" => 0.7 }}] }),
        include({ "name" => "span 0.8", "attributes" => [{ "key" => "bugsnag.sampling.p", "value" => { "doubleValue" => 0.8 }}] }),
        include({ "name" => "span 0.9", "attributes" => [{ "key" => "bugsnag.sampling.p", "value" => { "doubleValue" => 0.9 }}] }),
        include({ "name" => "span 1.0", "attributes" => [{ "key" => "bugsnag.sampling.p", "value" => { "doubleValue" => 1.0 }}] }),
      ])
    }
  end

  it "only logs delivery once" do
    status = subject.export([make_span])
    expect(status).to be(OpenTelemetry::SDK::Trace::Export::SUCCESS)

    expect(logger_output).to include("Sending managed spans to https://aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.otlp.bugsnag.com/v1/traces")

    logger_output_before = logger_output.dup

    status = subject.export([make_span])
    expect(status).to be(OpenTelemetry::SDK::Trace::Export::SUCCESS)

    expect(logger_output).to eq(logger_output_before)
  end
end
