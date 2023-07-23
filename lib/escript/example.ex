defmodule Escript.Example do
  use Nexus

  defcommand :foo, required?: true, type: :string

  Nexus.parse()

  defdelegate main(args), to: __MODULE__, as: :run
end
