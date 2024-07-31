# frozen_string_literal: true

module BugsnagPerformance
  class SpanExporter
    def initialize(probability_manager, delivery, payload_encoder, sampling_header_encoder)
      @probability_manager = probability_manager
      @delivery = delivery
      @payload_encoder = payload_encoder
      @sampling_header_encoder = sampling_header_encoder
    end

    # TODO: handle 'timeout'
    def export(span_data, timeout: nil)
      headers = { "Bugsnag-Span-Sampling" => @sampling_header_encoder.encode(span_data) }
      body = JSON.generate(@payload_encoder.encode(span_data))

      response = @delivery.deliver(headers, body)

      if response.sampling_probability
        @probability_manager.probability = response.sampling_probability
      end

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
