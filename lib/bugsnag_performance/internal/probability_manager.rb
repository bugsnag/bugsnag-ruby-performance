# frozen_string_literal: true

module BugsnagPerformance
  module Internal
    class ProbabilityManager
      # the duration (in seconds) that a probability value is considered stale
      # and therefore we need to fetch a new value
      STALE_PROBABILITY_SECONDS = 60 * 60 * 24 # 24 hours
      private_constant :STALE_PROBABILITY_SECONDS

      def initialize(probability_fetcher)
        @probability_fetcher = probability_fetcher
        @probability = 1.0
        @lock = Mutex.new

        @probability_fetcher.on_new_probability do |new_probability|
          self.probability = new_probability
        end
      end

      def probability
        @lock.synchronize do
          @probability
        end
      end

      def probability=(new_probability)
        @lock.synchronize do
          @probability = new_probability
          @probability_fetcher.stale_in(STALE_PROBABILITY_SECONDS)
        end
      end
    end
  end
end
