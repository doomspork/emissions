# Topic Routing

The `Emissions.TopicRouter` macro provides compile-time event-to-topic mapping. This is useful when adapters need to route events to different destinations based on their logical topic.

## Defining a Router

```elixir
defmodule MyApp.Topics do
  use Emissions.TopicRouter,
    mappings: %{
      orders: [:order_created, :order_updated, :order_shipped, :order_canceled],
      inventory: [:item_received, :item_adjusted, :item_moved, :item_transferred],
      users: [:user_created, :user_updated, :user_deactivated],
      shipping: [:parcel_created, :parcel_shipped, :shipment_created]
    }
end
```

## API

### `topic_for_event/1`

Returns the topic for a given event name, or `nil` if unmapped:

```elixir
MyApp.Topics.topic_for_event(:order_created)
#=> :orders

MyApp.Topics.topic_for_event(:unknown_event)
#=> nil
```

### `topics/0`

Returns all configured topic names:

```elixir
MyApp.Topics.topics()
#=> [:orders, :inventory, :users, :shipping]
```

### `events_for_topic/1`

Returns all events for a given topic:

```elixir
MyApp.Topics.events_for_topic(:orders)
#=> [:order_created, :order_updated, :order_shipped, :order_canceled]

MyApp.Topics.events_for_topic(:nonexistent)
#=> []
```

## Using with Adapters

Adapters can use the topic router to determine where to send events:

```elixir
defmodule MyApp.KafkaAdapter do
  @behaviour Emissions.Adapter

  @impl true
  def init(opts) do
    {:ok, %{prefix: Keyword.get(opts, :prefix, "events")}}
  end

  @impl true
  def handle_events(events, state) do
    for event <- events do
      case MyApp.Topics.topic_for_event(event.name) do
        nil ->
          :skip

        topic ->
          kafka_topic = "#{state.prefix}.#{topic}"
          MyApp.Kafka.produce(kafka_topic, Jason.encode!(event.payload))
      end
    end

    {:ok, state}
  end
end
```

## How It Works

The router is computed at compile time. The `mappings` are inverted into a flat `%{event_name => topic}` map stored as a module attribute. Lookups are O(1) `Map.get/2` calls with zero runtime overhead.

## Topic Routing is Optional

Topic routing is entirely opt-in. Adapters that don't need topic-based routing can ignore it entirely. The router is a standalone module with no coupling to the core pipeline.
