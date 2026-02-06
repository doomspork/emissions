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
    {:producer, :queue.new(), dispatcher: GenStage.BroadcastDispatcher}
  end

  @impl GenStage
  def handle_cast({:events, events}, queue) do
    queue = Enum.reduce(events, queue, fn event, q -> :queue.in(event, q) end)
    {events_to_send, remaining} = take_from_queue(queue, :infinity)
    {:noreply, events_to_send, remaining}
  end

  @impl GenStage
  def handle_demand(_demand, queue) do
    {events, remaining} = take_from_queue(queue, :infinity)
    {:noreply, events, remaining}
  end

  defp take_from_queue(queue, :infinity) do
    events = :queue.to_list(queue)
    {events, :queue.new()}
  end
end
