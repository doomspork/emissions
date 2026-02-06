defmodule Emissions.Buffer do
  @moduledoc """
  Per-request event buffer backed by a GenServer.

  Buffers are started under `Emissions.BufferPool` (a DynamicSupervisor),
  linked to the calling process, and tracked via the process dictionary.
  This ensures automatic cleanup if the caller exits unexpectedly.

  Events are collected asynchronously via `GenServer.cast` and delivered
  to the pipeline on commit via `GenServer.call`.
  """

  use GenServer, restart: :temporary

  require Logger

  alias Emissions.Event
  alias Emissions.Pipeline.Producer

  @process_key :emissions_buffer_pid

  ## Public API (called from the request process)

  @doc false
  @spec start(keyword()) :: :ok | {:error, :already_started}
  def start(_opts \\ []) do
    case Process.get(@process_key) do
      nil ->
        {:ok, pid} =
          DynamicSupervisor.start_child(Emissions.BufferPool, {__MODULE__, []})

        Process.link(pid)
        Process.put(@process_key, pid)

        :telemetry.execute([:emissions, :buffer, :started], %{count: 1})
        :ok

      _pid ->
        {:error, :already_started}
    end
  end

  @doc false
  @spec emit(atom(), term(), map()) :: :ok | {:error, :not_started}
  def emit(name, payload, metadata) do
    case Process.get(@process_key) do
      pid when is_pid(pid) ->
        event = Event.new(name, payload, metadata)
        GenServer.cast(pid, {:event, event})
        :ok

      nil ->
        :telemetry.execute([:emissions, :event, :dropped], %{count: 1}, %{
          event_name: name,
          reason: :not_started
        })

        {:error, :not_started}
    end
  end

  @doc false
  @spec commit() :: :ok | {:error, :not_started}
  def commit do
    with pid when is_pid(pid) <- Process.delete(@process_key),
         true <- Process.unlink(pid) do
      GenServer.call(pid, :commit)
    else
      nil -> {:error, :not_started}
    end
  end

  @doc false
  @spec flush() :: :ok | {:error, :not_started}
  def flush do
    case Process.get(@process_key) do
      pid when is_pid(pid) ->
        GenServer.call(pid, :flush)

      nil ->
        {:error, :not_started}
    end
  end

  @doc false
  @spec terminate() :: :ok
  def terminate do
    case Process.delete(@process_key) do
      pid when is_pid(pid) ->
        Process.unlink(pid)
        GenServer.stop(pid, :normal)
        :ok

      nil ->
        :ok
    end
  end

  ## GenServer callbacks

  @doc false
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl GenServer
  def init(_opts) do
    Process.flag(:trap_exit, true)
    {:ok, []}
  end

  @impl GenServer
  def handle_cast({:event, event}, events) do
    {:noreply, [event | events]}
  end

  @impl GenServer
  def handle_call(:commit, _from, events) do
    deliver_events(events)
    {:stop, :normal, :ok, []}
  end

  @impl GenServer
  def handle_call(:flush, _from, events) do
    deliver_events(events)
    {:reply, :ok, []}
  end

  @impl GenServer
  def handle_info({:EXIT, _pid, _reason}, events) do
    {:stop, :normal, events}
  end

  defp deliver_events([]), do: :ok

  defp deliver_events(events) do
    committed = Enum.reverse(events)
    count = length(committed)

    :telemetry.execute([:emissions, :buffer, :committed], %{count: count}, %{
      event_count: count
    })

    Producer.notify(committed)
  end
end
