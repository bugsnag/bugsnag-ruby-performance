Feature: Service names

Scenario: It sets the default OTeL service name
  Given I run the service "basic" with the command "bundle exec ruby service-names.rb"
  When I wait to receive a trace
  And the trace payload field "resourceSpans.0.resource" string attribute "service.name" equals "unknown_service"

Scenario: It uses OTeL environment variable for service name
  Given I set environment variable "OTEL_SERVICE_NAME" to "myservice"
  Given I run the service "basic" with the command "bundle exec ruby service-names.rb"
  When I wait to receive a trace
  And the trace payload field "resourceSpans.0.resource" string attribute "service.name" equals "myservice"

Scenario: It uses our environment variable over OTeL one
  Given I set environment variable "OTEL_SERVICE_NAME" to "myservice"
  Given I set environment variable "BUGSNAG_PERFORMANCE_SERVICE_NAME" to "srv1"
  Given I run the service "basic" with the command "bundle exec ruby service-names.rb"
  When I wait to receive a trace
  And the trace payload field "resourceSpans.0.resource" string attribute "service.name" equals "srv1"