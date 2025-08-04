defmodule Nexus.MixProject do
  use Mix.Project

  @version "0.6.0"
  @source_url "https://github.com/zoedsoupe/nexus"

  def project do
    [
      app: :nexus_cli,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      escript: [main_module: Escript.Example],
      package: package(),
      source_url: @source_url,
      description: description(),
      elixirc_paths: elixirc_paths(Mix.env()),
      dialyzer: [
        plt_local_path: "priv/plts",
        ignore_warnings: ".dialyzerignore.exs",
        plt_add_apps: [:mix, :ex_unit]
      ]
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp elixirc_paths(:dev), do: ["lib", "examples/"]
  defp elixirc_paths(:test), do: ["lib", "examples/", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:styler, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.3", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    %{
      name: "nexus_cli",
      licenses: ["WTFPL"],
      contributors: ["zoedsoupe"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib/nexus lib/nexus.ex LICENSE README.md mix.* examples)
    }
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"]
    ]
  end

  defp description do
    """
    An `Elixir` library to write command line apps in a cleaner and elegant way!
    """
  end
end
