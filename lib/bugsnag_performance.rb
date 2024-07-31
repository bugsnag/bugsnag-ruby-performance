# frozen_string_literal: true

require "time"
require "net/http"
require "concurrent-ruby"
require "opentelemetry-sdk"

require_relative "bugsnag_performance/error"

require_relative "bugsnag_performance/task"
require_relative "bugsnag_performance/sampler"
require_relative "bugsnag_performance/version"
require_relative "bugsnag_performance/delivery"
require_relative "bugsnag_performance/configuration"
require_relative "bugsnag_performance/task_scheduler"
require_relative "bugsnag_performance/payload_encoder"
require_relative "bugsnag_performance/probability_fetcher"
require_relative "bugsnag_performance/probability_manager"
require_relative "bugsnag_performance/configuration_validator"
require_relative "bugsnag_performance/sampling_header_encoder"
require_relative "bugsnag_performance/nil_errors_configuration"
