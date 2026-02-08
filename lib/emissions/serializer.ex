defmodule Emissions.Serializer do
  @moduledoc """
  Behaviour for serializing `Emissions.Event` structs before delivery.

  Adapters that need to transform events before delivery can accept a
  `:serializer` option and delegate to it. The return type is intentionally
  `term()` so serializers can produce maps, binaries (Avro, Protobuf), JSON
  strings, or any other format the adapter requires.

  When no serializer is configured, adapters should default to
  `Emissions.Serializer.Default`, which produces JSON-friendly maps.

  ## Example

      defmodule MyApp.CompactSerializer do
        @behaviour Emissions.Serializer

        @impl true
        def serialize(event) do
          %{
            type: event.name,
            data: event.payload,
            ts: event.timestamp
          }
        end
      end

  Then configure the adapter:

      config :emissions,
        adapters: [
          {MyApp.WebhookAdapter,
           url: "https://hooks.example.com/events",
           serializer: MyApp.CompactSerializer}
        ]

  ## Built-in Serializer

  `Emissions.Serializer.Default` converts events into JSON-friendly maps with
  `name`, `payload`, `metadata`, and `timestamp` keys. It is used automatically
  when no serializer is configured.

  ## Phoenix Channels

  For Phoenix Channels specifically, see `Emissions.Phoenix.Serializer` which
  narrows the return type to `map()` for compatibility with PubSub broadcasting.
  """

  @doc """
  Serializes an `Emissions.Event` for delivery.

  The return type depends on what the target adapter expects — maps, binaries,
  strings, or any other term.
  """
  @callback serialize(event :: Emissions.Event.t()) :: term()
end
