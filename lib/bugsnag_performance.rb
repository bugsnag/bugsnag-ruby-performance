# frozen_string_literal: true

require "concurrent-ruby"
require "opentelemetry-sdk"

require_relative "bugsnag_performance/error"

require_relative "bugsnag_performance/task"
require_relative "bugsnag_performance/sampler"
require_relative "bugsnag_performance/version"
require_relative "bugsnag_performance/configuration"
require_relative "bugsnag_performance/configuration_validator"
require_relative "bugsnag_performance/nil_errors_configuration"
