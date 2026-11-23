defmodule Emissions.HandlerTest do
  use ExUnit.Case

  defmodule CounterHandler do
    use Emissions.Handler

    @impl true
    def events, do: [:order_created, :order_shipped]

    @impl true
    def handle_event(:order_created, _payload, _metadata), do: :ok
    def handle_event(:order_shipped, _payload, _metadata), do: :ok
  end

  defmodule IgnoringHandler do
    use Emissions.Handler

    @impl true
    def events, do: [:order_created]

    @impl true
    def handle_event(:order_created, _payload, _metadata), do: :ignored
  end

  defmodule BlockingHandler do
    use Emissions.Handler
    def events, do: [:wait]

    def handle_event(:wait, owner, _) do
      send(owner, {:started, self()})

      receive do
        :finish -> :ok
      end
    end
  end

  test "holds demand until bounded handler work completes" do
    event = Emissions.Event.new(:wait, self())
    state = %{handlers: [BlockingHandler], concurrency: 1}
    task = Task.async(fn -> Emissions.HandlerDispatcher.handle_events([event, event], state) end)
    assert_receive {:started, first}
    refute_receive {:started, _}
    send(first, :finish)
    assert_receive {:started, second}
    send(second, :finish)
    assert Task.await(task) == {:ok, state}
  end

  describe "using Emissions.Handler" do
    test "defines handles?/1 based on events/0" do
      assert CounterHandler.handles?(:order_created)
      assert CounterHandler.handles?(:order_shipped)
      refute CounterHandler.handles?(:unknown_event)
    end

    test "handler returns expected values" do
      assert :ok = CounterHandler.handle_event(:order_created, %{}, %{})
      assert :ignored = IgnoringHandler.handle_event(:order_created, %{}, %{})
    end
  end
end
