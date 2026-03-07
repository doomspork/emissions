# Contributing to Emissions

Thank you for your interest in contributing to Emissions! This guide will help you get started.

## Getting Started

1. Fork the repository
2. Clone your fork and create a feature branch:

   ```bash
   git checkout -b my-new-feature
   ```

3. Install dependencies:

   ```bash
   mix deps.get
   ```

## Development Workflow

Before committing, run the precommit checks. This single command runs the compiler (warnings-as-errors), formatter, Credo (strict), Dialyzer, and the full test suite:

```bash
mix precommit
```

You can also run individual checks if needed:

```bash
mix test            # Run tests
mix format          # Format code
mix credo --strict  # Lint
mix dialyzer        # Type checking
```

## Commit Messages

This project uses [conventional commits](https://www.conventionalcommits.org/). Prefix your commit messages accordingly:

- `feat:` — New feature
- `fix:` — Bug fix
- `docs:` — Documentation changes
- `test:` — Adding or updating tests
- `chore:` — Maintenance tasks

## Submitting Changes

1. Push your branch to your fork
2. Open a Pull Request against `main`
3. Ensure all CI checks pass

## Generating Documentation

```bash
mix docs
```

Documentation guides live in the `docs/` directory and are included in HexDocs.
