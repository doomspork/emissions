defmodule Emissions.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/doomspork/emissions"

  def project do
    [
      app: :emissions,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      description: description(),
      package: package(),
      docs: docs(),
      dialyzer: dialyzer(),
      name: "Emissions",
      source_url: @source_url
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Emissions.Application, []}
    ]
  end

  def cli do
    [preferred_envs: [precommit: :test]]
  end

  defp deps do
    [
      {:gen_stage, "~> 1.2"},
      {:telemetry, "~> 1.0"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp aliases do
    [
      precommit: [
        "compile --warnings-as-errors",
        "deps.unlock --unused",
        "format",
        "credo --strict",
        "dialyzer",
        "test"
      ]
    ]
  end

  defp dialyzer do
    [
      plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
      plt_add_apps: [:mix]
    ]
  end

  defp description do
    "Event emission library with pluggable adapters, GenStage-powered delivery pipeline, per-request buffering, and internal event handlers."
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md",
        "LICENSE",
        "docs/adapters.md",
        "docs/handlers.md",
        "docs/buffering.md",
        "docs/pipeline.md",
        "docs/topic-routing.md",
        "docs/testing.md",
        "docs/telemetry.md"
      ],
      groups_for_extras: [
        Guides: [
          "docs/adapters.md",
          "docs/handlers.md",
          "docs/buffering.md",
          "docs/pipeline.md",
          "docs/topic-routing.md",
          "docs/testing.md",
          "docs/telemetry.md"
        ]
      ],
      source_ref: "v#{@version}"
    ]
  end
end
