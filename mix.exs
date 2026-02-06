defmodule Emissions.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/stord/emissions"

  def project do
    [
      app: :emissions,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
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

  defp deps do
    [
      {:gen_stage, "~> 1.2"},
      {:telemetry, "~> 1.0"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
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
