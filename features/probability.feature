Feature: Probability management

Scenario: It makes an initial probability request
  Given I set the sampling probability to "0.5"
  And I run the service "basic" with the command "bundle exec ruby probability-manager.rb"
  When I wait to receive a sampling request
  And I wait to receive a reflection
  Then the reflection payload field "probability" equals 0.5
