# frozen_string_literal: true

RSpec.describe BugsnagPerformance::SpanExporter do
  subject { BugsnagPerformance::SpanExporter.new(logger, probability_manager, delivery, payload_encoder, sampling_header_encoder) }

  let(:logger) { Logger.new(logger_io, level: Logger::DEBUG) }
  let(:logger_io) { StringIO.new(+"", "w+")}
  let(:logger_output) { logger_io.tap(&:rewind).read }

  let(:probability_manager) { BugsnagPerformance::ProbabilityManager.new(probability_fetcher) }
  let(:probability_fetcher) { instance_double(BugsnagPerformance::ProbabilityFetcher, { on_new_probability: nil, stale_in: nil }) }

  let(:delivery) { BugsnagPerformance::Delivery.new(configuration) }
  let(:configuration) do
    BugsnagPerformance::Configuration.new(BugsnagPerformance::NilErrorsConfiguration.new).tap do |config|
      config.api_key = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    end
  end

  let(:sampler) { BugsnagPerformance::Sampler.new(probability_manager) }
  let(:payload_encoder) { BugsnagPerformance::PayloadEncoder.new(sampler) }
  let(:sampling_header_encoder) { BugsnagPerformance::SamplingHeaderEncoder.new }

  it "sets the expected headers" do
    status = subject.export([make_span])

    expect(status).to be(OpenTelemetry::SDK::Trace::Export::SUCCESS)
    expect(subject).to have_sent_trace { |headers:, **|
      expect(headers["Bugsnag-Span-Sampling"]).to eq("1.0:1")
      expect(headers["Bugsnag-Api-Key"]).to eq("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
      expect(headers["Bugsnag-Sent-At"]).to match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z\z/)
      expect(headers["Content-Type"]).to eq("application/json")
    }
    expect(logger_output).to be_empty
  end

  it "updates the probability value from the response" do
    stub_probability_request(0.5)

    expect(probability_manager.probability).to be(1.0)

    status = subject.export([make_span])

    expect(status).to be(OpenTelemetry::SDK::Trace::Export::SUCCESS)
    expect(probability_manager.probability).to be(0.5)
    expect(logger_output).to be_empty
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

    expect(logger_output).to be_empty
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

    expect(logger_output).to include("[BugsnagPerformance] One or more spans are missing the 'bugsnag.sampling.p' attribute. This trace will be sent as 'unmanaged'.")
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
    expect(logger_output).to include("[BugsnagPerformance] Failed to deliver trace to BugSnag.")
    expect(logger_output).to include("execution expired (Timeout::Error)")
  end

  it "returns FAILURE when the request fails" do
    stub_request(:post, TRACES_URI).to_return do
      raise "oh no :("
    end

    status = subject.export([make_span])
    expect(status).to be(OpenTelemetry::SDK::Trace::Export::FAILURE)

    expect(logger_output).to include("[BugsnagPerformance] Failed to deliver trace to BugSnag.")
    expect(logger_output).to include("oh no :( (RuntimeError)")
  end

  it "does not export spans when disabled" do
    subject.disable!
    status = subject.export([make_span])

    expect(status).to be(OpenTelemetry::SDK::Trace::Export::SUCCESS)
    expect(subject).not_to have_sent_trace
    expect(logger_output).to be_empty
  end
end
