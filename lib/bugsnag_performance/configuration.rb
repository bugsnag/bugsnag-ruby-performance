# frozen_string_literal: true

module BugsnagPerformance
  class Configuration
    attr_accessor :api_key
    attr_accessor :app_version
    attr_accessor :release_stage
    attr_accessor :enabled_release_stages
    attr_accessor :use_managed_quota

    attr_writer :endpoint

    def initialize
      @release_stage = "production"
      @use_managed_quota = true
    end

    def endpoint
      case
      when @endpoint
        # if a custom endpoint has been set then use it directly
        @endpoint
      when @api_key.nil?
        # if there's no API key then we can't construct the default URL
        nil
      else
        "https://#{@api_key}.otlp.bugsnag.com/v1/traces"
      end
    end
  end
end
