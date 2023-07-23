defmodule Mix.Tasks.Example do
  @moduledoc false

  use Mix.Task
  use Nexus

  defcommand :foo, type: :string, required?: false

  @impl Nexus.CLI
  def version, do: "v0.1.0"

  @impl Nexus.CLI
  def banner, do: "Hello I'm a test"

  @impl Nexus.CLI
  def handle_input(:foo, args) do
    IO.puts("Executando #{:foo} com args #{args}...")
  end

  Nexus.parse()
end
