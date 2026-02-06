defmodule Emissions.HandlerDispatcher do
  @moduledoc """
  Adapter that dispatches events to internal event handlers.

  This module implements the `Emissions.Adapter` behaviour so it participates
  in the GenStage pipeline alongside other adapters. For each event, it finds
  matching handlers and runs them in supervised tasks.

  Each handler invocation gets its own event buffer, enabling handlers to emit
  cascading events.
  """

  @behaviour Emissions.Adapter

  require Logger

  @impl Emissions.Adapter
  def init(_opts) do
    handlers = Application.get_env(:emissions, :handlers, [])
    {:ok, %{handlers: handlers}}
  end

  @impl Emissions.Adapter
  def handle_events(events, state) do
    for event <- events do
      dispatch(event, state.handlers)
    end

    {:ok, state}
  end

  defp dispatch(event, handlers) do
    applicable = Enum.filter(handlers, &handler_matches?(&1, event.name))

    for handler <- applicable do
      Task.Supervisor.start_child(Emissions.TaskSupervisor, fn ->
        run_handler(handler, event)
      end)
    end
  end

  defp handler_matches?(handler, event_name) do
    handler.handles?(event_name)
  rescue
    error ->
      Logger.warning(
        "Handler #{inspect(handler)} raised in handles?/1: #{Exception.message(error)}"
      )

      false
  end

  defp run_handler(handler, event) do
    Emissions.start()
    start_time = System.monotonic_time()

    try do
      case handler.handle_event(event.name, event.payload, event.metadata) do
        :ok ->
          Emissions.commit()
          duration = System.monotonic_time() - start_time

          :telemetry.execute([:emissions, :handler, :success], %{duration: duration}, %{
            handler: handler,
            event: event.name
          })

        :ignored ->
          :telemetry.execute([:emissions, :handler, :ignored], %{count: 1}, %{
            handler: handler,
            event: event.name
          })

        {:error, reason} ->
          duration = System.monotonic_time() - start_time

          :telemetry.execute([:emissions, :handler, :error], %{duration: duration}, %{
            handler: handler,
            event: event.name,
            reason: reason
          })

          Logger.error("Handler #{inspect(handler)} failed on #{event.name}: #{inspect(reason)}")
      end
    rescue
      error ->
        Logger.error(
          "Handler #{inspect(handler)} raised on #{event.name}: #{Exception.message(error)}"
        )
    after
      Emissions.terminate()
    end
  end
end
