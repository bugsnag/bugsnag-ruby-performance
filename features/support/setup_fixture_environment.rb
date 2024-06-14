require_relative "../lib/environment"

Maze.hooks.before do
  environment = BugsnagPerformanceMazeRunner::Environment.new

  Maze::Runner.environment["BUGSNAG_PERFORMANCE_API_KEY"] = $api_key
  Maze::Runner.environment["BUGSNAG_PERFORMANCE_ENDPOINT"] = "http://#{environment.host}:#{Maze.config.port}/traces"
end
