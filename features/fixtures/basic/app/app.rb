require "uri"
require "open-uri"

uri = URI(ENV.fetch('BUGSNAG_PERFORMANCE_ENDPOINT'))
uri.path = '/reflect'

uri.read
