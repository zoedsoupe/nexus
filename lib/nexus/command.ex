defmodule Nexus.Command do
  @moduledoc """
  Defines a command entry for a CLI module. It also
  implements some basic validations.
  """

  import Nexus.Command.Validation

  @type t :: %Nexus.Command{
          module: atom,
          type: atom,
          required: boolean,
          name: atom,
          default: term,
          doc: String.t()
        }

  @enforce_keys ~w(module type name)a
  defstruct module: nil, required: true, type: nil, name: nil, default: nil, doc: ""

  @spec parse!(keyword) :: Nexus.Command.t()
  def parse!(attrs) do
    attrs
    |> Map.new()
    |> validate_type()
    |> validate_name()
    |> validate_default()
    |> validate_required(:doc, &is_binary/1)
    |> then(&struct(__MODULE__, &1))
  end
end
