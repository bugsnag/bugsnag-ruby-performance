# frozen_string_literal: true

module BugsnagPerformance
  module Internal
    class TracestateParser
      def parse(tracestate)
        smartbear_values = tracestate.value("sb")
        return ParsedTracestate.new(nil, nil, r_value_32_bit: false) if smartbear_values.nil?

        version = nil
        r_value_32 = nil
        r_value_64 = nil

        smartbear_values.split(";").each do |field|
          key, value = field.split(":", 2)

          case key
          when "v"
            version = value
          when "r32"
            r_value_32 = Integer(value, exception: false)
          when "r64"
            r_value_64 = Integer(value, exception: false)
          end
        end

        ParsedTracestate.new(
          version,
          # a 64 bit value should take precedence over a 32 bit one if both are
          # present in the tracestate
          r_value_64 || r_value_32,
          r_value_32_bit: r_value_64.nil? && !r_value_32.nil?
        )
      end
    end
  end
end
