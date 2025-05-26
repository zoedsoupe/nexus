defmodule Nexus.CLI.Validation do
  @moduledoc """
  Provides validation functions for commands, flags, and arguments within the Nexus.CLI DSL.
  """

  alias Nexus.CLI.Argument
  alias Nexus.CLI.Command
  alias Nexus.CLI.Flag

  @supported_types [:boolean, :string, :integer, :float]

  defmodule ValidationError do
    @moduledoc false
    defexception message: "Validation error"

    @spec exception(String.t()) :: %__MODULE__{message: String.t()}
    def exception(msg) do
      %__MODULE__{message: msg}
    end
  end

  @doc """
  Validates a command, including its subcommands, flags, and arguments.
  """
  @spec validate_command(Command.t()) :: Command.t()
  def validate_command(%Command{} = command) do
    command
    |> validate_command_name()
    |> validate_subcommands()
    |> validate_flags()
    |> validate_arguments()
  end

  defp validate_command_name(%Command{name: nil}) do
    raise ValidationError, "Command name is required and must be an atom."
  end

  defp validate_command_name(%Command{name: name} = command) when is_atom(name) do
    command
  end

  defp validate_command_name(%Command{name: name}) do
    raise ValidationError, "Command name must be an atom, got: #{inspect(name)}."
  end

  defp validate_subcommands(%Command{subcommands: subcommands} = command) do
    # Validate each subcommand
    subcommands = Enum.map(subcommands, &validate_command/1)
    # Check for duplicate subcommand names
    subcommand_names = Enum.map(subcommands, & &1.name)
    duplicates = find_duplicates(subcommand_names)

    if duplicates != [] do
      raise ValidationError,
            "Duplicate subcommand names in command '#{command.name}': #{Enum.join(duplicates, ", ")}."
    end

    %{command | subcommands: subcommands}
  end

  defp validate_flags(%Command{flags: flags} = command) do
    flags = Enum.map(flags, &validate_flag/1)

    flag_names = Enum.map(flags, & &1.name)
    duplicates = find_duplicates(flag_names)

    if duplicates != [] do
      raise ValidationError,
            "Duplicate flag names in command '#{command.name}': #{Enum.join(duplicates, ", ")}."
    end

    # Check for duplicate short flag names
    short_names = for flag <- flags, flag.short, do: flag.short
    duplicates_short = find_duplicates(short_names)

    if duplicates_short != [] do
      raise ValidationError,
            "Duplicate short flag aliases in command '#{command.name}': #{Enum.join(duplicates_short, ", ")}."
    end

    %{command | flags: flags}
  end

  defp validate_arguments(%Command{args: args} = command) do
    args = Enum.map(args, &validate_argument/1)

    arg_names = Enum.map(args, & &1.name)
    duplicates = find_duplicates(arg_names)

    if duplicates != [] do
      raise ValidationError,
            "Duplicate argument names in command '#{command.name}': #{Enum.join(duplicates, ", ")}."
    end

    %{command | args: args}
  end

  @doc """
  Validates a flag.
  """
  @spec validate_flag(Flag.t()) :: Flag.t()
  def validate_flag(%Flag{} = flag) do
    flag
    |> validate_flag_name()
    |> validate_flag_type()
    |> validate_flag_default()
  end

  defp validate_flag_name(%Flag{name: nil}) do
    raise ValidationError, "Flag name is required and must be an atom."
  end

  defp validate_flag_name(%Flag{name: name} = flag) when is_atom(name) do
    flag
  end

  defp validate_flag_name(%Flag{name: name}) do
    raise ValidationError, "Flag name must be an atom, got: #{inspect(name)}."
  end

  defp validate_flag_type(%Flag{type: type} = flag) do
    validate_type(type)
    flag
  end

  defp validate_flag_default(%Flag{default: default, type: type, name: name} = flag) do
    if default != nil do
      if !valid_default?(default, type) do
        raise ValidationError,
              "Default value for flag '#{name}' must be of type #{inspect(type)}, got: #{inspect(default)}."
      end
    end

    flag
  end

  @doc """
  Validates an argument.
  """
  @spec validate_argument(Argument.t()) :: Argument.t()
  def validate_argument(%Argument{} = arg) do
    arg
    |> validate_argument_name()
    |> validate_argument_type()
    |> validate_argument_default()
  end

  defp validate_argument_name(%Argument{name: nil}) do
    raise ValidationError, "Argument name is required and must be an atom."
  end

  defp validate_argument_name(%Argument{name: name} = arg) when is_atom(name) do
    arg
  end

  defp validate_argument_name(%Argument{name: name}) do
    raise ValidationError, "Argument name must be an atom, got: #{inspect(name)}."
  end

  defp validate_argument_type(%Argument{type: type} = arg) do
    validate_type(type)
    arg
  end

  defp validate_argument_default(%Argument{default: default, type: type, name: name} = arg) do
    if default != nil do
      if !valid_default?(default, type) do
        raise ValidationError,
              "Default value for argument '#{name}' must be of type #{inspect(type)}, got: #{inspect(default)}."
      end
    end

    arg
  end

  defp validate_type({:enum, values}) when is_list(values) do
    if Enum.all?(values, &is_atom/1) or Enum.all?(values, &is_binary/1) do
      :ok
    else
      raise ValidationError, "Enum values must be all atoms or all strings."
    end
  end

  defp validate_type({:list, subtype}) do
    validate_type(subtype)
  end

  defp validate_type(type) when type in @supported_types, do: :ok

  defp validate_type(type) do
    raise ValidationError, "Unsupported type: #{inspect(type)}."
  end

  defp valid_default?(default, {:enum, values}) do
    Enum.member?(values, default)
  end

  defp valid_default?(default, {:list, subtype}) when is_list(default) do
    Enum.all?(default, fn item -> valid_default?(item, subtype) end)
  end

  defp valid_default?(default, type) do
    case type do
      :boolean -> is_boolean(default)
      :string -> is_binary(default)
      :integer -> is_integer(default)
      :float -> is_float(default)
      _ -> false
    end
  end

  defp find_duplicates(list) do
    list
    |> Enum.frequencies()
    |> Enum.filter(fn {_item, count} -> count > 1 end)
    |> Enum.map(fn {item, _count} -> item end)
  end
end
