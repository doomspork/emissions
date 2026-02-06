defmodule Emissions.Handler do
  @moduledoc """
  Behaviour and macro for internal event handlers.

  Handlers subscribe to specific event names and process them in supervised
  tasks. Each handler invocation gets its own event buffer, allowing handlers
  to emit cascading events.

  ## Example

      defmodule MyApp.NotificationHandler do
        use Emissions.Handler

        @impl true
        def events, do: [:order_created, :order_shipped]

        @impl true
        def handle_event(:order_created, payload, _metadata) do
          send_notification("New order \#{payload.id}")
          :ok
        end

        def handle_event(:order_shipped, payload, _metadata) do
          send_notification("Order \#{payload.id} shipped")
          :ok
        end

        defp send_notification(msg), do: IO.puts(msg)
      end
  """

  @doc """
  Returns the list of event names this handler subscribes to.
  """
  @callback events() :: [atom()]

  @doc """
  Handles a single event.

  Return values:
  - `:ok` — event handled successfully, any cascading events are committed
  - `:ignored` — event was not relevant, no action taken
  - `{:error, reason}` — handling failed
  """
  @callback handle_event(name :: atom(), payload :: term(), metadata :: map()) ::
              :ok | :ignored | {:error, term()}

  defmacro __using__(_opts) do
    quote do
      @behaviour Emissions.Handler

      @doc false
      def handles?(event_name), do: event_name in events()

      defoverridable handles?: 1
    end
  end
end
