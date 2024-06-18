# frozen_string_literal: true

require "bugsnag_performance"

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
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  # make rspec display colour on CI
  if ENV["CI"] == "true"
    config.color_mode = :on
    config.tty = true
  end

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.include(Helpers)
end
