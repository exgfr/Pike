defmodule Pike.Mixfile do
  use Mix.Project

  def project do
    [
      app: :pike,
      description: "Guard at the API Gate",
      version: "0.1.0",
      elixir: "~> 1.6",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs()
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger, :plug, :phoenix]]
  end

  defp deps do
    [
      {:plug, "~> 1.14"},
      {:phoenix, "~> 1.7", optional: true},
      {:ex_doc, ">= 0.21.2", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      name: :pike,
      maintainers: ["exgfr"],
      licenses: ["MIT"],
      links: %{github: "https://github.com/exgfr/Pike"},
      files: ~w(lib mix.exs README.md)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md"
      ],
      source_url: "https://github.com/exgfr/Pike"
    ]
  end
end
