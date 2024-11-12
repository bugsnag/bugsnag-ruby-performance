require_relative "../lib/environment"
require_relative "../lib/fixtures"

Maze.hooks.before_all do
  # log to console, not a file
  Maze.config.file_log = false
  Maze.config.log_requests = true

  # don't wait so long for requests/not to receive requests locally
  unless ENV["CI"]
    Maze.config.receive_requests_wait = 10
    Maze.config.receive_no_requests_wait = 10
  end

  # we don't need to send the integrity header
  Maze.config.enforce_bugsnag_integrity = false
  # TODO - can be restored after https://smartbear.atlassian.net/browse/PIPE-7498
  Maze.config.skip_default_validation('trace')

  BugsnagPerformanceMazeRunner::Fixtures.new($logger).install_gem
end
