defmodule Emissions.Testing do
  @moduledoc """
  Test helpers for applications using Emissions.

  ## Setup

  Add to your `test/test_helper.exs`:

      Emissions.Testing.setup()

  Or in individual tests:

      defmodule MyApp.SomeTest do
        use ExUnit.Case

        setup do
          Emissions.Testing.reset()
          :ok
        end

        test "emits order created event" do
          do_something_that_emits_events()
          assert Emissions.Testing.emitted?(:order_created)
        end
      end

  ## Configuration

  In your `config/test.exs`, configure the test adapter:

      config :emissions,
        adapters: [{Emissions.Testing.TestAdapter, []}],
        handlers: []
  """

  @agent_name Emissions.Testing.EventStore

  @doc """
  Starts the test event store. Call this in `test_helper.exs`.
  """
  def setup do
    case Agent.start_link(fn -> [] end, name: @agent_name) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end
  end

  @doc """
  Clears all captured events. Call this in a `setup` block.
  """
  def reset do
    setup()
    Agent.update(@agent_name, fn _ -> [] end)
  end

  @doc """
  Returns all events captured by the test adapter.
  """
  @spec get_events() :: [Emissions.Event.t()]
  def get_events do
    Agent.get(@agent_name, & &1)
  end

  @doc """
  Returns `true` if an event with the given name was emitted.
  """
  @spec emitted?(atom()) :: boolean()
  def emitted?(event_name) do
    get_events()
    |> Enum.any?(&(&1.name == event_name))
  end

  @doc """
  Returns all events matching the given name.
  """
  @spec events_named(atom()) :: [Emissions.Event.t()]
  def events_named(event_name) do
    get_events()
    |> Enum.filter(&(&1.name == event_name))
  end

  @doc """
  Asserts that an event with the given name was emitted.

  Optionally provide a function to assert on the event payload.

  ## Examples

      Emissions.Testing.assert_emitted(:order_created)
      Emissions.Testing.assert_emitted(:order_created, fn event ->
        assert event.payload.id == 42
      end)
  """
  defmacro assert_emitted(event_name) do
    quote do
      events = Emissions.Testing.events_named(unquote(event_name))

      assert length(events) > 0,
             "Expected event #{inspect(unquote(event_name))} to be emitted, but it was not"

      events
    end
  end

  defmacro assert_emitted(event_name, fun) do
    quote do
      events = Emissions.Testing.events_named(unquote(event_name))

      assert length(events) > 0,
             "Expected event #{inspect(unquote(event_name))} to be emitted, but it was not"

      for event <- events, do: unquote(fun).(event)
      events
    end
  end

  @doc """
  Asserts that no event with the given name was emitted.
  """
  defmacro refute_emitted(event_name) do
    quote do
      events = Emissions.Testing.events_named(unquote(event_name))

      assert events == [],
             "Expected event #{inspect(unquote(event_name))} to not be emitted, but got #{length(events)}"
    end
  end

  @doc false
  def record_events(events) do
    Agent.update(@agent_name, fn existing -> existing ++ events end)
  end
end
