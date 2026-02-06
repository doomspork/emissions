defmodule Emissions.Pipeline.AdapterConsumer do
  @moduledoc """
  GenStage consumer that wraps an `Emissions.Adapter` implementation.

  One consumer is started per configured adapter. Each subscribes to
  `Emissions.Pipeline.Producer` and independently manages demand,
  so a slow adapter won't block others.
  """

  use GenStage

  require Logger

  @doc false
  def start_link({adapter_mod, adapter_opts}) do
    GenStage.start_link(__MODULE__, {adapter_mod, adapter_opts})
  end

  @doc false
  def child_spec({adapter_mod, adapter_opts}) do
    %{
      id: {__MODULE__, adapter_mod, adapter_opts},
      start: {__MODULE__, :start_link, [{adapter_mod, adapter_opts}]},
      restart: :permanent
    }
  end

  ## GenStage callbacks

  @impl GenStage
  def init({adapter_mod, adapter_opts}) do
    pipeline_config = Application.get_env(:emissions, :pipeline, [])
    max_demand = Keyword.get(pipeline_config, :max_demand, 50)

    case adapter_mod.init(adapter_opts) do
      {:ok, adapter_state} ->
        {:consumer, %{adapter: adapter_mod, state: adapter_state},
         subscribe_to: [{Emissions.Pipeline.Producer, max_demand: max_demand}]}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl GenStage
  def handle_events(events, _from, %{adapter: adapter_mod, state: adapter_state} = consumer) do
    filtered = filter_events(events, adapter_mod, adapter_state)

    if filtered == [] do
      {:noreply, [], consumer}
    else
      start_time = System.monotonic_time()

      case adapter_mod.handle_events(filtered, adapter_state) do
        {:ok, new_state} ->
          duration = System.monotonic_time() - start_time

          :telemetry.execute([:emissions, :adapter, :success], %{duration: duration}, %{
            adapter: adapter_mod,
            event_count: length(filtered)
          })

          {:noreply, [], %{consumer | state: new_state}}

        {:error, reason, new_state} ->
          duration = System.monotonic_time() - start_time

          :telemetry.execute([:emissions, :adapter, :error], %{duration: duration}, %{
            adapter: adapter_mod,
            reason: reason,
            event_count: length(filtered)
          })

          Logger.error(
            "Adapter #{inspect(adapter_mod)} failed: #{inspect(reason)}",
            adapter: adapter_mod,
            reason: reason
          )

          {:noreply, [], %{consumer | state: new_state}}
      end
    end
  end

  defp filter_events(events, adapter_mod, adapter_state) do
    if function_exported?(adapter_mod, :interested?, 2) do
      Enum.filter(events, &adapter_mod.interested?(&1, adapter_state))
    else
      events
    end
  end
end
