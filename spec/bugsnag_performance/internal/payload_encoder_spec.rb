# frozen_string_literal: true

RSpec.describe BugsnagPerformance::Internal::PayloadEncoder do
  subject { BugsnagPerformance::Internal::PayloadEncoder.new(sampler) }

  let(:sampler) { BugsnagPerformance::Internal::Sampler.new(probability_manager) }
  let(:probability_manager) { BugsnagPerformance::Internal::ProbabilityManager.new(probability_fetcher) }
  let(:probability_fetcher) { instance_double(BugsnagPerformance::Internal::ProbabilityFetcher, { on_new_probability: nil, stale_in: nil }) }

  it "can encode a single minimal span" do
    expect(subject.encode([make_span])).to match({
      resourceSpans: [
        {
          resource: {
            attributes: [],
          },
          scopeSpans: [
            {
              scope: { name: nil, version: nil },
              spans: [
                {
                  name: "span",
                  kind: 1,
                  startTimeUnixNano: "123456789",
                  endTimeUnixNano: "234567890",
                  spanId: be_a_hex_span_id,
                  traceId: be_a_hex_trace_id,
                  attributes: [{ key: "bugsnag.sampling.p", value: { doubleValue: 1.0 } }],
                  status: { code: 0, message: "" },
                  traceState: "",
                  droppedAttributesCount: 0,
                  droppedEventsCount: 0,
                  droppedLinksCount: 0,
                }
              ]
            }
          ]
        }
      ]
    })
  end

  it "can encode a single complex span" do
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
        resource: OpenTelemetry::SDK::Resources::Resource.create({ "a" => 1, "b" => "2", "c" => 3.4 }),
        instrumentation_scope: OpenTelemetry::SDK::InstrumentationScope.new("scoop", "v1.2"),
        tracestate: OpenTelemetry::Trace::Tracestate.from_string("a=1,b=2"),
      )
    ]

    expect(subject.encode(span_data)).to match({
      resourceSpans: [
        {
          resource: {
            attributes: [
              { key: "a", value: { intValue: "1" } },
              { key: "b", value: { stringValue: "2" } },
              { key: "c", value: { doubleValue: 3.4 } },
            ],
          },
          scopeSpans: [
            {
              scope: { name: "scoop", version: "v1.2" },
              spans: [
                {
                  name: "span",
                  kind: 3,
                  startTimeUnixNano: "123456789",
                  endTimeUnixNano: "234567890",
                  spanId: be_a_hex_span_id,
                  traceId: be_a_hex_trace_id,
                  parentSpanId: be_a_hex_span_id,
                  attributes: [
                    { key: "a", value: { intValue: "1" } },
                    { key: "b", value: { stringValue: "xyz" } },
                    { key: "c", value: { boolValue: false } },
                    { key: "d", value: { doubleValue: 2.3 } },
                    { key: "e", value: { arrayValue: [{ intValue: "1" }, { intValue: "2" }, { intValue: "3" }] } },
                  ],
                  events: [
                    {
                      attributes: [{ key: "z", value: { stringValue: "hihi" } }],
                      name: "event 1",
                      timeUnixNano: "192837465",
                    },
                    {
                      attributes: [{ key: "g", value: { doubleValue: 5.6 } }],
                      name: "event 2",
                      timeUnixNano: "192837466"
                    },
                  ],
                  status: { code: 2, message: "bad" },
                  traceState: "a=1,b=2",
                  links: [
                    {
                      attributes: [{ key: "x", value: { intValue: "9" } }],
                      spanId: be_a_hex_span_id,
                      traceId: be_a_hex_trace_id,
                      traceState: ""
                    },
                    {
                      attributes: [{ key: "y", value: { boolValue: true } }],
                      spanId: be_a_hex_span_id,
                      traceId: be_a_hex_trace_id,
                      traceState: ""
                    },
                    {
                      attributes: [],
                      spanId: be_a_hex_span_id,
                      traceId: be_a_hex_trace_id,
                      traceState: ""
                    },
                  ],
                  droppedAttributesCount: 0,
                  droppedEventsCount: 0,
                  droppedLinksCount: 0,
                }
              ]
            }
          ]
        }
      ]
    })
  end

  it "can encode spans in different scopes" do
    resource = OpenTelemetry::SDK::Resources::Resource.create
    scope2 = OpenTelemetry::SDK::InstrumentationScope.new("scope 2", "abcdefg")

    spans = [
      make_span(name: "span 1", resource: resource, instrumentation_scope: OpenTelemetry::SDK::InstrumentationScope.new("scope 1", "v9.8.7")),
      make_span(name: "span 2", resource: resource, instrumentation_scope: scope2),
      make_span(name: "span 3", resource: resource, instrumentation_scope: OpenTelemetry::SDK::InstrumentationScope.new("scope 3", "v0.0.0.0.0.1")),
      make_span(name: "span 4", resource: resource, instrumentation_scope: scope2),
    ]

    expect(subject.encode(spans)).to match({
      resourceSpans: [
        {
          resource: { attributes: [] },
          scopeSpans: [
            {
              scope: { name: "scope 1", version: "v9.8.7" },
              spans: [include({ name: "span 1" })],
            },
            {
              scope: { name: "scope 2", version: "abcdefg" },
              spans: [
                include({ name: "span 2" }),
                include({ name: "span 4" }),
              ]
            },
            {
              scope: { name: "scope 3", version: "v0.0.0.0.0.1" },
              spans: [include({ name: "span 3" })]
            },
          ]
        }
      ]
    })
  end

  it "can encode spans with different resources" do
    resource1 = OpenTelemetry::SDK::Resources::Resource.create({ "name" => "resource 1" })
    resource2 = OpenTelemetry::SDK::Resources::Resource.create({ "name" => "resource 2" })

    spans = [
      make_span(name: "span 1", resource: resource1),
      make_span(name: "span 2", resource: resource2),
      make_span(name: "span 3", resource: resource1),
    ]

    expect(subject.encode(spans)).to match({
      resourceSpans: [
        {
          resource: { attributes: [{ key: "name", value: { stringValue: "resource 1" } }] },
          scopeSpans: [
            {
              scope: { name: nil, version: nil },
              spans: [include({ name: "span 1" }), include({ name: "span 3" })],
            },
          ]
        },
        {
          resource: { attributes: [{ key: "name", value: { stringValue: "resource 2" } }] },
          scopeSpans: [
            {
              scope: { name: nil, version: nil },
              spans: [include({ name: "span 2" })]
            }
          ]
        }
      ]
    })
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

    # spans 0.6-1.0 should have their 'bugsnag.sampling.p' attribute reduced to
    # '0.5' as the current probability is smaller
    expect(subject.encode(spans).dig(:resourceSpans, 0, :scopeSpans, 0, :spans)).to match([
      include({ name: "span 0.4", attributes: [{ key: "bugsnag.sampling.p", value: { doubleValue: 0.4 }}] }),
      include({ name: "span 0.5", attributes: [{ key: "bugsnag.sampling.p", value: { doubleValue: 0.5 }}] }),
      include({ name: "span 0.6", attributes: [{ key: "bugsnag.sampling.p", value: { doubleValue: 0.5 }}] }),
      include({ name: "span 0.7", attributes: [{ key: "bugsnag.sampling.p", value: { doubleValue: 0.5 }}] }),
      include({ name: "span 0.8", attributes: [{ key: "bugsnag.sampling.p", value: { doubleValue: 0.5 }}] }),
      include({ name: "span 0.9", attributes: [{ key: "bugsnag.sampling.p", value: { doubleValue: 0.5 }}] }),
      include({ name: "span 1.0", attributes: [{ key: "bugsnag.sampling.p", value: { doubleValue: 0.5 }}] }),
    ])
  end
end
