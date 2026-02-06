defmodule Emissions.Phoenix.PubSubAdapterTest do
  use ExUnit.Case, async: true

  alias Emissions.Phoenix.PubSubAdapter

  defmodule TestRouter do
    use Emissions.TopicRouter,
      mappings: %{
        orders: [:order_created, :order_updated],
        users: [:user_created]
      }
  end

  defmodule CustomSerializer do
    @behaviour Emissions.Phoenix.Serializer

    @impl true
    def serialize(event) do
      %{type: event.name, data: event.payload}
    end
  end

  setup do
    pubsub = :"test_pubsub_#{System.unique_integer([:positive])}"
    start_supervised!({Phoenix.PubSub, name: pubsub})
    {:ok, pubsub: pubsub}
  end

  describe "init/1" do
    test "succeeds with required :pubsub option", %{pubsub: pubsub} do
      assert {:ok, state} = PubSubAdapter.init(pubsub: pubsub)
      assert state.pubsub == pubsub
      assert state.topic_prefix == "emissions"
      assert state.topic_router == nil
      assert state.serializer == Emissions.Phoenix.DefaultSerializer
    end

    test "accepts optional configuration", %{pubsub: pubsub} do
      assert {:ok, state} =
               PubSubAdapter.init(
                 pubsub: pubsub,
                 topic_prefix: "events",
                 topic_router: TestRouter,
                 serializer: CustomSerializer
               )

      assert state.topic_prefix == "events"
      assert state.topic_router == TestRouter
      assert state.serializer == CustomSerializer
    end

    test "returns error when :pubsub is missing" do
      assert {:error, ":pubsub option is required"} = PubSubAdapter.init([])
    end
  end

  describe "handle_events/2" do
    test "broadcasts to event-name topic", %{pubsub: pubsub} do
      {:ok, state} = PubSubAdapter.init(pubsub: pubsub)
      Phoenix.PubSub.subscribe(pubsub, "emissions:order_created")

      event = Emissions.Event.new(:order_created, %{id: 1})
      assert {:ok, _state} = PubSubAdapter.handle_events([event], state)

      assert_receive {:emissions_event, payload}
      assert payload.name == :order_created
      assert payload.payload == %{id: 1}
    end

    test "broadcasts to catch-all topic", %{pubsub: pubsub} do
      {:ok, state} = PubSubAdapter.init(pubsub: pubsub)
      Phoenix.PubSub.subscribe(pubsub, "emissions")

      event = Emissions.Event.new(:order_created, %{id: 1})
      assert {:ok, _state} = PubSubAdapter.handle_events([event], state)

      assert_receive {:emissions_event, payload}
      assert payload.name == :order_created
    end

    test "broadcasts to topic-group when topic_router is configured", %{pubsub: pubsub} do
      {:ok, state} = PubSubAdapter.init(pubsub: pubsub, topic_router: TestRouter)
      Phoenix.PubSub.subscribe(pubsub, "emissions:orders")

      event = Emissions.Event.new(:order_created, %{id: 1})
      assert {:ok, _state} = PubSubAdapter.handle_events([event], state)

      assert_receive {:emissions_event, payload}
      assert payload.name == :order_created
    end

    test "does not broadcast to topic-group for unmapped events", %{pubsub: pubsub} do
      {:ok, state} = PubSubAdapter.init(pubsub: pubsub, topic_router: TestRouter)
      Phoenix.PubSub.subscribe(pubsub, "emissions:unmapped_event")

      event = Emissions.Event.new(:unmapped_event, %{})
      assert {:ok, _state} = PubSubAdapter.handle_events([event], state)

      # Should receive on event-name topic
      assert_receive {:emissions_event, _payload}

      # Should NOT receive on a group topic (no group exists for this event)
      Phoenix.PubSub.subscribe(pubsub, "emissions:some_group")
      refute_receive {:emissions_event, _payload}
    end

    test "uses custom topic prefix", %{pubsub: pubsub} do
      {:ok, state} = PubSubAdapter.init(pubsub: pubsub, topic_prefix: "my_events")
      Phoenix.PubSub.subscribe(pubsub, "my_events:order_created")
      Phoenix.PubSub.subscribe(pubsub, "my_events")

      event = Emissions.Event.new(:order_created, %{id: 1})
      assert {:ok, _state} = PubSubAdapter.handle_events([event], state)

      assert_receive {:emissions_event, _payload}
      assert_receive {:emissions_event, _payload}
    end

    test "uses custom serializer", %{pubsub: pubsub} do
      {:ok, state} = PubSubAdapter.init(pubsub: pubsub, serializer: CustomSerializer)
      Phoenix.PubSub.subscribe(pubsub, "emissions:order_created")

      event = Emissions.Event.new(:order_created, %{id: 1})
      assert {:ok, _state} = PubSubAdapter.handle_events([event], state)

      assert_receive {:emissions_event, payload}
      assert payload == %{type: :order_created, data: %{id: 1}}
    end

    test "broadcasts multiple events", %{pubsub: pubsub} do
      {:ok, state} = PubSubAdapter.init(pubsub: pubsub)
      Phoenix.PubSub.subscribe(pubsub, "emissions")

      events = [
        Emissions.Event.new(:order_created, %{id: 1}),
        Emissions.Event.new(:user_created, %{id: 2})
      ]

      assert {:ok, _state} = PubSubAdapter.handle_events(events, state)

      assert_receive {:emissions_event, %{name: :order_created}}
      assert_receive {:emissions_event, %{name: :user_created}}
    end

    test "includes metadata and timestamp in default serialization", %{pubsub: pubsub} do
      {:ok, state} = PubSubAdapter.init(pubsub: pubsub)
      Phoenix.PubSub.subscribe(pubsub, "emissions:test_event")

      event = Emissions.Event.new(:test_event, %{value: 42}, %{source: "api"})
      assert {:ok, _state} = PubSubAdapter.handle_events([event], state)

      assert_receive {:emissions_event, payload}
      assert payload.metadata == %{source: "api"}
      assert is_integer(payload.timestamp)
    end
  end
end
