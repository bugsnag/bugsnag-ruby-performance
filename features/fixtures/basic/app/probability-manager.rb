require "uri"
require "json"
require "bugsnag_performance"

configuration = BugsnagPerformance::Configuration.new(BugsnagPerformance::NilErrorsConfiguration.new)
configuration.api_key = "ffffffffffffffffffffffffffffffff"
configuration.endpoint = "#{ENV.fetch('MAZE_RUNNER_ENDPOINT')}/traces"

delivery = BugsnagPerformance::Delivery.new(configuration)
scheduler = BugsnagPerformance::TaskScheduler.new
fetcher = BugsnagPerformance::ProbabilityFetcher.new(delivery, scheduler)
manager = BugsnagPerformance::ProbabilityManager.new(fetcher)

# wait to get a new probability value from MR
Timeout::timeout(5) { sleep(0.01) until manager.probability != 1.0 }

# confirm with MR that we got the new probability and set it on the manager
uri = URI(configuration.endpoint)
uri.path = '/reflect'

body = JSON.generate({ probability: manager.probability })

Net::HTTP.post(uri, body, { 'content-type' => 'application/json' })
