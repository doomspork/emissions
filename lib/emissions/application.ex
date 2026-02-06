defmodule Emissions.Application do
  @moduledoc false

  use Application

  @impl Application
  def start(_type, _args) do
    children = [
      Emissions.BufferPool,
      Emissions.Pipeline.Producer,
      Emissions.Pipeline.AdapterSupervisor,
      {Task.Supervisor, name: Emissions.TaskSupervisor}
    ]

    opts = [strategy: :rest_for_one, name: Emissions.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
