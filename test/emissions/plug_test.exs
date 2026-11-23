defmodule Emissions.PlugTest do
  use ExUnit.Case, async: false

  import Plug.Test

  setup do
    Process.sleep(50)
    Emissions.Testing.reset()
    :ok
  end

  test "leaves an existing buffer under its owner's control" do
    for status <- [200, 500] do
      :ok = Emissions.start()

      conn(:post, "/")
      |> Emissions.Plug.call(Emissions.Plug.init([]))
      |> Plug.Conn.send_resp(status, "")

      assert :ok = Emissions.emit(:still_owned, %{})
      :ok = Emissions.terminate()
    end
  end

  describe "init/1" do
    test "returns defaults when no options given" do
      opts = Emissions.Plug.init([])

      assert opts.skip_methods == ["GET", "HEAD", "OPTIONS"]
      assert opts.commit_statuses == 200..299
    end

    test "accepts custom skip_methods" do
      opts = Emissions.Plug.init(skip_methods: ["GET"])

      assert opts.skip_methods == ["GET"]
    end

    test "accepts custom commit_statuses" do
      opts = Emissions.Plug.init(commit_statuses: [200, 201])

      assert opts.commit_statuses == [200, 201]
    end
  end

  describe "call/2 with skipped methods" do
    test "skips GET requests" do
      opts = Emissions.Plug.init([])
      conn = conn(:get, "/orders")

      result = Emissions.Plug.call(conn, opts)

      assert result == conn
      assert {:error, :not_started} = Emissions.emit(:test, %{})
    end

    test "skips HEAD requests" do
      opts = Emissions.Plug.init([])
      conn = conn(:head, "/orders")

      result = Emissions.Plug.call(conn, opts)

      assert result == conn
    end

    test "skips OPTIONS requests" do
      opts = Emissions.Plug.init([])
      conn = conn(:options, "/orders")

      result = Emissions.Plug.call(conn, opts)

      assert result == conn
    end
  end

  describe "call/2 commits on success status" do
    test "commits buffered events on 200 response" do
      opts = Emissions.Plug.init([])
      conn = conn(:post, "/orders")

      conn = Emissions.Plug.call(conn, opts)
      Emissions.emit(:order_created, %{id: 1})

      conn
      |> Plug.Conn.resp(200, "ok")
      |> Plug.Conn.send_resp()

      Process.sleep(50)
      assert Emissions.Testing.emitted?(:order_created)
    end

    test "commits buffered events on 201 response" do
      opts = Emissions.Plug.init([])
      conn = conn(:post, "/orders")

      conn = Emissions.Plug.call(conn, opts)
      Emissions.emit(:order_created, %{id: 1})

      conn
      |> Plug.Conn.resp(201, "created")
      |> Plug.Conn.send_resp()

      Process.sleep(50)
      assert Emissions.Testing.emitted?(:order_created)
    end
  end

  describe "call/2 terminates on error status" do
    test "discards events on 422 response" do
      opts = Emissions.Plug.init([])
      conn = conn(:post, "/orders")

      conn = Emissions.Plug.call(conn, opts)
      Emissions.emit(:order_created, %{id: 1})

      conn
      |> Plug.Conn.resp(422, "unprocessable")
      |> Plug.Conn.send_resp()

      Process.sleep(50)
      refute Emissions.Testing.emitted?(:order_created)
    end

    test "discards events on 500 response" do
      opts = Emissions.Plug.init([])
      conn = conn(:post, "/orders")

      conn = Emissions.Plug.call(conn, opts)
      Emissions.emit(:order_created, %{id: 1})

      conn
      |> Plug.Conn.resp(500, "error")
      |> Plug.Conn.send_resp()

      Process.sleep(50)
      refute Emissions.Testing.emitted?(:order_created)
    end
  end

  describe "call/2 with custom options" do
    test "respects custom skip_methods" do
      opts = Emissions.Plug.init(skip_methods: ["GET", "PATCH"])
      conn = conn(:patch, "/orders/1")

      result = Emissions.Plug.call(conn, opts)

      assert result == conn
      assert {:error, :not_started} = Emissions.emit(:test, %{})
    end

    test "processes methods not in custom skip list" do
      opts = Emissions.Plug.init(skip_methods: ["GET"])
      conn = conn(:head, "/orders")

      _conn = Emissions.Plug.call(conn, opts)
      assert :ok = Emissions.emit(:test, %{})

      Emissions.terminate()
    end

    test "respects custom commit_statuses" do
      opts = Emissions.Plug.init(commit_statuses: [200])
      conn = conn(:post, "/orders")

      conn = Emissions.Plug.call(conn, opts)
      Emissions.emit(:order_created, %{id: 1})

      conn
      |> Plug.Conn.resp(201, "created")
      |> Plug.Conn.send_resp()

      Process.sleep(50)
      refute Emissions.Testing.emitted?(:order_created)
    end
  end

  describe "call/2 with different HTTP methods" do
    test "starts buffer for PUT requests" do
      opts = Emissions.Plug.init([])
      conn = conn(:put, "/orders/1")

      conn = Emissions.Plug.call(conn, opts)
      Emissions.emit(:order_updated, %{id: 1})

      conn
      |> Plug.Conn.resp(200, "ok")
      |> Plug.Conn.send_resp()

      Process.sleep(50)
      assert Emissions.Testing.emitted?(:order_updated)
    end

    test "starts buffer for DELETE requests" do
      opts = Emissions.Plug.init([])
      conn = conn(:delete, "/orders/1")

      conn = Emissions.Plug.call(conn, opts)
      Emissions.emit(:order_deleted, %{id: 1})

      conn
      |> Plug.Conn.resp(200, "ok")
      |> Plug.Conn.send_resp()

      Process.sleep(50)
      assert Emissions.Testing.emitted?(:order_deleted)
    end

    test "starts buffer for PATCH requests" do
      opts = Emissions.Plug.init([])
      conn = conn(:patch, "/orders/1")

      conn = Emissions.Plug.call(conn, opts)
      Emissions.emit(:order_patched, %{id: 1})

      conn
      |> Plug.Conn.resp(200, "ok")
      |> Plug.Conn.send_resp()

      Process.sleep(50)
      assert Emissions.Testing.emitted?(:order_patched)
    end
  end
end
