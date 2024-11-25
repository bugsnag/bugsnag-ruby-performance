Feature: bugsnag errors integration

Scenario: It picks up configuration from bugsnag errors configuration
  Given I run the service "bugsnag-errors" with the command "bundle exec ruby explicitly-configured.rb"
  And I wait to receive a reflection
  Then the reflection payload field "api_key" equals "123456789012345678901234567890ab"
  Then the reflection payload field "app_version" equals "1.2.3"
  Then the reflection payload field "release_stage" equals "prodevelopment"
  Then the reflection payload field "enabled_release_stages" is an array with 2 elements
  Then the reflection payload field "enabled_release_stages.0" equals "prodevelopment"
  Then the reflection payload field "enabled_release_stages.1" equals "production"

Scenario: It picks up configuration from bugsnag errors' environment variables
  Given I set environment variable "BUGSNAG_API_KEY" to "ab123456789012345678901234567890"
  Given I set environment variable "BUGSNAG_RELEASE_STAGE" to "developroduction"
  And I run the service "bugsnag-errors" with the command "bundle exec ruby environment-variables.rb"
  And I wait to receive a reflection
  Then the reflection payload field "api_key" equals "ab123456789012345678901234567890"
  Then the reflection payload field "release_stage" equals "developroduction"

Scenario: It picks up configuration from performance environment variables over errors'
  Given I set environment variable "BUGSNAG_API_KEY" to "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  Given I set environment variable "BUGSNAG_RELEASE_STAGE" to "development"
  Given I set environment variable "BUGSNAG_PERFORMANCE_API_KEY" to "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
  Given I set environment variable "BUGSNAG_PERFORMANCE_RELEASE_STAGE" to "production"
  Given I set environment variable "BUGSNAG_PERFORMANCE_APP_VERSION" to "3.2.1"
  And I run the service "bugsnag-errors" with the command "bundle exec ruby environment-variables.rb"
  And I wait to receive a reflection
  Then the reflection payload field "api_key" equals "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
  Then the reflection payload field "app_version" equals "3.2.1"
  Then the reflection payload field "release_stage" equals "production"
