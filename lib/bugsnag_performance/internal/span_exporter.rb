# frozen_string_literal: true

module BugsnagPerformance
  module Internal
    class SpanExporter
      def initialize(
        logger,
        probability_manager,
        delivery,
        sampler,
        payload_encoder,
        sampling_header_encoder
      )
        @logger = logger
        @probability_manager = probability_manager
        @delivery = delivery
        @sampler = sampler
        @payload_encoder = payload_encoder
        @sampling_header_encoder = sampling_header_encoder
        @disabled = false
        @unmanaged_mode = false
        @logged_first_batch_destination = false
      end

      def disable!
        @disabled = true
      end

      def unmanaged_mode!
        @unmanaged_mode = true
      end

      def unmanaged_mode?
        @unmanaged_mode
      end

      def export(span_data, timeout: nil)
        return OpenTelemetry::SDK::Trace::Export::SUCCESS if @disabled

        with_timeout(timeout) do
          # ensure we're in the correct managed or unmanaged mode
          maybe_enter_unmanaged_mode
          managed_status = unmanaged_mode? ? "unmanaged" : "managed"

          headers = {}

          # resample the spans and attach the Bugsnag-Span-Sampling header only
          # if we're in managed mode
          unless unmanaged_mode?
            span_data = span_data.filter { |span| @sampler.resample_span?(span) }

            sampling_header = @sampling_header_encoder.encode(span_data)

            if sampling_header.nil?
              @logger.warn("One or more spans are missing the 'bugsnag.sampling.p' attribute. This trace will be sent as unmanaged")
              managed_status = "unmanaged"
            else
              headers["Bugsnag-Span-Sampling"] = sampling_header
            end
          end

          body = JSON.generate(@payload_encoder.encode(span_data))

          # log whether we're sending managed or unmanaged spans on the first
          # batch only
          unless @logged_first_batch_destination
            @logger.info("Sending #{managed_status} spans to #{@delivery.uri}")
            @logged_first_batch_destination = true
          end

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

      def maybe_enter_unmanaged_mode
        # we're in unmanaged mode already so don't need to do anything
        return if unmanaged_mode?

        # our sampler is in use so we're in managed mode
        return if OpenTelemetry.tracer_provider.sampler.is_a?(Sampler)

        # the user has changed the sampler from ours to a custom one; enter
        # unmanaged mode
        unmanaged_mode!
      end

      def with_timeout(timeout, &block)
        if timeout.nil?
          block.call
        else
          Timeout::timeout(timeout) { block.call }
        end
      end
    end
  end
end
