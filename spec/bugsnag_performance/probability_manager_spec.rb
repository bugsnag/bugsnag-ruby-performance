# frozen_string_literal: true

RSpec.describe BugsnagPerformance::ProbabilityManager do
  subject { BugsnagPerformance::ProbabilityManager.new(probability_fetcher) }
  let(:probability_fetcher) { instance_double(BugsnagPerformance::ProbabilityFetcher) }

  it "has a default probability" do
    expect(probability_fetcher).to receive(:on_new_probability).once

    expect(subject.probability).to be(1.0)
  end

  it "fetches a new probability immediately" do
    expect(probability_fetcher).to receive(:on_new_probability).once.and_yield(0.123)
    expect(probability_fetcher).to receive(:stale_in).once.with(60 * 60 * 24)

    expect(subject.probability).to be(0.123)
  end

  it "can set a new probability value" do
    expect(probability_fetcher).to receive(:on_new_probability).once.and_yield(0.999)
    expect(probability_fetcher).to receive(:stale_in).twice.with(60 * 60 * 24)

    subject.probability = 0.5

    expect(subject.probability).to be(0.5)
  end
end
