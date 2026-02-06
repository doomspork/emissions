# GenStage Pipeline

Emissions uses a GenStage pipeline to fan out committed events to all configured adapters with independent backpressure per consumer.

## Architecture

```
Emissions.Buffer (GenServer)
    │ commit/0 calls Producer.notify/1
    ▼
Emissions.Pipeline.Producer (GenStage :producer)
    │ BroadcastDispatcher
    ├──► AdapterConsumer wrapping KafkaAdapter
    ├──► AdapterConsumer wrapping WebSocketAdapter
    ├──► AdapterConsumer wrapping WebhookAdapter
    └──► AdapterConsumer wrapping HandlerDispatcher
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

GenStage's demand-driven flow means each consumer independently controls how fast it receives events:

- A fast WebSocket adapter can process events immediately
- A slow Kafka adapter under load naturally applies backpressure
- The slow adapter does not block the fast one — each manages its own demand
- If all consumers are slow, the producer buffers events internally

## Supervision

```
Emissions.Supervisor (rest_for_one)
├── Emissions.BufferPool (DynamicSupervisor)
├── Emissions.Pipeline.Producer (GenStage)
├── Emissions.Pipeline.AdapterSupervisor (one_for_one)
│   ├── AdapterConsumer (adapter 1)
│   ├── AdapterConsumer (adapter 2)
│   └── AdapterConsumer (handler dispatcher)
└── Emissions.TaskSupervisor (Task.Supervisor)
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
