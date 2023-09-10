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

  @spec validate_name(map) :: map
  def validate_default(%{required: false, type: type, name: name} = attrs) do
    default = Map.get(attrs, :default)

    cond do
      !default ->
        raise ArgumentError, "Non required commands must have a default value"

      !is_same_type(default, type) ->
        raise ArgumentError, "Default value for #{name} must be of type #{type}"

      true ->
        attrs
    end
  end

  def validate_default(attrs), do: attrs

  defp is_same_type(value, :string), do: is_binary(value)
  defp is_same_type(value, :integer), do: is_integer(value)
  defp is_same_type(value, :float), do: is_float(value)
  defp is_same_type(value, :atom), do: is_atom(value)
  defp is_same_type(_, :null), do: true
end
