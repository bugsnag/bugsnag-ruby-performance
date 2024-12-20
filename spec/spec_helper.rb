# frozen_string_literal: true

require "webmock/rspec"
require "bugsnag_performance"

TRACES_URI = %r{\Ahttps://[0-9A-Fa-f]{32}\.otlp\.bugsnag\.com/v1/traces\z}

module Helpers
  def with_environment_variable(name, value, &block)
    value_before = ENV[name]

    ENV[name] = value

    block.call
  ensure
    if value_before
      ENV[name] = value_before
    else
      ENV.delete(name)
    end
  end

  def stub_probability_request(probability)
    stub_request(:post, TRACES_URI).to_return(
      body: "",
      status: 200,
      headers: { "Bugsnag-Sampling-Probability" => probability }
    )
  end

  def stub_response_status_code(status_code)
    stub_request(:post, TRACES_URI).to_return(
      body: "",
      status: status_code,
    )
  end

  def measure(&block)
    before = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    block.call

    Process.clock_gettime(Process::CLOCK_MONOTONIC) - before
  end

  def make_span(
    name: "span",
    kind: :internal,
    status: OpenTelemetry::Trace::Status.ok,
    parent_span_id: OpenTelemetry::Trace::INVALID_SPAN_ID,
    total_recorded_attributes: 0,
    total_recorded_events: 0,
    total_recorded_links: 0,
    start_timestamp: 123456789,
    end_timestamp: 234567890,
    attributes: { "bugsnag.sampling.p" => 1.0 },
    links: nil,
    events: nil,
    resource: OpenTelemetry::SDK::Resources::Resource.create,
    instrumentation_scope: OpenTelemetry::SDK::InstrumentationScope.new,
    span_id: OpenTelemetry::Trace.generate_span_id,
    trace_id: OpenTelemetry::Trace.generate_trace_id,
    trace_flags: 0,
    tracestate: OpenTelemetry::Trace::Tracestate.from_string("")
  )
    OpenTelemetry::SDK::Trace::SpanData.new(
      name,
      kind,
      status,
      parent_span_id,
      total_recorded_attributes,
      total_recorded_events,
      total_recorded_links,
      start_timestamp,
      end_timestamp,
      attributes,
      links,
      events,
      resource,
      instrumentation_scope,
      span_id,
      trace_id,
      trace_flags,
      tracestate,
    )
  end
end

RSpec.configure do |config|
  config.order = :random

  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!
  config.filter_run_when_matching(:focus)

  # make rspec display colour on CI
  if ENV["CI"] == "true"
    config.color_mode = :on
    config.tty = true
  end

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.include(Helpers)

  config.before(:each) do
    WebMock.stub_request(:post, TRACES_URI)
  end
end

def have_sent_trace(&matcher)
  have_requested(:post, TRACES_URI).with do |request|
    if matcher
      body = JSON.parse(request.body)
      spans = body["resourceSpans"].flat_map do |resource_span|
        resource_span["scopeSpans"].flat_map { |scope_span| scope_span["spans"] }
      end

      matcher.call(body: body, headers: request.headers, spans: spans)

      true
    else
      raise "no matcher provided to have_sent_trace (did you use { }?)"
    end
  end
end

RSpec::Matchers.define :be_a_hex_span_id do
  match do |actual|
    actual != OpenTelemetry::Trace::INVALID_SPAN_ID && actual.match?(/\A[0-9A-Fa-f]{16}\z/)
  end

  diffable
end

RSpec::Matchers.define :be_a_hex_trace_id do
  match do |actual|
    actual != OpenTelemetry::Trace::INVALID_TRACE_ID && actual.match?(/\A[0-9A-Fa-f]{32}\z/)
  end

  diffable
end

def truncate(maybe_string, max_length: 25)
  string = maybe_string.is_a?(String) ? maybe_string : maybe_string.inspect

  return string if string.length < max_length

  case string[0]
  when "{"
    string[..max_length - 3] + "… }"
  when "["
    string[..max_length - 2] + "…]"
  else
    string[..max_length - 1] + "…"
  end
end
