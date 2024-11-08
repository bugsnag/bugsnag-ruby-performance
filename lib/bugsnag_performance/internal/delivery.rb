# frozen_string_literal: true

module BugsnagPerformance
  module Internal
    class Delivery
      attr_reader :uri

      def initialize(configuration)
        @uri = URI(configuration.endpoint)
        @common_headers = {
          "User-Agent" => "#{BugsnagPerformance::SDK_NAME} v#{BugsnagPerformance::VERSION}",
          "Bugsnag-Api-Key" => configuration.api_key,
          "Content-Type" => "application/json",
        }.freeze
      end

      def deliver(headers, body)
        headers = headers.merge(
          @common_headers,
        # TODO - can be restored after https://smartbear.atlassian.net/browse/PIPE-7498
        #  { "Bugsnag-Sent-At" => Time.now.utc.iso8601(3) },
        )

        raw_response = OpenTelemetry::Common::Utilities.untraced do
          Net::HTTP.post(@uri, body, headers)
        end

        Response.new(raw_response)
      end

      class Response
        SAMPLING_PROBABILITY_HEADER = "Bugsnag-Sampling-Probability"
        RETRYABLE_STATUS_CODES = Set[402, 407, 408, 429]

        private_constant :SAMPLING_PROBABILITY_HEADER, :RETRYABLE_STATUS_CODES

        attr_reader :state
        attr_reader :sampling_probability

        def initialize(raw_response)
          if raw_response.nil?
            @state = :failure_retryable
            @sampling_probability = nil
          else
            @state = response_state_from_status_code(raw_response.code)
            @sampling_probability = parse_sampling_probability(raw_response[SAMPLING_PROBABILITY_HEADER])
          end
        end

        def successful?
          @state == :success
        end

        def retryable?
          @state == :failure_retryable
        end

        private

        def response_state_from_status_code(raw_status_code)
          case Integer(raw_status_code, exception: false)
          when 200...300
            :success
          when RETRYABLE_STATUS_CODES
            :failure_retryable
          when 400...500
            :failure_discard
          else
            :failure_retryable
          end
        end

        def parse_sampling_probability(raw_probability)
          parsed = Float(raw_probability, exception: false)

          if parsed && parsed >= 0.0 && parsed <= 1.0
            parsed
          else
            nil
          end
        end
      end
    end
  end
end
