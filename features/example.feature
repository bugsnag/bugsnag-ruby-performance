Feature: example

Scenario: It runs the basic app
  Given I run the service "basic" with the command "bundle exec ruby app.rb"
  And I wait to receive a reflection
