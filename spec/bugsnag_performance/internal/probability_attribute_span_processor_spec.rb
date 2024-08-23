# frozen_string_literal: true

RSpec.describe BugsnagPerformance::Internal::ProbabilityAttributeSpanProcessor do
  subject { BugsnagPerformance::Internal::ProbabilityAttributeSpanProcessor.new(probability_manager) }

  let(:probability_manager) { BugsnagPerformance::Internal::ProbabilityManager.new(probability_fetcher) }
  let(:probability_fetcher) { instance_double(BugsnagPerformance::Internal::ProbabilityFetcher, { on_new_probability: nil, stale_in: nil }) }

  let(:span) do
    span = OpenTelemetry::SDK::Trace::Span.new(
      OpenTelemetry::Trace::SpanContext.new,
      OpenTelemetry::Context.empty,
      OpenTelemetry::Trace::Span::INVALID,
      "name",
      OpenTelemetry::Trace::SpanKind::INTERNAL,
      nil,
      OpenTelemetry::SDK::Trace::SpanLimits.new(
        attribute_count_limit: 10,
        event_count_limit: 10,
        link_count_limit: 10,
        event_attribute_count_limit: 10,
        link_attribute_count_limit: 10,
        attribute_length_limit: 32,
        event_attribute_length_limit: 32
      ),
      [],
      nil,
      nil,
      Time.now,
      nil,
      nil
    )
  end

  context "#on_start" do
    [0.0, 0.1, 0.25, 0.33, 0.4, 0.5, 0.66, 0.75, 0.8, 0.99, 1.0].each do |probability|
      it "adds the 'bugsnag.sampling.p' attribute to spans with value of #{probability}" do
        probability_manager.probability = probability

        status = subject.on_start(span, OpenTelemetry::Context.empty)

        expect(status).to be(OpenTelemetry::SDK::Trace::Export::SUCCESS)
        expect(span.attributes).to eq({ "bugsnag.sampling.p" => probability })
      end
    end

    it "does not overwrite an existing 'bugsnag.sampling.p' attribute" do
      span.set_attribute("bugsnag.sampling.p", 0.1)

      probability_manager.probability = 0.5
      status = subject.on_start(span, OpenTelemetry::Context.empty)

      expect(status).to be(OpenTelemetry::SDK::Trace::Export::SUCCESS)
      expect(span.attributes).to eq({ "bugsnag.sampling.p" => 0.1 })
    end

    it "does not overwrite other existing attributes" do
      span.add_attributes({
        "some.other.attribute" => [1, 2, 3],
        "an.other.attribute" => "abc",
      })

      pp span.attributes

      probability_manager.probability = 0.6
      status = subject.on_start(span, OpenTelemetry::Context.empty)

      expect(status).to be(OpenTelemetry::SDK::Trace::Export::SUCCESS)
      expect(span.attributes).to eq({
        "some.other.attribute" => [1, 2, 3],
        "an.other.attribute" => "abc",
        "bugsnag.sampling.p" => 0.6
      })
    end
  end

  context "#on_finish" do
    it "returns successfully" do
      status = subject.on_finish(span)

      expect(status).to be(OpenTelemetry::SDK::Trace::Export::SUCCESS)
    end
  end

  context "#force_flush" do
    it "returns successfully" do
      status = subject.force_flush

      expect(status).to be(OpenTelemetry::SDK::Trace::Export::SUCCESS)
    end

    it "returns successfully with a timeout" do
      status = subject.force_flush(timeout: 1)

      expect(status).to be(OpenTelemetry::SDK::Trace::Export::SUCCESS)
    end
  end

  context "#shutdown" do
    it "returns successfully" do
      status = subject.shutdown

      expect(status).to be(OpenTelemetry::SDK::Trace::Export::SUCCESS)
    end

    it "returns successfully with a timeout" do
      status = subject.shutdown(timeout: 1)

      expect(status).to be(OpenTelemetry::SDK::Trace::Export::SUCCESS)
    end
  end
end
