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

    When the adapter is configured with `:scope`, topics include a tenant segment:

      * `"emissions:acme"` — all events for tenant "acme"
      * `"emissions:acme:orders"` — order events for tenant "acme"
      * `"emissions:acme:order_created"` — specific event for tenant "acme"

    ## Options

      * `:topic_prefix` — must match the prefix configured on the
        `PubSubAdapter`. Defaults to `"emissions"`.

    Set `:access` to `{:tenant, :tenant_id}` to authorize the first topic
    segment against an authenticated socket assign. The default denies joins.
    Use `:public` only for a dedicated public feed.
    """

    @doc false
    def allowed?(:public, prefix, topic, _assigns),
      do: topic == prefix or String.starts_with?(topic, prefix <> ":")

    def allowed?({:tenant, key}, prefix, topic, assigns) do
      with {:ok, id} <- Map.fetch(assigns, key),
           true <- is_binary(id) or is_integer(id),
           tenant = to_string(id),
           true <- tenant != "" and not String.contains?(tenant, ":") do
        allowed?(:public, prefix <> ":" <> tenant, topic, assigns)
      else
        _ -> false
      end
    end

    def allowed?(_policy, _prefix, _topic, _assigns), do: false

    defmacro __using__(opts) do
      quote do
        use Phoenix.Channel

        @emissions_prefix Keyword.get(unquote(opts), :topic_prefix, "emissions")

        @emissions_access Keyword.get(unquote(opts), :access, :deny)

        @impl Phoenix.Channel
        def join(topic, _params, socket) do
          if Emissions.Phoenix.Channel.allowed?(
               @emissions_access,
               @emissions_prefix,
               topic,
               socket.assigns
             ) do
            {:ok, socket}
          else
            {:error, %{reason: "unauthorized"}}
          end
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
