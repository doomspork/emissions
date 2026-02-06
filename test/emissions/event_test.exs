defmodule Emissions.EventTest do
  use ExUnit.Case

  alias Emissions.Event

  describe "new/3" do
    test "creates an event with name, payload, and metadata" do
      event = Event.new(:order_created, %{id: 1}, %{source: "api"})

      assert event.name == :order_created
      assert event.payload == %{id: 1}
      assert event.metadata == %{source: "api"}
      assert is_integer(event.timestamp)
    end

    test "defaults metadata to empty map" do
      event = Event.new(:test, %{})

      assert event.metadata == %{}
    end

    test "sets a system timestamp in microseconds" do
      before = System.system_time(:microsecond)
      event = Event.new(:test, %{})
      after_time = System.system_time(:microsecond)

      assert event.timestamp >= before
      assert event.timestamp <= after_time
    end
  end
end
