# frozen_string_literal: true

module BugsnagPerformance
  class Error < StandardError; end

  class MissingApiKeyError < Error
    def initialize
      super("No Bugsnag API Key set")
    end
  end
end
