# CLAUDE.md

## Project Overview

Emissions is a standalone Elixir library for event emission with pluggable adapters, per-request buffering, and a GenStage-powered delivery pipeline. It targets publication on Hex.

## Key Commands

```bash
# Run ALL checks before committing — always use this
mix precommit

# Individual checks (precommit runs all of these)
mix compile --warnings-as-errors
mix deps.unlock --unused
mix format
mix credo --strict
mix dialyzer
mix test
```

**Always run `mix precommit` before committing changes.** It runs compile (warnings-as-errors), deps cleanup, formatter, credo (strict), dialyzer, and the full test suite.

## Architecture

- **Public API**: `Emissions` module — `start/0`, `emit/3`, `commit/0`, `flush/0`, `terminate/0`
- **Buffer**: Per-request `GenServer` under `BufferPool` (`DynamicSupervisor`), tracked via process dictionary
- **Pipeline**: `GenStage` producer with `BroadcastDispatcher` fans out to adapter consumers
- **Adapters**: Implement `Emissions.Adapter` behaviour (`init/1`, `handle_events/2`, optional `interested?/2`)
- **Handlers**: Implement `Emissions.Handler` behaviour (`events/0`, `handle_event/3`), dispatched via `HandlerDispatcher`
- **TopicRouter**: Optional compile-time event-to-topic mapping macro

## Supervision Tree

```
Emissions.Supervisor (rest_for_one)
├── BufferPool (DynamicSupervisor)
├── Pipeline.Producer (GenStage)
├── Pipeline.AdapterSupervisor (one_for_one)
│   ├── AdapterConsumer per adapter
│   └── AdapterConsumer for HandlerDispatcher
└── TaskSupervisor (for handler tasks)
```

## Testing

- Test config uses `Emissions.Testing.TestAdapter` — see `config/test.exs`
- Tests use `Process.sleep(50)` before `reset()` to let the async GenStage pipeline drain
- The `precommit` alias sets `MIX_ENV=test` via `cli/0` preferred_envs

## Conventions

- **Commits**: Use [conventional commits](https://www.conventionalcommits.org/) (e.g., `feat:`, `fix:`, `docs:`, `test:`, `chore:`)
- **No co-authored-by**: Do not include co-authored-by lines in commits
- **Docs**: Feature guides live in `docs/` and are included in HexDocs via mix.exs extras
- **Mermaid diagrams**: Use mermaid diagrams in docs to illustrate lifecycle and flow concepts
- **Credo**: Runs in strict mode — watch for nesting depth (max 2) and prefer `!= []` over `length() > 0`
- **Dialyzer**: PLT cached in `priv/plts/` (gitignored)
