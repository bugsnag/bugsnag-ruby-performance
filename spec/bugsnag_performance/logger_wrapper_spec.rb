# frozen_string_literal: true

RSpec.describe BugsnagPerformance::LoggerWrapper do
  subject { BugsnagPerformance::LoggerWrapper.new(logger) }

  let(:logger) { Logger.new(logger_io, level: Logger::DEBUG) }
  let(:logger_io) { StringIO.new(+"", "w+")}
  let(:logger_output) { logger_io.tap(&:rewind).read }

  it "can log at 'debug' level" do
    subject.debug("d e b u g")

    expect(logger_output).to include("DEBUG -- : [BugsnagPerformance] d e b u g")
  end

  it "can log at 'info' level" do
    subject.info("i n f o")

    expect(logger_output).to include("INFO -- : [BugsnagPerformance] i n f o")
  end

  it "can log at 'warn' level" do
    subject.warn("w a r n")

    expect(logger_output).to include("WARN -- : [BugsnagPerformance] w a r n")
  end

  it "can log at 'error' level" do
    subject.error("e r r o r")

    expect(logger_output).to include("ERROR -- : [BugsnagPerformance] e r r o r")
  end
end
