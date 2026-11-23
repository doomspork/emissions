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

  defmodule CoreSerializer do
    @behaviour Emissions.Serializer

    @impl true
    def serialize(event) do
      %{event_type: event.name, event_data: event.payload}
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

    test "returns error when :scope is not an atom or function", %{pubsub: pubsub} do
      assert {:error, ":scope must be an atom or a 1-arity function"} =
               PubSubAdapter.init(pubsub: pubsub, scope: "tenant_123")
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

    test "accepts a top-level Emissions.Serializer implementation", %{pubsub: pubsub} do
      {:ok, state} = PubSubAdapter.init(pubsub: pubsub, serializer: CoreSerializer)
      Phoenix.PubSub.subscribe(pubsub, "emissions:order_created")

      event = Emissions.Event.new(:order_created, %{id: 1})
      assert {:ok, _state} = PubSubAdapter.handle_events([event], state)

      assert_receive {:emissions_event, payload}
      assert payload == %{event_type: :order_created, event_data: %{id: 1}}
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

  describe "scoped topics with :scope option" do
    test "scopes topics using metadata key", %{pubsub: pubsub} do
      {:ok, state} = PubSubAdapter.init(pubsub: pubsub, scope: :org_id)

      Phoenix.PubSub.subscribe(pubsub, "emissions:acme")
      Phoenix.PubSub.subscribe(pubsub, "emissions:acme:order_created")

      event = Emissions.Event.new(:order_created, %{id: 1}, %{org_id: "acme"})
      assert {:ok, _state} = PubSubAdapter.handle_events([event], state)

      assert_receive {:emissions_event, %{name: :order_created}}
      assert_receive {:emissions_event, %{name: :order_created}}
    end

    test "scopes topics using function", %{pubsub: pubsub} do
      scope_fn = fn event -> event.metadata[:tenant_id] end
      {:ok, state} = PubSubAdapter.init(pubsub: pubsub, scope: scope_fn)

      Phoenix.PubSub.subscribe(pubsub, "emissions:org123")
      Phoenix.PubSub.subscribe(pubsub, "emissions:org123:user_created")

      event = Emissions.Event.new(:user_created, %{id: 1}, %{tenant_id: "org123"})
      assert {:ok, _state} = PubSubAdapter.handle_events([event], state)

      assert_receive {:emissions_event, %{name: :user_created}}
      assert_receive {:emissions_event, %{name: :user_created}}
    end

    test "drops an event when the configured scope is missing", %{pubsub: pubsub} do
      {:ok, state} = PubSubAdapter.init(pubsub: pubsub, scope: :org_id)

      Phoenix.PubSub.subscribe(pubsub, "emissions")
      Phoenix.PubSub.subscribe(pubsub, "emissions:order_created")

      event = Emissions.Event.new(:order_created, %{id: 1}, %{})
      assert {:ok, _state} = PubSubAdapter.handle_events([event], state)

      refute_receive {:emissions_event, _payload}
    end

    test "scoped topics work with topic_router", %{pubsub: pubsub} do
      {:ok, state} =
        PubSubAdapter.init(pubsub: pubsub, scope: :org_id, topic_router: TestRouter)

      Phoenix.PubSub.subscribe(pubsub, "emissions:acme:orders")

      event = Emissions.Event.new(:order_created, %{id: 1}, %{org_id: "acme"})
      assert {:ok, _state} = PubSubAdapter.handle_events([event], state)

      assert_receive {:emissions_event, %{name: :order_created}}
    end

    test "different scopes receive only their events", %{pubsub: pubsub} do
      {:ok, state} = PubSubAdapter.init(pubsub: pubsub, scope: :org_id)

      Phoenix.PubSub.subscribe(pubsub, "emissions:acme")
      Phoenix.PubSub.subscribe(pubsub, "emissions:globex")

      events = [
        Emissions.Event.new(:order_created, %{id: 1}, %{org_id: "acme"}),
        Emissions.Event.new(:order_created, %{id: 2}, %{org_id: "globex"})
      ]

      assert {:ok, _state} = PubSubAdapter.handle_events(events, state)

      assert_receive {:emissions_event, %{payload: %{id: 1}}}
      assert_receive {:emissions_event, %{payload: %{id: 2}}}
      refute_receive {:emissions_event, _payload}
    end

    test "does not broadcast to unscoped topics when scope is present", %{pubsub: pubsub} do
      {:ok, state} = PubSubAdapter.init(pubsub: pubsub, scope: :org_id)

      Phoenix.PubSub.subscribe(pubsub, "emissions")
      Phoenix.PubSub.subscribe(pubsub, "emissions:order_created")

      event = Emissions.Event.new(:order_created, %{id: 1}, %{org_id: "acme"})
      assert {:ok, _state} = PubSubAdapter.handle_events([event], state)

      refute_receive {:emissions_event, _payload}
    end

    test "preserves backwards compatibility when scope not configured", %{pubsub: pubsub} do
      {:ok, state} = PubSubAdapter.init(pubsub: pubsub)

      Phoenix.PubSub.subscribe(pubsub, "emissions")
      Phoenix.PubSub.subscribe(pubsub, "emissions:order_created")

      event = Emissions.Event.new(:order_created, %{id: 1}, %{org_id: "acme"})
      assert {:ok, _state} = PubSubAdapter.handle_events([event], state)

      assert_receive {:emissions_event, _payload}
      assert_receive {:emissions_event, _payload}
    end

    test "custom topic_prefix composes with scope", %{pubsub: pubsub} do
      {:ok, state} =
        PubSubAdapter.init(pubsub: pubsub, scope: :org_id, topic_prefix: "events")

      Phoenix.PubSub.subscribe(pubsub, "events:acme")
      Phoenix.PubSub.subscribe(pubsub, "events:acme:order_created")

      event = Emissions.Event.new(:order_created, %{id: 1}, %{org_id: "acme"})
      assert {:ok, _state} = PubSubAdapter.handle_events([event], state)

      assert_receive {:emissions_event, _payload}
      assert_receive {:emissions_event, _payload}
    end
  end
end
