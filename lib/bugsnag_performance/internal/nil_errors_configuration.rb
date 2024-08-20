# frozen_string_literal: true

module BugsnagPerformance
  # this class is used when the bugsnag-ruby (aka "bugsnag errors") gem isn't
  # installed to provide the API we need in BugsnagPerformance::Configuration
  class NilErrorsConfiguration
    attr_accessor :api_key
    attr_accessor :app_version
    attr_accessor :release_stage
    attr_accessor :enabled_release_stages
    attr_accessor :logger
  end
end
