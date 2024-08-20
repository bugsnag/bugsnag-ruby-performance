# frozen_string_literal: true

module BugsnagPerformance
  class SpanExporter
    def initialize(
      logger,
      probability_manager,
      delivery,
      payload_encoder,
      sampling_header_encoder
    )
      @logger = logger
      @probability_manager = probability_manager
      @delivery = delivery
      @payload_encoder = payload_encoder
      @sampling_header_encoder = sampling_header_encoder
      @disabled = false
    end

    def disable!
      @disabled = true
    end

    def export(span_data, timeout: nil)
      return OpenTelemetry::SDK::Trace::Export::SUCCESS if @disabled

      with_timeout(timeout) do
        headers = {}
        sampling_header = @sampling_header_encoder.encode(span_data)

        if sampling_header.nil?
          @logger.warn("One or more spans are missing the 'bugsnag.sampling.p' attribute. This trace will be sent as 'unmanaged'.")
        else
          headers["Bugsnag-Span-Sampling"] = sampling_header
        end

        body = JSON.generate(@payload_encoder.encode(span_data))

        response = @delivery.deliver(headers, body)

        if response.sampling_probability
          @probability_manager.probability = response.sampling_probability
        end

        OpenTelemetry::SDK::Trace::Export::SUCCESS
      end
    rescue => exception
      @logger.error("Failed to deliver trace to BugSnag.")
      @logger.error(exception)

      return OpenTelemetry::SDK::Trace::Export::TIMEOUT if exception.is_a?(Timeout::Error)

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
