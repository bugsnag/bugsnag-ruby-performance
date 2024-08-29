# frozen_string_literal: true

RSpec.describe BugsnagPerformance::Internal::ParsedTracestate do
  ParsedTracestate = BugsnagPerformance::Internal::ParsedTracestate

  it "stores a version and r value (64 bit)" do
    parsed_tracestate = ParsedTracestate.new("3.2.1", 12345, r_value_32_bit: false)

    expect(parsed_tracestate.version).to eq("3.2.1")
    expect(parsed_tracestate.r_value).to eq(12345)
    expect(parsed_tracestate.r_value_32_bit?).to be(false)
  end

  it "stores a version and r value (32 bit)" do
    parsed_tracestate = ParsedTracestate.new("474.372", 927465, r_value_32_bit: true)

    expect(parsed_tracestate.version).to eq("474.372")
    expect(parsed_tracestate.r_value).to eq(927465)
    expect(parsed_tracestate.r_value_32_bit?).to be(true)
  end

  context "#valid?" do
    it "is valid when both version and r value are non-nil (64 bit)" do
      parsed_tracestate = ParsedTracestate.new("7.8.9", 54321, r_value_32_bit: false)

      expect(parsed_tracestate.valid?).to be(true)
    end

    it "is valid when both version and r value are non-nil (32 bit)" do
      parsed_tracestate = ParsedTracestate.new("982.34", 88888, r_value_32_bit: true)

      expect(parsed_tracestate.valid?).to be(true)
    end

    it "is invalid when version is nil" do
      parsed_tracestate = ParsedTracestate.new(nil, 54321, r_value_32_bit: false)

      expect(parsed_tracestate.valid?).to be(false)
    end

    it "is invalid when r value is nil" do
      parsed_tracestate = ParsedTracestate.new("1.2.3", nil, r_value_32_bit: false)

      expect(parsed_tracestate.valid?).to be(false)
    end

    it "is invalid when both version and r value are nil" do
      parsed_tracestate = ParsedTracestate.new(nil, nil, r_value_32_bit: false)

      expect(parsed_tracestate.valid?).to be(false)
    end
  end
end
