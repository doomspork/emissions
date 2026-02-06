defmodule Emissions.AdapterTest do
  use ExUnit.Case

  defmodule LogAdapter do
    @behaviour Emissions.Adapter

    @impl true
    def init(opts) do
      {:ok, %{level: Keyword.get(opts, :level, :info), events: []}}
    end

    @impl true
    def handle_events(events, state) do
      {:ok, %{state | events: state.events ++ events}}
    end
  end

  defmodule FilteredAdapter do
    @behaviour Emissions.Adapter

    @impl true
    def init(_opts), do: {:ok, %{}}

    @impl true
    def interested?(event, _state) do
      event.name in [:allowed_event]
    end

    @impl true
    def handle_events(events, state) do
      send(self(), {:filtered_events, events})
      {:ok, state}
    end
  end

  defmodule FailingAdapter do
    @behaviour Emissions.Adapter

    @impl true
    def init(_opts), do: {:ok, %{}}

    @impl true
    def handle_events(_events, state) do
      {:error, :something_went_wrong, state}
    end
  end

  describe "adapter behaviour" do
    test "LogAdapter initializes with options" do
      assert {:ok, state} = LogAdapter.init(level: :debug)
      assert state.level == :debug
    end

    test "LogAdapter handles events" do
      {:ok, state} = LogAdapter.init([])
      event = Emissions.Event.new(:test, %{})
      assert {:ok, new_state} = LogAdapter.handle_events([event], state)
      assert length(new_state.events) == 1
    end

    test "FailingAdapter returns error tuple" do
      {:ok, state} = FailingAdapter.init([])
      event = Emissions.Event.new(:test, %{})

      assert {:error, :something_went_wrong, _state} =
               FailingAdapter.handle_events([event], state)
    end

    test "FilteredAdapter implements interested?/2" do
      {:ok, state} = FilteredAdapter.init([])
      allowed = Emissions.Event.new(:allowed_event, %{})
      blocked = Emissions.Event.new(:blocked_event, %{})

      assert FilteredAdapter.interested?(allowed, state)
      refute FilteredAdapter.interested?(blocked, state)
    end
  end
end
