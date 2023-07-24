defmodule Nexus.Command do
  @moduledoc """
  Defines a command entry for a CLI module. It also
  implements some basic validations.
  """

  require Logger

  @type t :: %Nexus.Command{module: atom, type: String.t(), required?: boolean}

  @enforce_keys ~w(module type)a
  defstruct module: nil, required?: true, type: nil

  @spec parse!(keyword | map) :: Nexus.Command.t()
  def parse!(attrs) do
    attrs
    |> maybe_convert_to_map()
    |> validate_field(:type)
    |> then(&struct(__MODULE__, &1))
  end

  defp maybe_convert_to_map(kw) when is_list(kw) do
    Map.new(kw)
  end

  defp maybe_convert_to_map(map), do: map

  defp validate_field(%{type: type} = attrs, :type) do
    unless valid_type?(type) do
      raise "Invalid command type"
    end

    attrs
  end

  defp validate_field(_, _), do: raise("Invalid command param")

  defp valid_type?(:string), do: true
  defp valid_type?(_), do: false
end
