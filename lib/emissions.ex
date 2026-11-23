defmodule Emissions do
  @moduledoc """
  Event emission library with pluggable adapters, per-request buffering,
  and internal event handlers. Designed based on production event systems
  built at Stord and Hiive.

  ## Usage

  Events are collected in a per-request buffer and delivered to all configured
  adapters when committed:

      Emissions.start()
      Emissions.emit(:order_created, %{id: 1, total: 99.99})
      Emissions.emit(:order_confirmed, %{id: 1})
      Emissions.commit()

  `commit/0` hands events off to a GenStage pipeline that fans them out to
  every configured adapter (Kafka, WebSocket, webhooks, etc.) at the pace of the slowest subscribed consumer.

  ## Buffer Lifecycle

      start() → emit() → emit() → ... → commit()
                                       → flush()     (commit without terminating)
                                       → terminate() (discard without processing)
  """

  alias Emissions.Buffer

  @doc """
  Starts a new per-request event buffer.

  The buffer is linked to the calling process and stored in the process
  dictionary. It will be automatically cleaned up if the calling process exits.
  """
  @spec start(keyword()) :: :ok | {:error, :already_started}
  def start(opts \\ []) do
    Buffer.start(opts)
  end

  @doc """
  Emits an event into the current buffer.

  Events are collected asynchronously and not delivered until `commit/0`
  or `flush/0` is called.
  """
  @spec emit(atom(), term(), map()) :: :ok | {:error, :not_started}
  def emit(name, payload, metadata \\ %{}) do
    Buffer.emit(name, payload, metadata)
  end

  @doc """
  Commits all buffered events to the delivery pipeline and terminates the buffer.

  Events are handed off to the GenStage producer for fan-out to all configured
  adapters. This call returns immediately — delivery happens asynchronously
  with best-effort delivery. The return value acknowledges the local handoff.
  Overflow, adapter failure, or process restarts can lose events.
  """
  @spec commit() :: :ok | {:error, :not_started}
  def commit do
    Buffer.commit()
  end

  @doc """
  Commits all buffered events without terminating the buffer.

  Useful when you want to deliver events collected so far but continue
  collecting more in the same buffer.
  """
  @spec flush() :: :ok | {:error, :not_started}
  def flush do
    Buffer.flush()
  end

  @doc """
  Terminates the buffer without delivering any events.

  Use this for cleanup when an operation fails and events should be discarded.
  """
  @spec terminate() :: :ok
  def terminate do
    Buffer.terminate()
  end
end
