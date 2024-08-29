# frozen_string_literal: true

RSpec.describe BugsnagPerformance::Internal::TracestateParser do
  Tracestate = OpenTelemetry::Trace::Tracestate

  it "returns an empty ParsedTracestate when the tracestate is empty" do
    tracestate = Tracestate.from_string("")
    actual = subject.parse(tracestate)

    expect(actual.version).to be_nil
    expect(actual.r_value).to be_nil
    expect(actual.valid?).to be(false)
    expect(actual.r_value_32_bit?).to be(false)
  end

  it "returns an empty ParsedTracestate when there's no 'sb' value" do
    tracestate = Tracestate.from_string("ab=c:1,xyz=lmn:op")
    actual = subject.parse(tracestate)

    expect(actual.version).to be_nil
    expect(actual.r_value).to be_nil
    expect(actual.valid?).to be(false)
    expect(actual.r_value_32_bit?).to be(false)
  end

  it "returns a ParsedTracestate with no version if it is missing from tracestate (64 bit)" do
    tracestate = Tracestate.from_string("ab=c:1,xyz=lmn:op,sb=r64:1234")
    actual = subject.parse(tracestate)

    expect(actual.version).to be_nil
    expect(actual.r_value).to eq(1234)
    expect(actual.valid?).to be(false)
    expect(actual.r_value_32_bit?).to be(false)
  end

  it "returns a ParsedTracestate with no version if it is missing from tracestate (32 bit)" do
    tracestate = Tracestate.from_string("ab=c:1,xyz=lmn:op,sb=r32:1234")
    actual = subject.parse(tracestate)

    expect(actual.version).to be_nil
    expect(actual.r_value).to eq(1234)
    expect(actual.valid?).to be(false)
    expect(actual.r_value_32_bit?).to be(true)
  end

  it "returns a ParsedTracestate with no r value if it is missing from tracestate" do
    tracestate = Tracestate.from_string("ab=c:1,xyz=lmn:op,sb=v:1")
    actual = subject.parse(tracestate)

    expect(actual.version).to eq("1")
    expect(actual.r_value).to be_nil
    expect(actual.valid?).to be(false)
    expect(actual.r_value_32_bit?).to be(false)
  end

  it "returns a ParsedTracestate with both values if they are present in tracestate (64 bit)" do
    tracestate = Tracestate.from_string("ab=c:1,xyz=lmn:op,sb=v:2;r64:999")
    actual = subject.parse(tracestate)

    expect(actual.version).to eq("2")
    expect(actual.r_value).to eq(999)
    expect(actual.valid?).to be(true)
    expect(actual.r_value_32_bit?).to be(false)
  end

  it "returns a ParsedTracestate with both values if they are present in tracestate (32 bit)" do
    tracestate = Tracestate.from_string("ab=c:1,xyz=lmn:op,sb=v:2;r32:999")
    actual = subject.parse(tracestate)

    expect(actual.version).to eq("2")
    expect(actual.r_value).to eq(999)
    expect(actual.valid?).to be(true)
    expect(actual.r_value_32_bit?).to be(true)
  end
end
