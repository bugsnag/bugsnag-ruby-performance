require "uri"
require "json"
require "bugsnag"
require "bugsnag_performance"

configuration = BugsnagPerformance::Configuration.new(Bugsnag.configuration)

uri = URI(ENV.fetch('MAZE_RUNNER_ENDPOINT'))
uri.path = '/reflect'

body = JSON.generate({
  api_key: configuration.api_key,
  release_stage: configuration.release_stage,
})

Net::HTTP.post(uri, body, { 'content-type' => 'application/json' })
