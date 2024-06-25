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
