defmodule Nexus.MixProject do
  use Mix.Project

  @version "0.4.2"
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
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp elixirc_paths(:dev), do: ["lib"]
  defp elixirc_paths(:test), do: ["lib", "examples/file_management.ex"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:nimble_parsec, "~> 1.4"},
      {:ex_doc, "~> 0.27", only: :dev, runtime: false},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false}
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
      main: "Nexus",
      extras: ["README.md"]
    ]
  end

  defp description do
    """
    An `Elixir` library to write command line apps in a cleaner and elegant way!
    """
  end
end
