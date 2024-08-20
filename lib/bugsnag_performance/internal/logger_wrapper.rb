# frozen_string_literal: true

module BugsnagPerformance
  class LoggerWrapper
    attr_reader :logger

    def initialize(logger)
      @logger = logger
    end

    def debug(message)
      @logger.debug("[BugsnagPerformance] #{message}")
    end

    def info(message)
      @logger.info("[BugsnagPerformance] #{message}")
    end

    def warn(message)
      @logger.warn("[BugsnagPerformance] #{message}")
    end

    def error(message)
      @logger.error("[BugsnagPerformance] #{message}")
    end
  end
end
