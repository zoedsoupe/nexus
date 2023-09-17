defmodule Escript.Example do
  @moduledoc """
  This is an example on how to use `Nexus` with an
  escript application.

  After defined `:escript` entry into your `project/0` function
  on `mix.exs` and set the `main_module` option, you can safely
  define your commands as usual with `defcommand/2`, CLI config
  and handlers.

  Then you need to call `parse/0` macro, which will inject both
  `parse/1` and `run/1` function, which the latter you can delegate
  from the `main/1` escript funciton, as can seen below.
  """

  use Nexus

  defcommand :foo, required: true, type: :string, doc: "Command that receives a string as argument and prints it."

  @impl true
  def version, do: "0.1.0"

  @impl true
  def handle_input(:foo, input) do
    IO.puts(inspect(input))
  end

  Nexus.help()
  Nexus.parse()

  defdelegate main(args), to: __MODULE__, as: :run
end
