defmodule Emissions.TopicRouterTest do
  use ExUnit.Case

  defmodule TestRouter do
    use Emissions.TopicRouter,
      mappings: %{
        orders: [:order_created, :order_updated, :order_shipped],
        inventory: [:item_received, :item_adjusted],
        users: [:user_created]
      }
  end

  describe "topic_for_event/1" do
    test "returns the topic for a mapped event" do
      assert TestRouter.topic_for_event(:order_created) == :orders
      assert TestRouter.topic_for_event(:item_received) == :inventory
      assert TestRouter.topic_for_event(:user_created) == :users
    end

    test "returns nil for unmapped events" do
      assert TestRouter.topic_for_event(:unknown_event) == nil
    end
  end

  describe "topics/0" do
    test "returns all topic names" do
      topics = TestRouter.topics()
      assert :orders in topics
      assert :inventory in topics
      assert :users in topics
      assert length(topics) == 3
    end
  end

  describe "events_for_topic/1" do
    test "returns events for a topic" do
      events = TestRouter.events_for_topic(:orders)
      assert :order_created in events
      assert :order_updated in events
      assert :order_shipped in events
      assert length(events) == 3
    end

    test "returns empty list for unknown topic" do
      assert TestRouter.events_for_topic(:nonexistent) == []
    end
  end
end
