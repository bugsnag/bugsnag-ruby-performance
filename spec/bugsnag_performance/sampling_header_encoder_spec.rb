# frozen_string_literal: true

RSpec.describe BugsnagPerformance::SamplingHeaderEncoder do
  it "returns '1.0:0' when there are no spans" do
    expect(subject.encode([])).to eq("1.0:0")
  end

  it "returns nil when a span is missing the 'bugsnag.sampling.p' attribute" do
    span1 = make_span
    span2 = make_span(attributes: {})
    span3 = make_span

    expect(subject.encode([span1, span2, span3])).to be_nil
  end

  [
    [[1.0], "1.0:1"],
    [[1.0, 1.0, 1.0], "1.0:3"],
    [[1.0, 0.1, 1.0], "1.0:2;0.1:1"],
    [[0.1, 1.0, 1.0], "0.1:1;1.0:2"],
    [[0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9], "0.1:1;0.2:1;0.3:1;0.4:1;0.5:1;0.6:1;0.7:1;0.8:1;0.9:1"],
    [[].fill(0.1, 0...100).fill(0.2, 100...150).fill(0.88, 150...175).fill(0.456, 175...300), "0.1:100;0.2:50;0.88:25;0.456:125"],
  ].each do |probabilities, expected|
    it "returns '#{truncate(expected)}' with probabilities #{truncate(probabilities)}" do
      spans = probabilities.map do |probability|
        make_span(attributes: { "bugsnag.sampling.p" => probability })
      end

      expect(subject.encode(spans)).to eq(expected)
    end
  end
end
