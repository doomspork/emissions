defmodule Emissions.Testing.TestAdapter do
  @moduledoc """
  Adapter that captures events for test assertions.

  Configure in `config/test.exs`:

      config :emissions,
        adapters: [{Emissions.Testing.TestAdapter, []}],
        handlers: []
  """

  @behaviour Emissions.Adapter

  @impl Emissions.Adapter
  def init(_opts) do
    Emissions.Testing.setup()
    {:ok, %{}}
  end

  @impl Emissions.Adapter
  def handle_events(events, state) do
    Emissions.Testing.record_events(events)
    {:ok, state}
  end
end
