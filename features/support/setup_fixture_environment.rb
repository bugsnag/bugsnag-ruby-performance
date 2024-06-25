require_relative "../lib/environment"

Maze.hooks.before do
  environment = BugsnagPerformanceMazeRunner::Environment.new

  Maze::Runner.environment["MAZE_RUNNER_API_KEY"] = $api_key
  Maze::Runner.environment["MAZE_RUNNER_ENDPOINT"] = "http://#{environment.host}:#{Maze.config.port}"
end
