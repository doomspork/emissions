defmodule Emissions.TopicRouter do
  @moduledoc """
  Optional module for mapping event names to topics.

  Use this in your application to define a compile-time mapping from event
  names to logical topics. Adapters can then use the router to determine
  which topic an event belongs to.

  ## Example

      defmodule MyApp.Topics do
        use Emissions.TopicRouter,
          mappings: %{
            orders: [:order_created, :order_updated, :order_shipped],
            inventory: [:item_received, :item_adjusted, :item_moved],
            users: [:user_created, :user_updated]
          }
      end

      MyApp.Topics.topic_for_event(:order_created)
      #=> :orders

      MyApp.Topics.topics()
      #=> [:orders, :inventory, :users]
  """

  @doc false
  def __build_topic_map__(mappings) do
    mappings
    |> Enum.flat_map(fn {topic, events} -> Enum.map(events, &{&1, topic}) end)
    |> Enum.reduce(%{}, fn {event, topic}, acc ->
      validate_no_duplicate!(acc, event, topic)
      Map.put(acc, event, topic)
    end)
  end

  defp validate_no_duplicate!(map, event, topic) do
    case Map.fetch(map, event) do
      {:ok, existing} ->
        raise ArgumentError,
              "event #{inspect(event)} is mapped to both #{inspect(existing)} and #{inspect(topic)}"

      :error ->
        :ok
    end
  end

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @mappings Keyword.get(opts, :mappings, %{})

      @topic_by_event Emissions.TopicRouter.__build_topic_map__(@mappings)

      @doc """
      Returns the topic for the given event name, or `nil` if unmapped.
      """
      @spec topic_for_event(atom()) :: atom() | nil
      def topic_for_event(event), do: Map.get(@topic_by_event, event)

      @doc """
      Returns all configured topic names.
      """
      @spec topics() :: [atom()]
      def topics, do: Map.keys(@mappings)

      @doc """
      Returns all events for a given topic, or `[]` if the topic doesn't exist.
      """
      @spec events_for_topic(atom()) :: [atom()]
      def events_for_topic(topic), do: Map.get(@mappings, topic, [])
    end
  end
end
