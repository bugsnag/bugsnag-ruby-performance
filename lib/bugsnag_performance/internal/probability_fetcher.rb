# frozen_string_literal: true

module BugsnagPerformance
  module Internal
    class ProbabilityFetcher
      # the time to wait before retrying a failed request
      RETRY_SECONDS = 30
      STALE_PROBABILITY_SECONDS = 60 * 60 * 24 # 24 hours
      HEADERS = { "Bugsnag-Span-Sampling" => "1.0:0" }
      BODY = '{"resourceSpans": []}'

      private_constant :RETRY_SECONDS, :STALE_PROBABILITY_SECONDS, :HEADERS, :BODY

      def initialize(logger, delivery, task_scheduler)
        @logger = logger
        @delivery = delivery
        @task_scheduler = task_scheduler
      end

      def stale_in(seconds)
        @task.schedule(seconds)
      end

      def on_new_probability(&on_new_probability_callback)
        @task = @task_scheduler.now do |done|
          get_new_probability do |new_probability|
            on_new_probability_callback.call(new_probability)

            done.call
          end
        end
      end

      private

      def get_new_probability(&block)
        # keep making requests until we get a new probability from the server
        loop do
          begin
            response = @delivery.deliver(HEADERS, BODY)
          rescue => exception
            # do nothing, we'll warn about this shortly...
          end

          # in theory this should always be present, but it's possible the request
          # fails or there's a bug on the server side causing it not to be returned
          if response && new_probability = response.sampling_probability
            new_probability = Float(new_probability, exception: false)

            if new_probability && new_probability >= 0.0 && new_probability <= 1.0
              block.call(new_probability)

              break
            end
          end

          @logger.warn("Failed to retrieve a probability value from BugSnag. Retrying in 30 seconds.")
          @logger.warn(exception) if exception

          # wait a bit before trying again
          sleep(RETRY_SECONDS)
        end
      end
    end
  end
end
