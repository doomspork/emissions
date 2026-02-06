defmodule Emissions.BufferPool do
  @moduledoc """
  DynamicSupervisor that manages per-request `Emissions.Buffer` processes.

  Started as part of the Emissions supervision tree. Buffers are added and
  removed dynamically as requests start and complete.
  """

  use DynamicSupervisor

  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl DynamicSupervisor
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
