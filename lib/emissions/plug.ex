if Code.ensure_loaded?(Plug.Conn) do
  defmodule Emissions.Plug do
    @moduledoc """
    Plug that manages the Emissions buffer lifecycle per HTTP request.

    Starts a buffer at the beginning of mutating requests and automatically
    commits or terminates based on the response status code.

    ## Usage

    Add to your Phoenix router or plug pipeline:

        plug Emissions.Plug

    Read-only methods (`GET`, `HEAD`, `OPTIONS`) are skipped by default — no
    buffer is started and no events are collected.

    For all other methods, the plug:

    1. Calls `Emissions.start/0` to open a buffer.
    2. Registers a `before_send` callback that:
       - Calls `Emissions.commit/0` when the response status is in the
         configured commit range (default `200..299`).
       - Calls `Emissions.terminate/0` otherwise, discarding buffered events.

    ## Options

      * `:skip_methods` — list of HTTP methods (uppercase strings) to skip.
        Defaults to `["GET", "HEAD", "OPTIONS"]`.

      * `:commit_statuses` — range or list of HTTP status codes that trigger
        `Emissions.commit/0`. All other statuses trigger `Emissions.terminate/0`.
        Defaults to `200..299`.
    """

    @behaviour Plug

    @default_skip_methods ["GET", "HEAD", "OPTIONS"]
    @default_commit_statuses 200..299

    @impl Plug
    def init(opts) do
      %{
        skip_methods: Keyword.get(opts, :skip_methods, @default_skip_methods),
        commit_statuses: Keyword.get(opts, :commit_statuses, @default_commit_statuses)
      }
    end

    @impl Plug
    def call(conn, opts) do
      if conn.method in opts.skip_methods do
        conn
      else
        case Emissions.start() do
          :ok -> Plug.Conn.register_before_send(conn, &before_send(&1, opts))
          {:error, :already_started} -> conn
        end
      end
    end

    defp before_send(conn, opts) do
      if conn.status in opts.commit_statuses do
        Emissions.commit()
      else
        Emissions.terminate()
      end

      conn
    end
  end
end
