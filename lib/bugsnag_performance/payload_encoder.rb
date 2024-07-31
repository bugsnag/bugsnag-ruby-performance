# frozen_string_literal: true

module BugsnagPerformance
  class PayloadEncoder
    # https://github.com/open-telemetry/opentelemetry-proto/blob/484241a016d7b81f20b6e19d00ffbc4a3b864a22/opentelemetry/proto/trace/v1/trace.proto#L150-L176
    SPAN_KIND_UNSPECIFIED = 0
    SPAN_KIND_INTERNAL = 1
    SPAN_KIND_SERVER = 2
    SPAN_KIND_CLIENT = 3
    SPAN_KIND_PRODUCER = 4
    SPAN_KIND_CONSUMER = 5

    # https://github.com/open-telemetry/opentelemetry-proto/blob/484241a016d7b81f20b6e19d00ffbc4a3b864a22/opentelemetry/proto/trace/v1/trace.proto#L312-L320
    SPAN_STATUS_OK = 0
    SPAN_STATUS_UNSET = 1
    SPAN_STATUS_ERROR = 2

    private_constant :SPAN_KIND_UNSPECIFIED,
      :SPAN_KIND_INTERNAL,
      :SPAN_KIND_SERVER,
      :SPAN_KIND_CLIENT,
      :SPAN_KIND_PRODUCER,
      :SPAN_KIND_CONSUMER,
      :SPAN_STATUS_OK,
      :SPAN_STATUS_UNSET,
      :SPAN_STATUS_ERROR

    def encode(span_data)
      {
        resourceSpans: span_data
          .group_by(&:resource)
          .map do |resource, scope_spans|
            {
              resource: {
                attributes: resource.attribute_enumerator.map(&method(:attribute_to_json)),
              },
              scopeSpans: scope_spans
                .group_by(&:instrumentation_scope)
                .map do |scope, spans|
                  {
                    scope: { name: scope.name, version: scope.version },
                    spans: spans.map(&method(:span_to_json)),
                  }
                end,
            }
          end
      }
    end

    private

    def span_to_json(span)
      {
        name: span.name,
        kind: kind_to_json(span.kind),
        spanId: span.hex_span_id,
        traceId: span.hex_trace_id,
        parentSpanId: span.parent_span_id == OpenTelemetry::Trace::INVALID_SPAN_ID ? nil : span.hex_parent_span_id,
        startTimeUnixNano: span.start_timestamp.to_s,
        endTimeUnixNano: span.end_timestamp.to_s,
        traceState: span.tracestate.to_s,
        droppedAttributesCount: calculate_dropped_count(span.total_recorded_attributes, span.attributes),
        droppedEventsCount: calculate_dropped_count(span.total_recorded_events, span.events),
        droppedLinksCount: calculate_dropped_count(span.total_recorded_links, span.links),
        status: { code: span.status.code, message: span.status.description },
        attributes: span.attributes&.map(&method(:attribute_to_json)),
        events: span.events&.map do |event|
          {
            name: event.name,
            timeUnixNano: event.timestamp.to_s,
            attributes: event.attributes&.map(&method(:attribute_to_json))
            # the OTel SDK doesn't provide dropped_attributes_count for events
          }.tap(&:compact!)
        end,
        links: span.links&.map do |link|
          context = link.span_context

          {
            traceId: context.hex_trace_id,
            spanId: context.hex_span_id,
            traceState: context.tracestate.to_s,
            attributes: link.attributes&.map(&method(:attribute_to_json))
            # the OTel SDK doesn't provide dropped_attributes_count for links
          }.tap(&:compact!)
        end,
      }.tap(&:compact!)
    end

    def attribute_to_json(key, value)
      { key: key, value: attribute_value_to_json(value) }
    end

    def attribute_value_to_json(value)
      case value
      when Integer
        { intValue: value.to_s }
      when Float
        { doubleValue: value }
      when true, false
        { boolValue: value }
      when String
        { stringValue: value }
      when Array
        { arrayValue: value.map(&method(:attribute_value_to_json)) }
      end
    end

    def kind_to_json(kind)
      case kind
      when :internal
        SPAN_KIND_INTERNAL
      when :server
        SPAN_KIND_SERVER
      when :client
        SPAN_KIND_CLIENT
      when :producer
        SPAN_KIND_PRODUCER
      when :consumer
        SPAN_KIND_CONSUMER
      else
        SPAN_KIND_UNSPECIFIED
      end
    end

    def calculate_dropped_count(total_items, remaining_items)
      return 0 if remaining_items.nil?

      dropped_count = total_items - remaining_items.length
      return 0 if dropped_count.negative?

      dropped_count
    end
  end
end
