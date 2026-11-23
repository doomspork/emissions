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
    limit = Application.get_env(:emissions, :handler_concurrency, System.schedulers_online())

    if is_integer(limit) and limit > 0 do
      {:ok, %{handlers: handlers, concurrency: limit}}
    else
      {:error, :invalid_handler_concurrency}
    end
  end

  @impl Emissions.Adapter
  def handle_events(events, state) do
    jobs =
      for event <- events,
          handler <- state.handlers,
          handler_matches?(handler, event.name),
          do: {handler, event}

    Emissions.TaskSupervisor
    |> Task.Supervisor.async_stream_nolink(
      jobs,
      fn {handler, event} -> run_handler(handler, event) end,
      max_concurrency: state.concurrency,
      ordered: false,
      timeout: :infinity
    )
    |> Stream.run()

    {:ok, state}
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
