require "uri"
require "json"
require "bugsnag_performance"

BugsnagPerformance.configure do |configuration|
  configuration.api_key = "ffffffffffffffffffffffffffffffff"
  configuration.endpoint = "#{ENV.fetch('MAZE_RUNNER_ENDPOINT')}/traces"
end

manager = OpenTelemetry.tracer_provider.sampler.instance_variable_get(:@probability_manager)

# wait to get a new probability value from MR
Timeout::timeout(5) { sleep(0.01) until manager.probability != 1.0 }

# confirm with MR that we got the new probability and set it on the manager
uri = URI("#{ENV.fetch('MAZE_RUNNER_ENDPOINT')}/traces")
uri.path = '/reflect'

body = JSON.generate({ probability: manager.probability })

Net::HTTP.post(uri, body, { 'content-type' => 'application/json' })
