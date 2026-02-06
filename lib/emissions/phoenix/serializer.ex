if Code.ensure_loaded?(Phoenix.PubSub) do
  defmodule Emissions.Phoenix.Serializer do
    @moduledoc """
    Behaviour for serializing `Emissions.Event` structs into maps suitable
    for transmission over Phoenix Channels.

    The default implementation (`Emissions.Phoenix.DefaultSerializer`) converts
    events into JSON-friendly maps. Implement this behaviour to customize the
    wire format — for example, to filter sensitive fields, rename keys, or
    conform to a specific schema.

    ## Example

        defmodule MyApp.EmissionsSerializer do
          @behaviour Emissions.Phoenix.Serializer

          @impl true
          def serialize(event) do
            %{
              type: event.name,
              data: event.payload,
              occurred_at: event.timestamp
            }
          end
        end

    Then configure the adapter:

        config :emissions,
          adapters: [
            {Emissions.Phoenix.PubSubAdapter,
             pubsub: MyApp.PubSub,
             serializer: MyApp.EmissionsSerializer}
          ]
    """

    @callback serialize(event :: Emissions.Event.t()) :: map()
  end

  defmodule Emissions.Phoenix.DefaultSerializer do
    @moduledoc """
    Default serializer that converts `Emissions.Event` structs into JSON-friendly maps.

    Produces maps with the keys `name`, `payload`, `metadata`, and `timestamp`.
    """

    @behaviour Emissions.Phoenix.Serializer

    @impl true
    def serialize(%Emissions.Event{} = event) do
      %{
        name: event.name,
        payload: event.payload,
        metadata: event.metadata,
        timestamp: event.timestamp
      }
    end
  end
end
