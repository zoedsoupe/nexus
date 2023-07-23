defmodule Mix.Tasks.Example do
  @moduledoc """
  This is a Mix Task example using Nexus.
  Basically, you can `use` both `Mix.Task` and `Nexus`
  modules, define your commands as usual with `defcommand/2`
  and implement others callbacks.

  Then you need to call `Nexus.parse/0`, that will inject
  both `parse/1` and `run/1` functions into your module.
  In a `Mix.Task` module, the `run/1` function will supply
  the behaviour, so you don't need to define it yourself.

  If you need to do other computations inside `Mix.Task.run/1`,
  then simply define `run/1` by yourself and call `__MODULE__.run/1`
  when you need it, passing the raw args to it.
  """

  use Mix.Task
  use Nexus

  defcommand :foo, type: :string, required?: false

  @impl Nexus.CLI
  def version, do: "0.1.0"

  @impl Nexus.CLI
  def banner, do: "Hello I'm a test"

  @impl Nexus.CLI
  def handle_input(:foo, _args) do
    IO.puts("Running :foo command...")
  end

  Nexus.parse()
end
