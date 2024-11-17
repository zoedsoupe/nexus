defmodule Nexus.Parser do
  @moduledoc """
  Nexus.Parser provides functionalities to parse raw input strings based on the CLI AST.
  This implementation uses manual tokenization and parsing without parser combinators.
  """

  @type result :: %{
          program: atom,
          command: list(atom),
          flags: %{atom => term},
          args: %{atom => term}
        }

  @doc """
  Parses the raw input string based on the given AST.
  """
  @spec parse_ast(ast :: Nexus.CLI.ast(), input :: String.t()) ::
          {:ok, result} | {:error, list(String.t())}
  def parse_ast(ast, input) when is_list(ast) and is_binary(input) do
    with {:ok, tokens} <- tokenize(input),
         {:ok, program_name, tokens} <- extract_program_name(tokens),
         {:ok, program_ast} <- find_program(program_name, ast),
         {:ok, command_path, command_ast, tokens} <- extract_commands(tokens, program_ast),
         {:ok, flags, args} <- parse_flags_and_args(tokens),
         {:ok, processed_flags} <- process_flags(flags, command_ast.flags),
         {:ok, processed_args} <- process_args(args, command_ast.args) do
      {:ok,
       %{
         program: program_name,
         command: Enum.map(command_path, &String.to_existing_atom/1),
         flags: processed_flags,
         args: processed_args
       }}
    end
  end

  ## Tokenization Functions

  defp tokenize(input) do
    input
    |> String.trim()
    |> String.split(~r/\s+/, trim: true)
    |> handle_quoted_strings()
  end

  defp handle_quoted_strings(tokens) do
    tokens
    |> Enum.reduce({:ok, [], false, []}, fn token, {:ok, acc, in_quote, buffer} ->
      cond do
        String.starts_with?(token, "\"") and String.ends_with?(token, "\"") and
            String.length(token) > 1 ->
          # Token starts and ends with quotes
          unquoted = String.slice(token, 1..-2//-1)
          {:ok, [unquoted | acc], in_quote, buffer}

        String.starts_with?(token, "\"") ->
          # Start of a quoted string
          unquoted = String.trim_leading(token, "\"")
          {:ok, acc, true, [unquoted]}

        String.ends_with?(token, "\"") and in_quote ->
          # End of a quoted string
          unquoted = String.trim_trailing(token, "\"")
          buffer = Enum.reverse([unquoted | buffer])
          combined = Enum.join(buffer, " ")
          {:ok, [combined | acc], false, []}

        in_quote ->
          # Inside a quoted string
          {:ok, acc, true, [token | buffer]}

        true ->
          # Regular token
          {:ok, [token | acc], in_quote, buffer}
      end
    end)
    |> case do
      {:ok, acc, false, []} ->
        {:ok, Enum.reverse(acc)}

      {:ok, _acc, true, _buffer} ->
        {:error, "Unclosed quoted string"}

      {:error, msg} ->
        {:error, [msg]}
    end
  end

  ## Extraction Functions

  defp extract_program_name([program_name | rest]) do
    {:ok, String.to_existing_atom(program_name), rest}
  end

  defp extract_program_name([]), do: {:error, "No program specified"}

  defp extract_commands(tokens, program_ast) do
    extract_commands(tokens, [], program_ast)
  end

  defp extract_commands([token | rest_tokens], command_path, current_ast) do
    subcommand_ast =
      Enum.find(current_ast.subcommands || [], fn cmd ->
        to_string(cmd.name) == token
      end)

    if subcommand_ast do
      # Found a subcommand, add it to the path and continue
      extract_commands(rest_tokens, command_path ++ [token], subcommand_ast)
    else
      # No matching subcommand, return current command path and ast
      if command_path == [] do
        {:error, "Unknown subcommand: #{token}"}
      else
        {:ok, command_path, current_ast, [token | rest_tokens]}
      end
    end
  end

  defp extract_commands([], command_path, current_ast) do
    # No more tokens
    {:ok, command_path, current_ast, []}
  end

  ## Lookup Functions

  defp find_program(name, ast) do
    case Enum.find(ast, &(&1.name == name)) do
      nil -> {:error, "Program '#{name}' not found"}
      program -> {:ok, program}
    end
  end

  ## Parsing Flags and Arguments

  defp parse_flags_and_args(tokens) do
    parse_flags_and_args(tokens, [], [])
  end

  defp parse_flags_and_args([], flags, args) do
    {:ok, Enum.reverse(flags), Enum.reverse(args)}
  end

  defp parse_flags_and_args([token | rest], flags, args) do
    cond do
      String.starts_with?(token, "--") ->
        # Long flag
        parse_long_flag(token, rest, flags, args)

      String.starts_with?(token, "-") and token != "-" ->
        # Short flag
        parse_short_flag(token, rest, flags, args)

      true ->
        # Argument
        parse_flags_and_args(rest, flags, [token | args])
    end
  end

  defp parse_long_flag(token, rest, flags, args) do
    case String.split(token, "=", parts: 2) do
      [flag] ->
        flag_name = String.trim_leading(flag, "--")
        parse_flags_and_args(rest, [{:long_flag, flag_name, true} | flags], args)

      [flag, value] ->
        flag_name = String.trim_leading(flag, "--")
        parse_flags_and_args(rest, [{:long_flag, flag_name, value} | flags], args)
    end
  end

  defp parse_short_flag(token, rest, flags, args) do
    case String.split(token, "=", parts: 2) do
      [flag] ->
        flag_name = String.trim_leading(flag, "-")
        parse_flags_and_args(rest, [{:short_flag, flag_name, true} | flags], args)

      [flag, value] ->
        flag_name = String.trim_leading(flag, "-")
        parse_flags_and_args(rest, [{:short_flag, flag_name, value} | flags], args)
    end
  end

  ## Processing Flags

  defp process_flags(flag_tokens, defined_flags) do
    flags =
      Enum.reduce(flag_tokens, %{}, fn {_flag_type, name, value}, acc ->
        name_atom = String.to_atom(name)

        flag_def =
          Enum.find(defined_flags, fn flag ->
            flag.name == name_atom || (flag.short && flag.short == name_atom)
          end)

        if flag_def do
          parsed_value = parse_value(value, flag_def.type)

          Map.put(acc, Atom.to_string(flag_def.name), parsed_value)
        else
          acc
        end
      end)

    missing_required_flags = list_missing_required_flags(flags, defined_flags)

    if not Enum.empty?(missing_required_flags) do
      {:error, "Missing required flags: #{Enum.join(missing_required_flags, ", ")}"}
    else
      non_parsed_flags = list_non_parsed_flags(flags, defined_flags)

      {:ok,
       flags
       |> Map.new(fn {k, v} -> {String.to_existing_atom(k), v} end)
       |> Map.merge(non_parsed_flags)}
    end
  end

  defp list_missing_required_flags(parsed, defined) do
    defined
    |> Enum.filter(fn flag ->
      flag.required and not Map.has_key?(parsed, Atom.to_string(flag.name))
    end)
    |> Enum.map(&Atom.to_string/1)
  end

  defp list_non_parsed_flags(parsed, defined) do
    defined
    |> Enum.filter(&(not Map.has_key?(parsed, Atom.to_string(&1.name))))
    |> Enum.map(&{&1.name, &1.default})
    |> Map.new()
  end

  defp parse_value(value, :boolean) when is_boolean(value), do: value
  defp parse_value("true", :boolean), do: true
  defp parse_value("false", :boolean), do: false

  defp parse_value(value, :integer) when is_integer(value), do: value

  defp parse_value(value, :integer) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> raise ArgumentError, "Invalid integer value: #{value}"
    end
  end

  defp parse_value(value, :float) when is_float(value), do: value

  defp parse_value(value, :float) do
    case Float.parse(value) do
      {float, ""} -> float
      _ -> raise ArgumentError, "Invalid float value: #{value}"
    end
  end

  defp parse_value(value, _), do: value

  ## Processing Arguments

  defp process_args(arg_tokens, defined_args) do
    case process_args_recursive(arg_tokens, defined_args, %{}) do
      {:ok, acc} -> {:ok, acc}
      {:error, reason} -> {:error, [reason]}
    end
  end

  defp process_args_recursive(_tokens, [], acc) do
    {:ok, acc}
  end

  defp process_args_recursive(tokens, [arg_def | rest_args], acc) do
    case process_single_arg(tokens, arg_def) do
      {:ok, value, rest_tokens} ->
        acc = Map.put(acc, arg_def.name, value)
        process_args_recursive(rest_tokens, rest_args, acc)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp process_single_arg(tokens, arg_def) do
    case arg_def.type do
      {:list, _type} -> process_list_arg(tokens, arg_def)
      {:enum, values_list} -> process_enum_arg(tokens, arg_def, values_list)
      _ -> process_default_arg(tokens, arg_def)
    end
  end

  defp process_list_arg(tokens, arg_def) do
    if tokens == [] and arg_def.required do
      {:error, "Missing required argument '#{arg_def.name}' of type list"}
    else
      {:ok, tokens, []}
    end
  end

  defp process_enum_arg([value | rest_tokens], arg_def, values_list) do
    if value in Enum.map(values_list, &to_string/1) do
      {:ok, value, rest_tokens}
    else
      {:error,
       "Invalid value for argument '#{arg_def.name}': expected one of [#{Enum.join(values_list, ", ")}], got '#{value}'"}
    end
  end

  defp process_enum_arg([], arg_def, _values_list) do
    if arg_def.required do
      {:error, "Missing required argument '#{arg_def.name}'"}
    else
      {:ok, nil, []}
    end
  end

  defp process_default_arg([value | rest_tokens], _arg_def) do
    {:ok, value, rest_tokens}
  end

  defp process_default_arg([], arg_def) do
    if arg_def.required do
      {:error, "Missing required argument '#{arg_def.name}'"}
    else
      {:ok, nil, []}
    end
  end
end
