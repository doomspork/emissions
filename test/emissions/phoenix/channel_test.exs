defmodule Emissions.Phoenix.ChannelTest.TestChannel do
  use Emissions.Phoenix.Channel, access: :public
end

defmodule Emissions.Phoenix.ChannelTest.AuthChannel do
  use Emissions.Phoenix.Channel, access: :public

  def join("emissions:" <> _rest = topic, %{"token" => "valid"}, socket) do
    super(topic, %{}, socket)
  end

  def join(_topic, _params, _socket) do
    {:error, %{reason: "unauthorized"}}
  end
end

defmodule Emissions.Phoenix.ChannelTest.TestEndpoint do
  use Phoenix.Endpoint, otp_app: :emissions_channel_test

  @pubsub_name :"channel_test_pubsub_#{System.unique_integer([:positive])}"

  def pubsub_name, do: @pubsub_name
end

defmodule Emissions.Phoenix.ChannelTest do
  use ExUnit.Case, async: true

  import Phoenix.ChannelTest

  alias Emissions.Phoenix.Channel
  alias Emissions.Phoenix.ChannelTest.{AuthChannel, TestChannel, TestEndpoint}

  @endpoint TestEndpoint

  setup_all do
    pubsub = TestEndpoint.pubsub_name()
    start_link_supervised!({Phoenix.PubSub, name: pubsub})

    Application.put_env(:emissions_channel_test, TestEndpoint,
      pubsub_server: pubsub,
      secret_key_base: String.duplicate("a", 64),
      server: false
    )

    start_link_supervised!(TestEndpoint)
    :ok
  end

  describe "join/3" do
    test "joins the catch-all topic" do
      {:ok, _, _socket} =
        socket(TestEndpoint, nil, %{})
        |> subscribe_and_join(TestChannel, "emissions")

      Phoenix.PubSub.broadcast(
        TestEndpoint.pubsub_name(),
        "emissions",
        {:emissions_event, %{name: :test}}
      )

      assert_push("event", %{name: :test})
    end

    test "joins an event-name topic" do
      {:ok, _, _socket} =
        socket(TestEndpoint, nil, %{})
        |> subscribe_and_join(TestChannel, "emissions:order_created")

      Phoenix.PubSub.broadcast(
        TestEndpoint.pubsub_name(),
        "emissions:order_created",
        {:emissions_event, %{name: :order_created, payload: %{id: 1}}}
      )

      assert_push("event", %{name: :order_created, payload: %{id: 1}})
    end

    test "joins a topic-group topic" do
      {:ok, _, _socket} =
        socket(TestEndpoint, nil, %{})
        |> subscribe_and_join(TestChannel, "emissions:orders")

      Phoenix.PubSub.broadcast(
        TestEndpoint.pubsub_name(),
        "emissions:orders",
        {:emissions_event, %{name: :order_created}}
      )

      assert_push("event", %{name: :order_created})
    end
  end

  describe "topic scoping" do
    test "requires a trusted matching tenant segment" do
      policy = {:tenant, :org}
      check = &Channel.allowed?(&1, "emissions", &2, &3)
      assert check.(policy, "emissions:a:orders", %{org: "a"})
      refute check.(policy, "emissions:ab:orders", %{org: "a"})
      refute check.(policy, "emissions:a", %{})
      refute check.(:deny, "emissions", %{})
    end

    test "only receives events for the subscribed topic" do
      {:ok, _, _socket} =
        socket(TestEndpoint, nil, %{})
        |> subscribe_and_join(TestChannel, "emissions:order_created")

      Phoenix.PubSub.broadcast(
        TestEndpoint.pubsub_name(),
        "emissions:user_created",
        {:emissions_event, %{name: :user_created}}
      )

      refute_push("event", _)
    end
  end

  describe "overridable join/3" do
    test "accepts authorized connections" do
      {:ok, _, _socket} =
        socket(TestEndpoint, nil, %{})
        |> subscribe_and_join(AuthChannel, "emissions:orders", %{"token" => "valid"})

      Phoenix.PubSub.broadcast(
        TestEndpoint.pubsub_name(),
        "emissions:orders",
        {:emissions_event, %{name: :order_created}}
      )

      assert_push("event", %{name: :order_created})
    end

    test "rejects unauthorized connections" do
      assert {:error, %{reason: "unauthorized"}} =
               socket(TestEndpoint, nil, %{})
               |> subscribe_and_join(AuthChannel, "emissions:orders", %{"token" => "invalid"})
    end
  end
end
