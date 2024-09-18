# frozen_string_literal: true

module BugsnagPerformance
  module Internal
    # this class is used when the bugsnag-ruby (aka "bugsnag errors") gem isn't
    # installed to provide the API we need in BugsnagPerformance::Configuration
    class NilErrorsConfiguration
      attr_accessor :api_key
      attr_accessor :app_version
      attr_accessor :release_stage
      attr_accessor :enabled_release_stages
      attr_accessor :logger

      def initialize
        # if bugsnag errors is not installed we still want to read from the
        # environment variables it supports
        @api_key = ENV["BUGSNAG_API_KEY"]
        @app_version = ENV["BUGSNAG_APP_VERSION"]
        @release_stage = ENV["BUGSNAG_RELEASE_STAGE"]
        @enabled_release_stages = ENV["BUGSNAG_ENABLED_RELEASE_STAGES"]
      end
    end
  end
end
