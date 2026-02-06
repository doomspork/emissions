defmodule Emissions.BufferPool do
  @moduledoc false

  # DynamicSupervisor that manages per-request Buffer processes.
  # Started as part of the Emissions supervision tree.

  use DynamicSupervisor

  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl DynamicSupervisor
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
