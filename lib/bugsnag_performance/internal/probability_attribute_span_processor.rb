# frozen_string_literal: true

module BugsnagPerformance
  module Internal
    class ProbabilityAttributeSpanProcessor
      def initialize(probability_manager)
        @probability_manager = probability_manager
      end

      def on_start(span, parent_context)
        # avoid overwriting the attribute if the sampler has already set it
        if span.attributes.nil? || span.attributes["bugsnag.sampling.p"].nil?
          span.set_attribute("bugsnag.sampling.p", @probability_manager.probability)
        end

        OpenTelemetry::SDK::Trace::Export::SUCCESS
      end

      def on_finish(span)
        OpenTelemetry::SDK::Trace::Export::SUCCESS
      end

      def force_flush(timeout: nil)
        OpenTelemetry::SDK::Trace::Export::SUCCESS
      end

      def shutdown(timeout: nil)
        OpenTelemetry::SDK::Trace::Export::SUCCESS
      end
    end
  end
end
