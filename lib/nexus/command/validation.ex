defmodule Nexus.Command.Validation do
  @moduledoc """
  Defines validations for a `Nexus.Command` struct
  """

  alias Nexus.Command.MissingType
  alias Nexus.Command.NotSupportedType

  @spec validate_required(map, atom, (any -> boolean)) :: map
  def validate_required(%{name: name} = attrs, field, valid_type?) do
    value = Map.get(attrs, field)

    if value && valid_type?.(value) do
      attrs
    else
      raise ArgumentError, "Missing or invalid value for #{field} field in command #{name}"
    end
  end

  @supported_types Application.compile_env!(:nexus, :supported_types)

  @spec validate_type(map) :: map
  def validate_type(%{type: {:enum, values}} = attrs) do
    string = Enum.all?(values, &is_same_type(&1, :string))
    atom = Enum.all?(values, &is_same_type(&1, :atom))

    if string or atom do
      attrs
    else
      raise ArgumentError, "Enum values must be all strings or all atoms"
    end
  end

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

  @spec validate_default(map) :: map
  def validate_default(%{required: false, type: {:enum, values}, name: name} = attrs) do
    string = Enum.all?(values, &is_same_type(&1, :string))
    atom = Enum.all?(values, &is_same_type(&1, :atom))
    type = (string && "string") || (atom && "atom") || "enum"
    default = Map.get(attrs, :default)
    valid_default? = is_valid_default_type?(default, string, atom)

    cond do
      !default -> raise ArgumentError, "Non required commands must have a default value"
      !valid_default? -> raise ArgumentError, "Default value for #{name} must be of type #{type}"
      true -> attrs
    end
  end

  def validate_default(%{required: false, type: type, name: name} = attrs) do
    default = Map.get(attrs, :default)

    cond do
      !default and type != :null ->
        raise ArgumentError, "Non required commands must have a default value"

      !is_same_type(default, type) ->
        raise ArgumentError, "Default value for #{name} must be of type #{type}"

      true ->
        attrs
    end
  end

  def validate_default(attrs), do: attrs

  defp is_valid_default_type?(default, string, atom) do
    cond do
      string -> is_binary(default)
      atom -> is_atom(default)
      true -> is_same_type(default, :string)
    end
  end

  defp is_same_type(value, :string), do: is_binary(value)
  defp is_same_type(value, :integer), do: is_integer(value)
  defp is_same_type(value, :float), do: is_float(value)
  defp is_same_type(value, :atom), do: is_atom(value)
  defp is_same_type(_, :null), do: true
end
