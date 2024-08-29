# frozen_string_literal: true

module BugsnagPerformance
  module Internal
    class Sampler
      # the scale factor to use with a 64 bit r value
      PROBABILITY_SCALE_FACTOR_64 = 18_446_744_073_709_551_615 # (2 ** 64) - 1

      # the scale factor to use with a 32 bit r value
      PROBABILITY_SCALE_FACTOR_32 = 4_294_967_295 # (2 ** 32) - 1

      private_constant :PROBABILITY_SCALE_FACTOR_64, :PROBABILITY_SCALE_FACTOR_32

      def initialize(probability_manager, tracestate_parser)
        @probability_manager = probability_manager
        @tracestate_parser = tracestate_parser
      end

      def should_sample?(trace_id:, parent_context:, links:, name:, kind:, attributes:)
        # NOTE: the probability could change at any time so we _must_ only read
        #       it once in this method, otherwise we could use different values
        #       for the sampling decision & p value attribute which would result
        #       in inconsistent data
        probability = @probability_manager.probability
        parent_span_context = OpenTelemetry::Trace.current_span(parent_context).context
        tracestate = parent_span_context.tracestate

        decision =
          if sample_using_probability_and_trace?(probability, tracestate, trace_id)
            OpenTelemetry::SDK::Trace::Samplers::Decision::RECORD_AND_SAMPLE
          else
            OpenTelemetry::SDK::Trace::Samplers::Decision::DROP
          end

        OpenTelemetry::SDK::Trace::Samplers::Result.new(
          decision: decision,
          tracestate: tracestate,
          attributes: { "bugsnag.sampling.p" => probability },
        )
      end

      # @api private
      def resample_span?(span)
        # sample all spans that are missing the p value attribute
        return true if span.attributes.nil? || span.attributes["bugsnag.sampling.p"].nil?

        probability = @probability_manager.probability

        # update the p value attribute if it was originally sampled with a larger
        # probability than the current value
        if span.attributes["bugsnag.sampling.p"] > probability
          span.attributes["bugsnag.sampling.p"] = probability
        end

        sample_using_probability_and_trace?(
          span.attributes["bugsnag.sampling.p"],
          span.tracestate,
          span.trace_id
        )
      end

      private

      def sample_using_probability_and_trace?(probability, tracestate, trace_id)
        # parse the r value from tracestate or generate from the trace ID by
        # unpacking it as a u64
        parsed_tracestate = @tracestate_parser.parse(tracestate)

        if parsed_tracestate.valid?
          # the JS SDK will send a u32 as the r value so we need to scale the
          # probability value to the same range for comparisons to work
          r_value = parsed_tracestate.r_value
          scale_factor = parsed_tracestate.r_value_32_bit? ? PROBABILITY_SCALE_FACTOR_32 : PROBABILITY_SCALE_FACTOR_64
        else
          r_value = trace_id.unpack1("@8Q>")
          scale_factor = PROBABILITY_SCALE_FACTOR_64
        end

        # scale the probability (stored as a float from 0-1) to the appropriate
        # size int (u32 or u64)
        p_value = (probability * scale_factor).floor

        p_value >= r_value
      end
    end
  end
end
