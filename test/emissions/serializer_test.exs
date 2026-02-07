defmodule Emissions.SerializerTest do
  use ExUnit.Case, async: true

  alias Emissions.Phoenix.DefaultSerializer, as: PhoenixDefault
  alias Emissions.Serializer.Default

  defmodule BinarySerializer do
    @behaviour Emissions.Serializer

    @impl true
    def serialize(event) do
      :erlang.term_to_binary(%{name: event.name, payload: event.payload})
    end
  end

  defmodule CompactSerializer do
    @behaviour Emissions.Serializer

    @impl true
    def serialize(event) do
      %{type: event.name, data: event.payload, ts: event.timestamp}
    end
  end

  describe "Emissions.Serializer.Default" do
    test "converts event to map with all fields" do
      event = Emissions.Event.new(:order_created, %{id: 1}, %{source: "api"})
      result = Default.serialize(event)

      assert result.name == :order_created
      assert result.payload == %{id: 1}
      assert result.metadata == %{source: "api"}
      assert is_integer(result.timestamp)
    end

    test "handles empty metadata" do
      event = Emissions.Event.new(:test_event, %{value: 42})
      result = Default.serialize(event)

      assert result.name == :test_event
      assert result.payload == %{value: 42}
      assert result.metadata == %{}
    end

    test "preserves all payload data" do
      payload = %{id: 1, items: [%{sku: "A1", qty: 2}], total: 99.99}
      event = Emissions.Event.new(:order_created, payload)
      result = Default.serialize(event)

      assert result.payload == payload
    end
  end

  describe "custom serializer returning binary" do
    test "serialize/1 returns binary data" do
      event = Emissions.Event.new(:test, %{value: 1})
      result = BinarySerializer.serialize(event)

      assert is_binary(result)
      assert :erlang.binary_to_term(result) == %{name: :test, payload: %{value: 1}}
    end
  end

  describe "custom serializer returning map with different keys" do
    test "serialize/1 returns map with custom keys" do
      event = Emissions.Event.new(:order_created, %{id: 1})
      result = CompactSerializer.serialize(event)

      assert result.type == :order_created
      assert result.data == %{id: 1}
      assert is_integer(result.ts)
      refute Map.has_key?(result, :name)
      refute Map.has_key?(result, :metadata)
    end
  end

  describe "Emissions.Phoenix.DefaultSerializer delegation" do
    test "produces identical output to Emissions.Serializer.Default" do
      event = Emissions.Event.new(:order_created, %{id: 1}, %{source: "api"})

      assert Default.serialize(event) == PhoenixDefault.serialize(event)
    end
  end
end
