# Testing

Emissions includes test helpers for capturing emitted events and making assertions in your test suite.

## Setup

### 1. Configure the Test Adapter

```elixir
# config/test.exs
config :emissions,
  adapters: [{Emissions.Testing.TestAdapter, []}],
  handlers: []
```

### 2. Initialize the Event Store

```elixir
# test/test_helper.exs
Emissions.Testing.setup()
ExUnit.start()
```

### 3. Reset Between Tests

```elixir
setup do
  Emissions.Testing.reset()
  :ok
end
```

## Assertions

Import `Emissions.Testing` to use the assertion macros:

```elixir
defmodule MyApp.OrdersTest do
  use ExUnit.Case
  import Emissions.Testing

  setup do
    Emissions.Testing.reset()
    :ok
  end

  test "creating an order emits order_created" do
    MyApp.Orders.create(%{item: "widget", qty: 5})

    assert_emitted(:order_created)
  end

  test "can assert on event payload" do
    MyApp.Orders.create(%{item: "widget", qty: 5})

    assert_emitted(:order_created, fn event ->
      assert event.payload.item == "widget"
      assert event.payload.qty == 5
    end)
  end

  test "failed operations don't emit events" do
    MyApp.Orders.create(%{invalid: true})

    refute_emitted(:order_created)
  end
end
```

### `assert_emitted/1`

Asserts that at least one event with the given name was emitted:

```elixir
assert_emitted(:order_created)
```

### `assert_emitted/2`

Asserts the event was emitted and runs a function on each matching event for further assertions:

```elixir
assert_emitted(:order_created, fn event ->
  assert event.payload.total > 0
  assert event.metadata.source == "api"
end)
```

### `refute_emitted/1`

Asserts that no event with the given name was emitted:

```elixir
refute_emitted(:order_canceled)
```

## Querying Events

For more complex assertions, query the event store directly:

```elixir
# Get all captured events
events = Emissions.Testing.get_events()

# Get events by name
order_events = Emissions.Testing.events_named(:order_created)

# Check if an event was emitted
Emissions.Testing.emitted?(:order_created)
```

## Async Considerations

Because events flow through a GenStage pipeline, there is a small delay between `commit/0` and events arriving at the test adapter. If your tests assert immediately after the code under test runs, you may need a brief wait:

```elixir
test "events arrive after pipeline processes them" do
  MyApp.Orders.create(%{item: "widget"})

  # Allow the GenStage pipeline to deliver
  Process.sleep(50)

  assert_emitted(:order_created)
end
```

If your code under test already calls `Emissions.commit()` and the test calls the code synchronously, this is typically sufficient. The 50ms sleep is a conservative safety margin.

## Testing Handlers

To test handlers in isolation, call them directly without the pipeline:

```elixir
test "handler processes order_created" do
  result = MyApp.SearchIndexHandler.handle_event(
    :order_created,
    %{id: 1, name: "Widget"},
    %{}
  )

  assert result == :ok
end
```

To test handlers with cascading events, start a buffer first:

```elixir
test "handler emits cascading events" do
  Emissions.start()
  result = MyApp.FulfillmentHandler.handle_event(:order_created, order, %{})
  assert result == :ok
  Emissions.commit()

  Process.sleep(50)
  assert_emitted(:order_fulfillable)
end
```
