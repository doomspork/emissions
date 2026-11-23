defmodule Emissions.ProducerTest do
  use ExUnit.Case
  alias Emissions.Pipeline.Producer

  defmodule Consumer do
    use GenStage
    def init(owner), do: {:consumer, owner}

    def handle_events(events, _, owner) do
      send(owner, {:received, self(), events})
      {:noreply, [], owner}
    end
  end

  test "a stalled subscriber limits broadcast and overflow is measurable" do
    {:ok, producer} = GenStage.start_link(Producer, buffer_size: 2)
    {:ok, fast} = GenStage.start_link(Consumer, self())
    {:ok, slow} = GenStage.start_link(Consumer, self())
    for pid <- [fast, slow], do: GenStage.sync_subscribe(pid, to: producer, max_demand: 1)
    GenStage.cast(producer, {:events, [:ready]})
    assert_receive {:received, ^slow, [:ready]}
    assert_receive {:received, ^fast, [:ready]}
    :sys.suspend(slow)
    event = [:emissions, :pipeline, :discarded]
    id = make_ref()
    :telemetry.attach(id, event, &__MODULE__.report/4, self())
    on_exit(fn -> :telemetry.detach(id) end)
    GenStage.cast(producer, {:events, Enum.to_list(1..10)})
    assert_receive {:discarded, count}
    assert count in 7..8
    :sys.resume(slow)
    assert_receive {:received, ^fast, [10]}
    assert_receive {:received, ^slow, [10]}
  end

  def report(_, %{count: count}, _, owner), do: send(owner, {:discarded, count})
end
