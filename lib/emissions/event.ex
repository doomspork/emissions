defmodule Emissions.Event do
  @moduledoc """
  Struct representing an emitted event.

  Events are collected in a buffer and delivered to adapters as a batch
  when the buffer is committed.
  """

  @type t :: %__MODULE__{
          name: atom(),
          payload: term(),
          metadata: map(),
          timestamp: integer()
        }

  @enforce_keys [:name, :payload]
  defstruct [:name, :payload, metadata: %{}, timestamp: nil]

  @doc """
  Creates a new event with the current system timestamp in microseconds.
  """
  @spec new(atom(), term(), map()) :: t()
  def new(name, payload, metadata \\ %{}) do
    %__MODULE__{
      name: name,
      payload: payload,
      metadata: metadata,
      timestamp: System.system_time(:microsecond)
    }
  end
end
