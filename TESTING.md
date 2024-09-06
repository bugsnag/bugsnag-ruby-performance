# Testing the Ruby BugSnag performance SDK

## Unit tests

```
bundle install
bundle exec rspec
```

## End-to-end tests

These tests are implemented with our internal testing tool [Maze Runner](https://github.com/bugsnag/maze-runner).

End to end tests are written in cucumber-style `.feature` files, and need Ruby-backed "steps" in order to know what to run. The tests are located in the top level [`features`](./features/) directory.

The Maze Runner test fixtures are containerised so you'll need Docker and Docker Compose to run them.

### Running the end to end tests

Install Maze Runner:

```sh
$ BUNDLE_GEMFILE=Gemfile-maze-runner bundle install
```

Configure the tests to be run in the following way:

- Determine the Ruby version to be tested using the environment variable `RUBY_TEST_VERSION`, e.g. `RUBY_TEST_VERSION=3.3`
- Determine the Open Telemetry SDK version using the environment variable `OPEN_TELEMETRY_SDK_TEST_VERSION`, e.g. `OPEN_TELEMETRY_SDK_TEST_VERSION="~> 1.5"`

Use the Maze Runner CLI to run the tests:

```sh
$ RUBY_TEST_VERSION=3.3 \
  OPEN_TELEMETRY_SDK_TEST_VERSION="~> 1.5" \
  BUNDLE_GEMFILE=Gemfile-maze-runner \
  bundle exec maze-runner
```
