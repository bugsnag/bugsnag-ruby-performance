# frozen_string_literal: true

module BugsnagPerformance
  class Sampler
    PROBABILITY_SCALE_FACTOR = 18_446_744_073_709_551_615 # (2 ** 64) - 1

    private_constant :PROBABILITY_SCALE_FACTOR

    def initialize(probability_manager)
      @probability_manager = probability_manager
    end

    def should_sample?(trace_id:, parent_context:, links:, name:, kind:, attributes:)
      # NOTE: the probability could change at any time so we _must_ only read
      #       it once in this method, otherwise we could use different values
      #       for the sampling decision & p value attribute which would result
      #       in inconsistent data
      probability = @probability_manager.probability

      decision =
        if sample_using_probability_and_trace_id?(probability, trace_id)
          OpenTelemetry::SDK::Trace::Samplers::Decision::RECORD_AND_SAMPLE
        else
          OpenTelemetry::SDK::Trace::Samplers::Decision::DROP
        end

      parent_span_context = OpenTelemetry::Trace.current_span(parent_context).context

      OpenTelemetry::SDK::Trace::Samplers::Result.new(
        decision: decision,
        tracestate: parent_span_context.tracestate,
        attributes: { "bugsnag.sampling.p" => probability },
      )
    end

    # @api private
    def resample_span?(span)
      probability = @probability_manager.probability

      # sample all spans that are missing the p value attribute
      return true if span.attributes.nil? || span.attributes["bugsnag.sampling.p"].nil?

      # update the p value attribute if it was originally sampled with a larger
      # probability than the current value
      if span.attributes["bugsnag.sampling.p"] > probability
        span.attributes["bugsnag.sampling.p"] = probability
      end

      sample_using_probability_and_trace_id?(span.attributes["bugsnag.sampling.p"], span.trace_id)
    end

    private

    def sample_using_probability_and_trace_id?(probability, trace_id)
      # scale the probability (stored as a float from 0-1) to a u64
      p_value = (probability * PROBABILITY_SCALE_FACTOR).floor

      # unpack the trace ID as a u64
      r_value = trace_id.unpack1("@8Q>")

      p_value >= r_value
    end
  end
end
