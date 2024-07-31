Feature: example

Scenario: It runs the basic app
  Given I run the service "basic" with the command "bundle exec ruby app.rb"
  When I wait to receive a trace
  Then the sampling request "Bugsnag-Span-Sampling" header equals "1.0:0"
  And the trace "Bugsnag-Span-Sampling" header equals "1.0:5"

  And the trace payload field "resourceSpans.0.resource" string attribute "service.name" equals "basic app"
  And the trace payload field "resourceSpans.0.resource" integer attribute "device.id" equals 1
  And the trace payload field "resourceSpans.0.resource" string attribute "deployment.environment" equals "production"

  And the trace payload field "resourceSpans.0.scopeSpans.0.spans.0.name" equals "test span 1"
  And the trace payload field "resourceSpans.0.scopeSpans.0.spans.0.kind" equals 1
  And the trace payload field "resourceSpans.0.scopeSpans.0.spans.0" integer attribute "span.custom.age" equals 0
  And the trace payload field "resourceSpans.0.scopeSpans.0.spans.0.traceState" equals ""
  And the trace payload field "resourceSpans.0.scopeSpans.0.spans.0.droppedAttributesCount" equals 0
  And the trace payload field "resourceSpans.0.scopeSpans.0.spans.0.droppedEventsCount" equals 0
  And the trace payload field "resourceSpans.0.scopeSpans.0.spans.0.droppedLinksCount" equals 0
  And the trace payload field "resourceSpans.0.scopeSpans.0.spans.0.status.code" equals 1
  And the trace payload field "resourceSpans.0.scopeSpans.0.spans.0.status.message" equals ""

  And the trace payload field "resourceSpans.0.scopeSpans.0.spans.1.name" equals "test span 2"
  And the trace payload field "resourceSpans.0.scopeSpans.0.spans.1.kind" equals 1
  And the trace payload field "resourceSpans.0.scopeSpans.0.spans.1" integer attribute "span.custom.age" equals 10
  And the trace payload field "resourceSpans.0.scopeSpans.0.spans.1.traceState" equals ""
  And the trace payload field "resourceSpans.0.scopeSpans.0.spans.1.droppedAttributesCount" equals 0
  And the trace payload field "resourceSpans.0.scopeSpans.0.spans.1.droppedEventsCount" equals 0
  And the trace payload field "resourceSpans.0.scopeSpans.0.spans.1.droppedLinksCount" equals 0
  And the trace payload field "resourceSpans.0.scopeSpans.0.spans.1.status.code" equals 1
  And the trace payload field "resourceSpans.0.scopeSpans.0.spans.1.status.message" equals ""

  And the trace payload field "resourceSpans.0.scopeSpans.0.spans.2.name" equals "test span 3"
  And the trace payload field "resourceSpans.0.scopeSpans.0.spans.2.kind" equals 1
  And the trace payload field "resourceSpans.0.scopeSpans.0.spans.2" integer attribute "span.custom.age" equals 20
  And the trace payload field "resourceSpans.0.scopeSpans.0.spans.2.traceState" equals ""
  And the trace payload field "resourceSpans.0.scopeSpans.0.spans.2.droppedAttributesCount" equals 0
  And the trace payload field "resourceSpans.0.scopeSpans.0.spans.2.droppedEventsCount" equals 0
  And the trace payload field "resourceSpans.0.scopeSpans.0.spans.2.droppedLinksCount" equals 0
  And the trace payload field "resourceSpans.0.scopeSpans.0.spans.2.status.code" equals 1
  And the trace payload field "resourceSpans.0.scopeSpans.0.spans.2.status.message" equals ""

  And the trace payload field "resourceSpans.0.scopeSpans.0.spans.3.name" equals "test span 4"
  And the trace payload field "resourceSpans.0.scopeSpans.0.spans.3.kind" equals 1
  And the trace payload field "resourceSpans.0.scopeSpans.0.spans.3" integer attribute "span.custom.age" equals 30
  And the trace payload field "resourceSpans.0.scopeSpans.0.spans.3.traceState" equals ""
  And the trace payload field "resourceSpans.0.scopeSpans.0.spans.3.droppedAttributesCount" equals 0
  And the trace payload field "resourceSpans.0.scopeSpans.0.spans.3.droppedEventsCount" equals 0
  And the trace payload field "resourceSpans.0.scopeSpans.0.spans.3.droppedLinksCount" equals 0
  And the trace payload field "resourceSpans.0.scopeSpans.0.spans.3.status.code" equals 1
  And the trace payload field "resourceSpans.0.scopeSpans.0.spans.3.status.message" equals ""

  And the trace payload field "resourceSpans.0.scopeSpans.0.spans.4.name" equals "test span 5"
  And the trace payload field "resourceSpans.0.scopeSpans.0.spans.4.kind" equals 1
  And the trace payload field "resourceSpans.0.scopeSpans.0.spans.4" integer attribute "span.custom.age" equals 40
  And the trace payload field "resourceSpans.0.scopeSpans.0.spans.4.traceState" equals ""
  And the trace payload field "resourceSpans.0.scopeSpans.0.spans.4.droppedAttributesCount" equals 0
  And the trace payload field "resourceSpans.0.scopeSpans.0.spans.4.droppedEventsCount" equals 0
  And the trace payload field "resourceSpans.0.scopeSpans.0.spans.4.droppedLinksCount" equals 0
  And the trace payload field "resourceSpans.0.scopeSpans.0.spans.4.status.code" equals 1
  And the trace payload field "resourceSpans.0.scopeSpans.0.spans.4.status.message" equals ""