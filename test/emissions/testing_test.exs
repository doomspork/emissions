defmodule Emissions.TestingTest do
  use ExUnit.Case
  import Emissions.Testing

  setup do
    Process.sleep(50)
    Emissions.Testing.reset()
    :ok
  end

  describe "event capture" do
    test "captures events from test adapter" do
      Emissions.start()
      Emissions.emit(:test_event, %{value: 42})
      Emissions.commit()

      Process.sleep(50)

      assert Emissions.Testing.emitted?(:test_event)
      refute Emissions.Testing.emitted?(:other_event)
    end

    test "events_named/1 returns matching events" do
      Emissions.start()
      Emissions.emit(:a, %{n: 1})
      Emissions.emit(:b, %{n: 2})
      Emissions.emit(:a, %{n: 3})
      Emissions.commit()

      Process.sleep(50)

      a_events = Emissions.Testing.events_named(:a)
      assert length(a_events) == 2
      assert Enum.all?(a_events, &(&1.name == :a))
    end
  end

  describe "assert_emitted/1" do
    test "passes when event was emitted" do
      Emissions.start()
      Emissions.emit(:found_it, %{})
      Emissions.commit()

      Process.sleep(50)

      assert_emitted(:found_it)
    end
  end

  describe "refute_emitted/1" do
    test "passes when event was not emitted" do
      refute_emitted(:never_happened)
    end
  end

  describe "reset/0" do
    test "clears all events" do
      Emissions.start()
      Emissions.emit(:old_event, %{})
      Emissions.commit()

      Process.sleep(50)
      assert Emissions.Testing.emitted?(:old_event)

      Emissions.Testing.reset()
      refute Emissions.Testing.emitted?(:old_event)
    end
  end
end
