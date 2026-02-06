defmodule Emissions.Telemetry do
  @moduledoc """
  Telemetry events emitted by the Emissions library.

  ## Buffer Events

  - `[:emissions, :buffer, :started]` — A new per-request buffer was created.
    - Measurements: `%{count: 1}`
    - Metadata: `%{}`

  - `[:emissions, :buffer, :committed]` — A buffer was committed to the pipeline.
    - Measurements: `%{count: pos_integer()}`
    - Metadata: `%{event_count: pos_integer()}`

  - `[:emissions, :buffer, :terminated]` — A buffer was terminated without committing.
    - Measurements: `%{count: 1}`
    - Metadata: `%{event_count: non_neg_integer()}`

  ## Event Events

  - `[:emissions, :event, :dropped]` — An event was dropped (buffer not started).
    - Measurements: `%{count: 1}`
    - Metadata: `%{event_name: atom(), reason: atom()}`

  ## Adapter Events

  - `[:emissions, :adapter, :success]` — An adapter successfully processed events.
    - Measurements: `%{duration: integer()}`
    - Metadata: `%{adapter: module(), event_count: pos_integer()}`

  - `[:emissions, :adapter, :error]` — An adapter failed to process events.
    - Measurements: `%{duration: integer()}`
    - Metadata: `%{adapter: module(), reason: term(), event_count: pos_integer()}`

  ## Handler Events

  - `[:emissions, :handler, :success]` — A handler successfully processed an event.
    - Measurements: `%{duration: integer()}`
    - Metadata: `%{handler: module(), event: atom()}`

  - `[:emissions, :handler, :error]` — A handler failed to process an event.
    - Measurements: `%{duration: integer()}`
    - Metadata: `%{handler: module(), event: atom(), reason: term()}`

  - `[:emissions, :handler, :ignored]` — A handler returned `:ignored` for an event.
    - Measurements: `%{count: 1}`
    - Metadata: `%{handler: module(), event: atom()}`
  """
end
