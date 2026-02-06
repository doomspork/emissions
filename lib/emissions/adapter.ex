defmodule Emissions.Adapter do
  @moduledoc """
  Behaviour for event delivery adapters.

  Adapters receive batches of events from the GenStage pipeline and deliver
  them to external systems (Kafka, WebSockets, webhooks, etc.).

  ## Example

      defmodule MyApp.LogAdapter do
        @behaviour Emissions.Adapter

        require Logger

        @impl true
        def init(opts) do
          level = Keyword.get(opts, :level, :info)
          {:ok, %{level: level}}
        end

        @impl true
        def handle_events(events, state) do
          for event <- events do
            Logger.log(state.level, "Event: \#{event.name} payload=\#{inspect(event.payload)}")
          end

          {:ok, state}
        end
      end
  """

  @doc """
  Called once when the adapter consumer starts.

  Returns `{:ok, state}` where `state` is passed to subsequent callbacks.
  """
  @callback init(opts :: keyword()) :: {:ok, state :: term()} | {:error, reason :: term()}

  @doc """
  Receives a batch of committed events for delivery.

  Return `{:ok, new_state}` on success or `{:error, reason, new_state}` on failure.
  """
  @callback handle_events(events :: [Emissions.Event.t()], state :: term()) ::
              {:ok, state :: term()} | {:error, reason :: term(), state :: term()}

  @doc """
  Optional callback to filter events this adapter cares about.

  When implemented, only events for which this returns `true` are passed to
  `handle_events/2`. When not implemented, all events are delivered.
  """
  @callback interested?(event :: Emissions.Event.t(), state :: term()) :: boolean()

  @optional_callbacks [interested?: 2]
end
