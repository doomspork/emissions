defmodule Emissions.Serializer.Default do
  @moduledoc """
  Default serializer that converts `Emissions.Event` structs into JSON-friendly maps.

  Produces maps with the keys `name`, `payload`, `metadata`, and `timestamp`.
  This serializer is used automatically when no explicit serializer is configured.
  """

  @behaviour Emissions.Serializer

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
