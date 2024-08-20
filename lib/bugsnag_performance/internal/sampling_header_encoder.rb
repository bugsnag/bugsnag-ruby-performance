# frozen_string_literal: true

module BugsnagPerformance
  module Internal
    class SamplingHeaderEncoder
      def encode(spans)
        return "1.0:0" if spans.empty?

        spans
          .group_by do |span|
            # bail if the atrribute is missing; we'll warn about this later as it
            # means something has gone wrong
            return nil if span.attributes.nil?

            probability = span.attributes["bugsnag.sampling.p"]
            return nil if probability.nil?

            probability
          end
          .map { |probability, spans| "#{probability}:#{spans.length}" }
          .join(";")
      end
    end
  end
end
