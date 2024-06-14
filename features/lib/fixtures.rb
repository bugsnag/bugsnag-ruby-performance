module BugsnagPerformanceMazeRunner
  class Fixtures
    def initialize(logger)
      @logger = logger
    end

    def install_gem
      @logger.debug("Building bugsnag-performance")

      # build the gem
      `gem build bugsnag-performance.gemspec -o bugsnag-performance.gem`

      gem_path = File.realpath("#{__dir__}/../../bugsnag-performance.gem")
      @logger.debug("Built bugsnag-performance at: #{gem_path}")

      Dir.entries("features/fixtures").reject { |entry| [".", ".."].include?(entry) }.each do |entry|
        target = "features/fixtures/#{entry}"

        next unless File.directory?(target)

        @logger.debug("Unpacking bugsnag-performance in '#{entry}' fixture (#{target})")

        `cp #{gem_path} #{target}`
        `gem unpack #{target}/bugsnag-performance.gem --target #{target}/temp-bugsnag-performance`
      end
    ensure
      File.unlink(gem_path) if gem_path && File.exist?(gem_path)
    end
  end
end
