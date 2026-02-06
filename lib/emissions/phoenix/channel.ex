if Code.ensure_loaded?(Phoenix.Channel) do
  defmodule Emissions.Phoenix.Channel do
    @moduledoc """
    Macro for generating a Phoenix Channel that receives Emissions events
    from `Emissions.Phoenix.PubSubAdapter`.

    The generated channel subscribes to the matching PubSub topic on join and
    pushes incoming events to connected WebSocket clients as `"event"` messages.

    ## Usage

        defmodule MyAppWeb.EmissionsChannel do
          use Emissions.Phoenix.Channel
        end

    Then mount it in your socket with a wildcard topic:

        channel "emissions:*", MyAppWeb.EmissionsChannel

    Clients can join at any granularity:

      * `"emissions"` — receives all events
      * `"emissions:orders"` — receives events for the `orders` topic group
      * `"emissions:order_created"` — receives only `order_created` events

    ## Options

      * `:topic_prefix` — must match the prefix configured on the
        `PubSubAdapter`. Defaults to `"emissions"`.

    ## Customization

    The `join/3` callback is `defoverridable`, so you can add authorization:

        defmodule MyAppWeb.EmissionsChannel do
          use Emissions.Phoenix.Channel

          def join(topic, params, socket) do
            if authorized?(params) do
              super(topic, params, socket)
            else
              {:error, %{reason: "unauthorized"}}
            end
          end
        end
    """

    defmacro __using__(opts) do
      quote do
        use Phoenix.Channel

        @emissions_prefix Keyword.get(unquote(opts), :topic_prefix, "emissions")

        @impl Phoenix.Channel
        def join(@emissions_prefix <> _rest = topic, _params, socket) do
          pubsub = socket.endpoint.config(:pubsub_server)
          Phoenix.PubSub.subscribe(pubsub, topic)
          {:ok, socket}
        end

        @impl Phoenix.Channel
        def handle_info({:emissions_event, payload}, socket) do
          push(socket, "event", payload)
          {:noreply, socket}
        end

        defoverridable join: 3
      end
    end
  end
end
