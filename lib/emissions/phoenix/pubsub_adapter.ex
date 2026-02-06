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

    ## Options

      * `:pubsub` (required) — the `Phoenix.PubSub` server name.
      * `:topic_prefix` — prefix for all topic strings. Defaults to `"emissions"`.
      * `:topic_router` — a module that uses `Emissions.TopicRouter`. When set,
        events are also broadcast to their mapped topic group.
      * `:serializer` — a module implementing `Emissions.Phoenix.Serializer`.
        Defaults to `Emissions.Phoenix.DefaultSerializer`.
    """

    @behaviour Emissions.Adapter

    @impl true
    def init(opts) do
      case Keyword.fetch(opts, :pubsub) do
        {:ok, pubsub} ->
          state = %{
            pubsub: pubsub,
            topic_prefix: Keyword.get(opts, :topic_prefix, "emissions"),
            topic_router: Keyword.get(opts, :topic_router),
            serializer: Keyword.get(opts, :serializer, Emissions.Phoenix.DefaultSerializer)
          }

          {:ok, state}

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
      prefix = state.topic_prefix
      event_topic = "#{prefix}:#{event.name}"

      topics = [prefix, event_topic]

      case resolve_group_topic(event, state) do
        nil -> topics
        group_topic -> [group_topic | topics]
      end
    end

    defp resolve_group_topic(_event, %{topic_router: nil}), do: nil

    defp resolve_group_topic(event, %{topic_router: router, topic_prefix: prefix}) do
      case router.topic_for_event(event.name) do
        nil -> nil
        group -> "#{prefix}:#{group}"
      end
    end
  end
end
