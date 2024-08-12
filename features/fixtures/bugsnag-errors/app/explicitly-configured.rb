require "uri"
require "json"
require "bugsnag"
require "bugsnag_performance"

Bugsnag.configure do |configuration|
  configuration.api_key = "123456789012345678901234567890ab"
  configuration.app_version = "1.2.3"
  configuration.release_stage = "prodevelopment"
  configuration.enabled_release_stages = ["prodevelopment", "production"]
end

BugsnagPerformance.configure do |configuration|
  uri = URI(ENV.fetch('MAZE_RUNNER_ENDPOINT'))
  uri.path = '/reflect'

  body = JSON.generate({
    api_key: configuration.api_key,
    app_version: configuration.app_version,
    release_stage: configuration.release_stage,
    enabled_release_stages: configuration.enabled_release_stages,
  })

  Net::HTTP.post(uri, body, { 'content-type' => 'application/json' })
end
