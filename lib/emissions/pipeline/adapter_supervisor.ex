defmodule Emissions.Pipeline.AdapterSupervisor do
  @moduledoc false

  # Supervises all adapter consumers (one per configured adapter, plus
  # the handler dispatcher). Uses :one_for_one so a crashed adapter
  # consumer restarts independently.

  use Supervisor

  alias Emissions.Pipeline.AdapterConsumer

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl Supervisor
  def init(_opts) do
    adapters = Application.get_env(:emissions, :adapters, [])
    handlers = Application.get_env(:emissions, :handlers, [])

    adapter_children =
      Enum.map(adapters, fn {mod, opts} ->
        {AdapterConsumer, {mod, opts}}
      end)

    handler_children =
      if handlers != [] do
        [{AdapterConsumer, {Emissions.HandlerDispatcher, []}}]
      else
        []
      end

    children = adapter_children ++ handler_children

    Supervisor.init(children, strategy: :one_for_one)
  end
end
