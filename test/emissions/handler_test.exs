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
