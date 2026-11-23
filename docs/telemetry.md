# Telemetry

Emissions emits telemetry events at key points throughout the event lifecycle. Attach handlers to these events to build dashboards, alerts, and observability into your application.

## Attaching Handlers

```elixir
defmodule MyApp.EmissionsTelemetry do
  def setup do
    :telemetry.attach_many(
      "emissions-metrics",
      [
        [:emissions, :buffer, :started],
        [:emissions, :buffer, :committed],
        [:emissions, :event, :dropped],
        [:emissions, :adapter, :success],
        [:emissions, :adapter, :error],
        [:emissions, :handler, :success],
        [:emissions, :handler, :error],
        [:emissions, :handler, :ignored]
      ],
      &handle_event/4,
      nil
    )
  end

  defp handle_event(event, measurements, metadata, _config) do
    # Report to your metrics system
    MyApp.Metrics.increment(event, measurements, metadata)
  end
end
```

## Buffer Events

### `[:emissions, :buffer, :started]`

A new per-request buffer was created.

| Field | Value |
|---|---|
| Measurements | `%{count: 1}` |
| Metadata | `%{}` |

### `[:emissions, :buffer, :committed]`

A buffer was committed and events were handed to the pipeline.

| Field | Value |
|---|---|
| Measurements | `%{count: pos_integer()}` |
| Metadata | `%{event_count: pos_integer()}` |

## Event Events

### `[:emissions, :event, :dropped]`

An event was dropped because no buffer was active.

| Field | Value |
|---|---|
| Measurements | `%{count: 1}` |
| Metadata | `%{event_name: atom(), reason: :not_started}` |

## Adapter Events

### `[:emissions, :adapter, :success]`

An adapter successfully processed a batch of events.

| Field | Value |
|---|---|
| Measurements | `%{duration: integer()}` |
| Metadata | `%{adapter: module(), event_count: pos_integer()}` |

Duration is in native time units (see `System.convert_time_unit/3`).

### `[:emissions, :adapter, :error]`

An adapter failed to process a batch of events.

| Field | Value |
|---|---|
| Measurements | `%{duration: integer()}` |
| Metadata | `%{adapter: module(), reason: term(), event_count: pos_integer()}` |

## Handler Events

### `[:emissions, :handler, :success]`

A handler successfully processed an event.

| Field | Value |
|---|---|
| Measurements | `%{duration: integer()}` |
| Metadata | `%{handler: module(), event: atom()}` |

### `[:emissions, :handler, :error]`

A handler returned `{:error, reason}` for an event.

| Field | Value |
|---|---|
| Measurements | `%{duration: integer()}` |
| Metadata | `%{handler: module(), event: atom(), reason: term()}` |

### `[:emissions, :handler, :ignored]`

A handler returned `:ignored` for an event.

| Field | Value |
|---|---|
| Measurements | `%{count: 1}` |
| Metadata | `%{handler: module(), event: atom()}` |

## Example: StatsD Integration

```elixir
defmodule MyApp.EmissionsMetrics do
  def setup do
    events = [
      [:emissions, :buffer, :committed],
      [:emissions, :adapter, :success],
      [:emissions, :adapter, :error],
      [:emissions, :handler, :success],
      [:emissions, :handler, :error]
    ]

    :telemetry.attach_many("emissions-statsd", events, &handle/4, nil)
  end

  defp handle([:emissions, :buffer, :committed], %{count: count}, _meta, _) do
    Statix.histogram("emissions.buffer.committed", count)
  end

  defp handle([:emissions, :adapter, :success], %{duration: d}, %{adapter: mod}, _) do
    Statix.timing("emissions.adapter.duration", native_to_ms(d), tags: ["adapter:#{mod}"])
    Statix.increment("emissions.adapter.success", tags: ["adapter:#{mod}"])
  end

  defp handle([:emissions, :adapter, :error], %{duration: d}, %{adapter: mod}, _) do
    Statix.timing("emissions.adapter.duration", native_to_ms(d), tags: ["adapter:#{mod}"])
    Statix.increment("emissions.adapter.error", tags: ["adapter:#{mod}"])
  end

  defp handle([:emissions, :handler, :success], %{duration: d}, %{handler: h, event: e}, _) do
    Statix.timing("emissions.handler.duration", native_to_ms(d),
      tags: ["handler:#{h}", "event:#{e}"]
    )
  end

  defp handle([:emissions, :handler, :error], _m, %{handler: h, event: e}, _) do
    Statix.increment("emissions.handler.error", tags: ["handler:#{h}", "event:#{e}"])
  end

  defp native_to_ms(native) do
    System.convert_time_unit(native, :native, :millisecond)
  end
end
```

### Producer overflow

`[:emissions, :pipeline, :discarded]` reports `%{count: discarded_events}` with `reason: :buffer_overflow`.
