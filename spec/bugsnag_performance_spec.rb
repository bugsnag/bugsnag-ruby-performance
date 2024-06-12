# frozen_string_literal: true

RSpec.describe BugsnagPerformance do
  it "has a version number" do
    expect(BugsnagPerformance::VERSION).to be_a(String)
    expect(BugsnagPerformance::VERSION).not_to be_empty
  end
end
