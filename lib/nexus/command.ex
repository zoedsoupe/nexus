defmodule Nexus.Command do
  @moduledoc """
  Defines a command entry for a CLI module. It also
  implements some basic validations.
  """

  import Nexus.Command.Validation

  @type t :: %Nexus.Command{module: atom, type: String.t(), required?: boolean, name: atom}

  @enforce_keys ~w(module type name)a
  defstruct module: nil, required?: true, type: nil, name: nil

  @spec parse!(keyword) :: Nexus.Command.t()
  def parse!(attrs) do
    attrs
    |> Map.new()
    |> validate_type()
    |> validate_name()
    |> then(&struct(__MODULE__, &1))
  end
end
