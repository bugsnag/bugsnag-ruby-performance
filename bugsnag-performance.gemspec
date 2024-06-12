# frozen_string_literal: true

require_relative "lib/bugsnag_performance/version"

Gem::Specification.new do |spec|
  spec.name = "bugsnag-performance"
  spec.version = BugsnagPerformance::VERSION
  spec.authors = ["BugSnag"]
  spec.email = ["notifiers@bugsnag.com"]

  spec.summary = "BugSnag integration for the Ruby Open Telemetry SDK"
  spec.homepage = "https://www.bugsnag.com"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0"
  spec.require_paths = ["lib"]

  spec.metadata["homepage_uri"] = spec.homepage

  github_url = "https://github.com/bugsnag/bugsnag-ruby-performance"

  spec.metadata["source_code_uri"] = "#{github_url}"
  spec.metadata["bug_tracker_uri"] = "#{github_url}/issues"
  spec.metadata["changelog_uri"] = "#{github_url}/blob/v#{BugsnagPerformance::VERSION}/CHANGELOG.md"
  spec.metadata["documentation_uri"] = "https://docs.bugsnag.com/performance/integration-guides/ruby/"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github .rspec Gemfile])
    end
  end

  spec.add_development_dependency "rspec", "~> 3.0"
end
