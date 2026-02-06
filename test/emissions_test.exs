defmodule EmissionsTest do
  use ExUnit.Case

  setup do
    # Allow pipeline to drain any events from prior tests before resetting
    Process.sleep(50)
    Emissions.Testing.reset()
    :ok
  end

  describe "start/0" do
    test "starts a buffer" do
      assert :ok = Emissions.start()
      Emissions.terminate()
    end

    test "returns error when buffer already started" do
      Emissions.start()
      assert {:error, :already_started} = Emissions.start()
      Emissions.terminate()
    end
  end

  describe "emit/3" do
    test "returns error when buffer not started" do
      assert {:error, :not_started} = Emissions.emit(:test_event, %{id: 1})
    end

    test "buffers events" do
      Emissions.start()
      assert :ok = Emissions.emit(:test_event, %{id: 1})
      assert :ok = Emissions.emit(:other_event, %{id: 2})
      Emissions.terminate()
    end
  end

  describe "commit/0" do
    test "returns error when buffer not started" do
      assert {:error, :not_started} = Emissions.commit()
    end

    test "delivers events to the test adapter" do
      Emissions.start()
      Emissions.emit(:order_created, %{id: 1})
      Emissions.emit(:order_updated, %{id: 1, status: :confirmed})
      Emissions.commit()

      # Give the GenStage pipeline a moment to deliver
      Process.sleep(50)

      events = Emissions.Testing.get_events()
      assert length(events) == 2
      assert Enum.at(events, 0).name == :order_created
      assert Enum.at(events, 1).name == :order_updated
    end

    test "terminates the buffer after commit" do
      Emissions.start()
      Emissions.emit(:test_event, %{})
      Emissions.commit()

      # Buffer should be terminated — emit should fail
      assert {:error, :not_started} = Emissions.emit(:another, %{})
    end
  end

  describe "flush/0" do
    test "returns error when buffer not started" do
      assert {:error, :not_started} = Emissions.flush()
    end

    test "delivers events but keeps buffer open" do
      Emissions.start()
      Emissions.emit(:first, %{n: 1})
      Emissions.flush()

      # Buffer should still be active
      assert :ok = Emissions.emit(:second, %{n: 2})
      Emissions.commit()

      Process.sleep(50)

      events = Emissions.Testing.get_events()
      names = Enum.map(events, & &1.name)
      assert :first in names
      assert :second in names
    end
  end

  describe "terminate/0" do
    test "discards buffered events" do
      Emissions.start()
      Emissions.emit(:should_be_discarded, %{})
      Emissions.terminate()

      Process.sleep(50)

      assert Emissions.Testing.get_events() == []
    end

    test "is a no-op when no buffer started" do
      assert :ok = Emissions.terminate()
    end
  end
end
