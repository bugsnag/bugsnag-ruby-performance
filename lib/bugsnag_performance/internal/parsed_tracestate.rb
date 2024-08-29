# frozen_string_literal: true

module BugsnagPerformance
  module Internal
    class ParsedTracestate
      attr_reader :version
      attr_reader :r_value

      def initialize(version, r_value, r_value_32_bit:)
        @version = version
        @r_value = r_value
        @r_value_32_bit = r_value_32_bit
      end

      def valid?
        !!(@version && @r_value)
      end

      def r_value_32_bit?
        @r_value_32_bit
      end
    end
  end
end
