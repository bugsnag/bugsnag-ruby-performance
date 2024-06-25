require "uri"
require "open-uri"

uri = URI(ENV.fetch('MAZE_RUNNER_ENDPOINT'))
uri.path = '/reflect'

uri.read
