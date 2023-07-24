defmodule Nexus.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/zoedsoupe/nexus"

  def project do
    [
      app: :nexus,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      escript: [main_module: Escript.Example],
      package: package(),
      source_url: @source_url,
      description: description()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
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
      files: ~w(lib/nexus lib/nexus.ex LICENSE README.md mix.*)
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
