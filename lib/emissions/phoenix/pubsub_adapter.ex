if Code.ensure_loaded?(Phoenix.PubSub) do
  defmodule Emissions.Phoenix.PubSubAdapter do
    @moduledoc """
    Adapter that broadcasts events to Phoenix.PubSub topics.

    Events are serialized and broadcast to multiple PubSub topics at three
    granularity levels, allowing WebSocket clients to subscribe at the scope
    that suits them.

    ## Topic Hierarchy

    Each event is broadcast to up to three topics:

    1. **Catch-all** — `"emissions"` — receives every event
    2. **Topic group** — `"emissions:orders"` — receives events mapped by a
       `Emissions.TopicRouter` (only when `:topic_router` is configured)
    3. **Event name** — `"emissions:order_created"` — receives a single event type

    The prefix (`"emissions"` by default) is configurable via `:topic_prefix`.

    ## Configuration

        config :emissions,
          adapters: [
            {Emissions.Phoenix.PubSubAdapter,
             pubsub: MyApp.PubSub,
             topic_prefix: "emissions",
             topic_router: MyApp.Topics,
             serializer: Emissions.Phoenix.DefaultSerializer}
          ]

    ## Multi-Tenant Scoping

    For multi-tenant applications, configure the `:scope` option to insert a
    tenant segment into all topic strings. The scope can be an atom (metadata
    key) or a 1-arity function that receives the event:

        config :emissions,
          adapters: [
            {Emissions.Phoenix.PubSubAdapter,
             pubsub: MyApp.PubSub,
             scope: :org_id}
          ]

    An event emitted with `%{org_id: "acme"}` metadata then broadcasts to:

    1. `"emissions:acme"` — scoped catch-all
    2. `"emissions:acme:orders"` — scoped topic group
    3. `"emissions:acme:order_created"` — scoped event name

    When the scope resolves to `nil` (or is not configured), topics remain
    unscoped for backwards compatibility.

    ## Options

      * `:pubsub` (required) — the `Phoenix.PubSub` server name.
      * `:topic_prefix` — prefix for all topic strings. Defaults to `"emissions"`.
      * `:scope` — atom (metadata key) or 1-arity function to resolve a tenant
        scope from each event. When present and non-nil, all topics include the
        scope segment.
      * `:topic_router` — a module that uses `Emissions.TopicRouter`. When set,
        events are also broadcast to their mapped topic group.
      * `:serializer` — a module implementing `Emissions.Serializer` (or the
        narrower `Emissions.Phoenix.Serializer` for map-only output). Defaults
        to `Emissions.Phoenix.DefaultSerializer`.
    """

    @behaviour Emissions.Adapter

    @impl true
    def init(opts) do
      scope = Keyword.get(opts, :scope)

      case Keyword.fetch(opts, :pubsub) do
        {:ok, pubsub} when is_nil(scope) or is_atom(scope) or is_function(scope, 1) ->
          state = %{
            pubsub: pubsub,
            topic_prefix: Keyword.get(opts, :topic_prefix, "emissions"),
            scope: scope,
            topic_router: Keyword.get(opts, :topic_router),
            serializer: Keyword.get(opts, :serializer, Emissions.Phoenix.DefaultSerializer)
          }

          {:ok, state}

        {:ok, _pubsub} ->
          {:error, ":scope must be an atom or a 1-arity function"}

        :error ->
          {:error, ":pubsub option is required"}
      end
    end

    @impl true
    def handle_events(events, state) do
      Enum.each(events, &broadcast_event(&1, state))
      {:ok, state}
    end

    defp broadcast_event(event, state) do
      payload = state.serializer.serialize(event)
      message = {:emissions_event, payload}

      event
      |> resolve_topics(state)
      |> Enum.each(&Phoenix.PubSub.broadcast(state.pubsub, &1, message))
    end

    defp resolve_topics(event, state) do
      prefix =
        case resolve_scope(event, state) do
          nil -> state.topic_prefix
          scope_value -> "#{state.topic_prefix}:#{scope_value}"
        end

      event_topic = "#{prefix}:#{event.name}"
      topics = [prefix, event_topic]

      case resolve_group_topic(event, state, prefix) do
        nil -> topics
        group_topic -> [group_topic | topics]
      end
    end

    defp resolve_scope(_event, %{scope: nil}), do: nil

    defp resolve_scope(event, %{scope: key}) when is_atom(key) do
      Map.get(event.metadata, key)
    end

    defp resolve_scope(event, %{scope: fun}) when is_function(fun, 1) do
      fun.(event)
    end

    defp resolve_group_topic(_event, %{topic_router: nil}, _prefix), do: nil

    defp resolve_group_topic(event, %{topic_router: router}, prefix) do
      case router.topic_for_event(event.name) do
        nil -> nil
        group -> "#{prefix}:#{group}"
      end
    end
  end
end
