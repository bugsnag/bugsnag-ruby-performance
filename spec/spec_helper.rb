# frozen_string_literal: true

require "webmock/rspec"
require "bugsnag_performance"

TRACES_URI = %r{\Ahttps://[0-9A-Fa-f]{32}\.otlp\.bugsnag\.com/v1/traces\z}

module Helpers
  def with_environment_variable(name, value, &block)
    value_before = ENV[name]

    ENV[name] = value

    block.call
  ensure
    if value_before
      ENV[name] = value_before
    else
      ENV.delete(name)
    end
  end

  def stub_probability_request(probability)
    stub_request(:post, TRACES_URI).to_return(
      body: "",
      status: 200,
      headers: { "Bugsnag-Sampling-Probability" => probability }
    )
  end

  def stub_response_status_code(status_code)
    stub_request(:post, TRACES_URI).to_return(
      body: "",
      status: status_code,
    )
  end

  def measure(&block)
    before = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    block.call

    Process.clock_gettime(Process::CLOCK_MONOTONIC) - before
  end
end

RSpec.configure do |config|
  config.order = :random

  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!
  config.filter_run_when_matching(:focus)

  # make rspec display colour on CI
  if ENV["CI"] == "true"
    config.color_mode = :on
    config.tty = true
  end

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.include(Helpers)

  config.before(:each) do
    WebMock.stub_request(:post, TRACES_URI)
  end
end
