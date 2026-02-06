defmodule Emissions.Pipeline.Producer do
  @moduledoc """
  GenStage producer that receives committed event batches and fans them out
  to all adapter consumers via `BroadcastDispatcher`.

  Events are pushed into this producer by `Emissions.Buffer` on commit.
  Each adapter consumer subscribes independently and manages its own demand,
  providing per-adapter backpressure.
  """

  use GenStage

  @doc false
  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Pushes a batch of committed events into the producer for delivery
  to all subscribed adapter consumers.
  """
  @spec notify([Emissions.Event.t()]) :: :ok
  def notify(events) when is_list(events) do
    GenStage.cast(__MODULE__, {:events, events})
  end

  ## GenStage callbacks

  @impl GenStage
  def init(_opts) do
    {:producer, [], dispatcher: GenStage.BroadcastDispatcher}
  end

  @impl GenStage
  def handle_cast({:events, events}, _state) do
    {:noreply, events, []}
  end

  @impl GenStage
  def handle_demand(_demand, state) do
    {:noreply, [], state}
  end
end
