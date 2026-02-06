# GenStage Pipeline

Emissions uses a GenStage pipeline to fan out committed events to all configured adapters with independent backpressure per consumer.

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

```mermaid
sequenceDiagram
    participant P as Producer
    participant Fast as Fast Consumer (WebSocket)
    participant Slow as Slow Consumer (Kafka)

    Fast->>P: demand(50)
    Slow->>P: demand(10)
    Note over P: Receives committed events
    P->>Fast: 50 events
    P->>Slow: 10 events
    Fast->>P: demand(50)
    Note over Slow: Still processing...
    P->>Fast: 50 events
    Slow->>P: demand(10)
    P->>Slow: 10 events
```

GenStage's demand-driven flow means each consumer independently controls how fast it receives events:

- A fast WebSocket adapter can process events immediately
- A slow Kafka adapter under load naturally applies backpressure
- The slow adapter does not block the fast one — each manages its own demand
- If all consumers are slow, the producer buffers events internally

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
