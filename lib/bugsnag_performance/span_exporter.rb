# frozen_string_literal: true

module BugsnagPerformance
  class SpanExporter
    def initialize(probability_manager, delivery, payload_encoder, sampling_header_encoder)
      @probability_manager = probability_manager
      @delivery = delivery
      @payload_encoder = payload_encoder
      @sampling_header_encoder = sampling_header_encoder
    end

    def export(span_data, timeout: nil)
      with_timeout(timeout) do
        headers = { "Bugsnag-Span-Sampling" => @sampling_header_encoder.encode(span_data) }
        body = JSON.generate(@payload_encoder.encode(span_data))

        response = @delivery.deliver(headers, body)

        if response.sampling_probability
          @probability_manager.probability = response.sampling_probability
        end

        OpenTelemetry::SDK::Trace::Export::SUCCESS
      end
    rescue
      OpenTelemetry::SDK::Trace::Export::FAILURE
    end

    def force_flush(timeout: nil)
      OpenTelemetry::SDK::Trace::Export::SUCCESS
    end

    def shutdown(timeout: nil)
      OpenTelemetry::SDK::Trace::Export::SUCCESS
    end

    private

    def with_timeout(timeout, &block)
      if timeout.nil?
        block.call
      else
        Timeout::timeout(timeout) { block.call }
      end
    end
  end
end
