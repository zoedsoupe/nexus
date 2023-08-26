defmodule Nexus.Command.Validation do
  @moduledoc """
  Defines validations for a `Nexus.Command` struct
  """

  alias Nexus.Command.MissingType
  alias Nexus.Command.NotSupportedType

  @supported_types Application.compile_env!(:nexus, :supported_types)

  @spec validate_type(map) :: map
  def validate_type(%{type: type} = attrs) do
    if type in @supported_types do
      attrs
    else
      raise NotSupportedType, type
    end
  end

  def validate_type(_), do: raise(MissingType)

  @spec validate_name(map) :: map
  def validate_name(%{name: name} = attrs) do
    if is_atom(name) do
      attrs
    else
      raise ArgumentError, "Command name must be an atom"
    end
  end
end
