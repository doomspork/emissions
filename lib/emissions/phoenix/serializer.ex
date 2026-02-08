if Code.ensure_loaded?(Phoenix.PubSub) do
  defmodule Emissions.Phoenix.Serializer do
    @moduledoc """
    Specialization of `Emissions.Serializer` for Phoenix Channels.

    This behaviour narrows the return type to `map()` to align with the
    typical Phoenix Channels JSON encoding over WebSockets, which expects
    map payloads when pushing to clients. `Phoenix.PubSub.broadcast/3` itself
    can carry any Elixir term; this module standardizes on maps for
    channel-facing payloads.

    For adapters that need binary, string, or other output formats, use
    `Emissions.Serializer` directly.

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
    Default serializer for Phoenix Channels.

    Delegates to `Emissions.Serializer.Default` which produces JSON-friendly maps
    with `name`, `payload`, `metadata`, and `timestamp` keys.
    """

    @behaviour Emissions.Phoenix.Serializer

    @impl true
    defdelegate serialize(event), to: Emissions.Serializer.Default
  end
end
