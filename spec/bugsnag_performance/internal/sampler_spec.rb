# frozen_string_literal: true

class FakeProbabilityManager
  attr_reader :probability

  def initialize(probability)
    @probability = probability
  end
end

RSpec.describe BugsnagPerformance::Internal::Sampler do
  let(:trace_id) { OpenTelemetry::Trace.generate_trace_id }
  let(:tracestate) { OpenTelemetry::Trace::Tracestate.from_string("") }
  let(:tracestate_parser) { BugsnagPerformance::Internal::TracestateParser.new }

  let(:parent_context) do
    span_context = OpenTelemetry::Trace::SpanContext.new(
      trace_id: OpenTelemetry::Trace.generate_trace_id,
      tracestate: tracestate
    )

    OpenTelemetry::Trace.context_with_span(
      OpenTelemetry::Trace.non_recording_span(span_context)
    )
  end

  it "should always sample with a probability of 1.0" do
    sampler = BugsnagPerformance::Internal::Sampler.new(FakeProbabilityManager.new(1.0), tracestate_parser)

    result = sampler.should_sample?(
      trace_id: trace_id,
      parent_context: parent_context,
      links: nil,
      name: nil,
      kind: nil,
      attributes: nil,
    )

    expect(result).to be_sampled
    expect(result.tracestate).to be(tracestate)
    expect(result.attributes).to eq({ "bugsnag.sampling.p" => 1.0 })
  end

  it "should never sample with a probability of 0.0" do
    sampler = BugsnagPerformance::Internal::Sampler.new(FakeProbabilityManager.new(0.0), tracestate_parser)

    result = sampler.should_sample?(
      trace_id: trace_id,
      parent_context: parent_context,
      links: nil,
      name: nil,
      kind: nil,
      attributes: nil,
    )

    expect(result).not_to be_sampled
    expect(result.tracestate).to be(tracestate)
    expect(result.attributes).to eq({ "bugsnag.sampling.p" => 0.0 })
  end

  it "should sample trace ID '2b0eb6c82ae431ad7fdc00306faebef6' with a probability of 0.5" do
    # known value pregenerated with 'OpenTelemetry::Trace.generate_trace_id' and
    # converted to hex for ease of reading
    trace_id = ["2b0eb6c82ae431ad7fdc00306faebef6"].pack("H*")

    sampler = BugsnagPerformance::Internal::Sampler.new(FakeProbabilityManager.new(0.5), tracestate_parser)

    result = sampler.should_sample?(
      trace_id: trace_id,
      parent_context: parent_context,
      links: nil,
      name: nil,
      kind: nil,
      attributes: nil,
    )

    expect(result).to be_sampled
    expect(result.tracestate).to be(tracestate)
    expect(result.attributes).to eq({ "bugsnag.sampling.p" => 0.5 })
  end

  it "should not sample trace ID '98e03bf7fc2715bdcf426f549ca74150' with a probability of 0.5" do
    # known value pregenerated with 'OpenTelemetry::Trace.generate_trace_id' and
    # converted to hex for ease of reading
    trace_id = ["98e03bf7fc2715bdcf426f549ca74150"].pack("H*")

    sampler = BugsnagPerformance::Internal::Sampler.new(FakeProbabilityManager.new(0.5), tracestate_parser)

    result = sampler.should_sample?(
      trace_id: trace_id,
      parent_context: parent_context,
      links: nil,
      name: nil,
      kind: nil,
      attributes: nil,
    )

    expect(result).not_to be_sampled
    expect(result.tracestate).to be(tracestate)
    expect(result.attributes).to eq({ "bugsnag.sampling.p" => 0.5 })
  end

  it "should sample roughly half of all spans with a probability of 0.5" do
    total_spans = 50_000
    margin_of_error = total_spans / 100

    sampler = BugsnagPerformance::Internal::Sampler.new(FakeProbabilityManager.new(0.5), tracestate_parser)
    sampled_spans = 0

    total_spans.times do
      result = sampler.should_sample?(
        trace_id: OpenTelemetry::Trace.generate_trace_id,
        parent_context: parent_context,
        links: nil,
        name: nil,
        kind: nil,
        attributes: nil,
      )

      sampled_spans += 1 if result.sampled?
    end

    expect(sampled_spans).to be_within(margin_of_error).of(total_spans / 2)
  end

  [
    [OpenTelemetry::Trace::Tracestate.from_string("sb=v:1;r32:1234"), 0.00000029, :sampled],
    [OpenTelemetry::Trace::Tracestate.from_string("sb=v:1;r32:2000"), 0.00000030, :not_sampled],
    [OpenTelemetry::Trace::Tracestate.from_string("sb=v:1;r32:999999999"), 1.0, :sampled],
    [OpenTelemetry::Trace::Tracestate.from_string("sb=v:1;r32:999999999"), 0.00005, :not_sampled],
    [OpenTelemetry::Trace::Tracestate.from_string("sb=v:1;r64:1234"), 0.00000029, :sampled],
    [OpenTelemetry::Trace::Tracestate.from_string("sb=v:1;r64:5534023222113"), 0.00000030, :not_sampled],
    [OpenTelemetry::Trace::Tracestate.from_string("sb=v:1;r64:999999999"), 1.0, :sampled],
    [OpenTelemetry::Trace::Tracestate.from_string("sb=v:1;r64:999999999"), 0.00000000005, :not_sampled],
  ].each do |tracestate, probability, expected_result|
    it "should use the r value from tracestate if present ('#{tracestate}', #{probability})" do
      span_context = OpenTelemetry::Trace::SpanContext.new(
        trace_id: OpenTelemetry::Trace.generate_trace_id,
        tracestate: tracestate
      )

      parent_context = OpenTelemetry::Trace.context_with_span(
        OpenTelemetry::Trace.non_recording_span(span_context)
      )

      sampler = BugsnagPerformance::Internal::Sampler.new(
        FakeProbabilityManager.new(probability),
        tracestate_parser
      )

      result = sampler.should_sample?(
        trace_id: trace_id,
        parent_context: parent_context,
        links: nil,
        name: nil,
        kind: nil,
        attributes: nil,
      )

      if expected_result == :sampled
        expect(result).to be_sampled
      else
        expect(result).not_to be_sampled
      end

      expect(result.tracestate).to be(tracestate)
      expect(result.attributes).to eq({ "bugsnag.sampling.p" => probability })
    end
  end
end
