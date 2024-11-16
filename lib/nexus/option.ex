defmodule Nexus.Option do
  import Nexus.Command.Validation

  @type t :: %__MODULE__{
          name: atom,
          short: atom,
          required: boolean,
          doc: String.t() | nil,
          default: term | nil,
          module: atom,
          type: atom,
          value: term
        }

  defstruct name: nil,
            doc: nil,
            type: :null,
            short: nil,
            required: false,
            default: nil,
            module: nil,
            value: nil

  @spec parse!(keyword | map) :: t
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
