# GenStage Pipeline

Emissions uses a GenStage pipeline to fan out committed events to all configured adapters using shared broadcast demand.

## Architecture

```mermaid
graph TD
    B[Emissions.Buffer] -->|"commit → notify(events)"| P[Pipeline.Producer]
    P -->|BroadcastDispatcher| C1[AdapterConsumer: Kafka]
    P -->|BroadcastDispatcher| C2[AdapterConsumer: WebSocket]
    P -->|BroadcastDispatcher| C3[AdapterConsumer: Webhook]
    P -->|BroadcastDispatcher| C4[AdapterConsumer: HandlerDispatcher]
    C4 --> H1[Handler Task 1]
    C4 --> H2[Handler Task 2]
    C4 --> H3[Handler Task N]

    style P fill:#4a9eff,color:#fff
    style C1 fill:#34d399,color:#fff
    style C2 fill:#34d399,color:#fff
    style C3 fill:#34d399,color:#fff
    style C4 fill:#f59e0b,color:#fff
```

## Producer

`Emissions.Pipeline.Producer` is a named GenStage producer that uses `GenStage.BroadcastDispatcher`. This dispatcher sends every event to every subscribed consumer, enabling true fan-out.

When a buffer commits, it calls `Producer.notify/1` which pushes events into the producer via `GenStage.cast`. The producer drains its internal queue in response to demand from consumers.

## Adapter Consumers

Each configured adapter is wrapped in an `Emissions.Pipeline.AdapterConsumer` — a GenStage consumer that subscribes to the producer. Each consumer:

1. Calls the adapter's `init/1` on startup
2. Subscribes to the producer with configurable `max_demand`
3. Optionally filters events via `interested?/2`
4. Delegates to `handle_events/2` for delivery
5. Reports success/failure via telemetry

## Backpressure

BroadcastDispatcher waits for demand from every subscribed consumer. A stalled adapter therefore delays delivery to healthy adapters once its outstanding demand is exhausted.

`commit/0` and `flush/0` acknowledge local, asynchronous handoff. The producer keeps up to `pipeline: [buffer_size: 10_000]` pending events by default. On overflow GenStage discards older buffered events, logs a warning and emits `[:emissions, :pipeline, :discarded]` with the discarded count. In-flight messages and request buffers are separate from this limit. Restarts and adapter failures can also lose events. For billing or other durable workflows, persist an outbox entry in the business transaction and retry delivery from that record.

## Supervision

```mermaid
graph TD
    S["Emissions.Supervisor<br/><i>rest_for_one</i>"]
    S --> BP["Emissions.BufferPool<br/><i>DynamicSupervisor</i>"]
    S --> PR["Pipeline.Producer<br/><i>GenStage</i>"]
    S --> AS["Pipeline.AdapterSupervisor<br/><i>one_for_one</i>"]
    S --> TS["Emissions.TaskSupervisor<br/><i>Task.Supervisor</i>"]

    BP -.->|dynamic| B1["Buffer 1"]
    BP -.->|dynamic| B2["Buffer 2"]
    BP -.->|dynamic| BN["Buffer N"]

    AS --> AC1["AdapterConsumer<br/>Adapter 1"]
    AS --> AC2["AdapterConsumer<br/>Adapter 2"]
    AS --> AH["AdapterConsumer<br/>HandlerDispatcher"]

    style S fill:#6366f1,color:#fff
    style BP fill:#4a9eff,color:#fff
    style PR fill:#4a9eff,color:#fff
    style AS fill:#4a9eff,color:#fff
    style TS fill:#4a9eff,color:#fff
```

The top-level supervisor uses `rest_for_one` strategy. If the producer crashes, all adapter consumers are restarted (since they subscribe to the producer). The `AdapterSupervisor` uses `one_for_one` so a single adapter crash doesn't affect others.

## Configuration

Tune the pipeline via the `:pipeline` config key:

```elixir
config :emissions,
  pipeline: [
    max_demand: 50   # events per consumer per batch (default: 50)
  ]
```

Higher `max_demand` means larger batches to adapters (better throughput, higher latency). Lower values mean smaller batches (lower latency, more overhead).

## Handler Dispatcher

The `Emissions.HandlerDispatcher` is a special adapter that dispatches events to internal handlers. It's automatically added to the pipeline when handlers are configured. It implements the same `Emissions.Adapter` behaviour, so it participates in the GenStage pipeline like any other adapter.
