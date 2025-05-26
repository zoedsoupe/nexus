defmodule Nexus.Parser do
  @moduledoc """
  Nexus.Parser provides functionalities to parse raw input strings based on the CLI AST.
  This implementation uses manual tokenization and parsing without parser combinators.
  """

  alias Nexus.CLI.Flag

  @type result :: %{
          program: atom,
          command: list(atom),
          flags: %{atom => term},
          args: %{atom => term}
        }

  @doc """
  Parses the raw input string based on the given AST.
  """
  @spec parse_ast(cli :: Nexus.CLI.t(), input :: String.t() | list(String.t())) ::
          {:ok, result} | {:error, list(String.t())}
  def parse_ast(%Nexus.CLI{} = cli, input) when is_binary(input) do
    with {:ok, tokens} <- tokenize(input) do
      parse_ast(cli, tokens)
    end
  end

  def parse_ast(%Nexus.CLI{} = cli, tokens) when is_list(tokens) do
    with {:ok, root_cmd, tokens} <- extract_root_cmd_name(tokens),
         {:ok, root_ast} <- find_root(root_cmd, cli.spec),
         {:ok, command_path, command_ast, tokens} <- extract_commands(tokens, root_ast),
         {:ok, flags, args} <- parse_flags_and_args(tokens),
         {:ok, help_issued?} <- verify_help_presence(flags),
         {:ok, processed_flags} <- process_flags(flags, command_ast.flags, help: help_issued?),
         {:ok, processed_args} <- process_args(args, command_ast.args, help: help_issued?) do
      {:ok,
       %{
         program: cli.name,
         command: [root_cmd | Enum.map(command_path, &String.to_existing_atom/1)],
         flags: processed_flags,
         args: processed_args
       }}
    else
      {:error, reason} -> {:error, List.wrap(reason)}
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
    |> Enum.reduce({:ok, [], false, []}, &handle_quoted_string/2)
    |> case do
      {:ok, acc, false, []} ->
        {:ok, Enum.reverse(acc)}

      {:ok, _acc, true, _buffer} ->
        {:error, "Unclosed quoted string"}

      {:error, msg} ->
        {:error, [msg]}
    end
  end

  defp handle_quoted_string(token, {:ok, acc, in_quote, buffer}) do
    cond do
      raw_quoted?(token) -> handle_raw_quoted(token, buffer, in_quote, acc)
      String.starts_with?(token, "\"") -> handle_started_quoted(token, acc)
      String.ends_with?(token, "\"") and in_quote -> handle_ended_quoted(token, buffer, acc)
      in_quote -> {:ok, acc, true, [token | buffer]}
      true -> {:ok, [token | acc], in_quote, buffer}
    end
  end

  defp raw_quoted?(token) do
    String.starts_with?(token, "\"") and String.ends_with?(token, "\"") and
      String.length(token) > 1
  end

  defp handle_raw_quoted(token, buffer, in_quote, acc) do
    unquoted = String.slice(token, 1..-2//-1)
    {:ok, [unquoted | acc], in_quote, buffer}
  end

  defp handle_started_quoted(token, acc) do
    unquoted = String.trim_leading(token, "\"")
    {:ok, acc, true, [unquoted]}
  end

  defp handle_ended_quoted(token, buffer, acc) do
    unquoted = String.trim_trailing(token, "\"")
    buffer = Enum.reverse([unquoted | buffer])
    combined = Enum.join(buffer, " ")
    {:ok, [combined | acc], false, []}
  end

  ## Extraction Functions

  defp extract_root_cmd_name([program_name | rest]) do
    {:ok, String.to_existing_atom(program_name), rest}
  end

  defp extract_root_cmd_name([]), do: {:error, "No program specified"}

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
      {:ok, command_path, current_ast, [token | rest_tokens]}
    end
  end

  defp extract_commands([], command_path, current_ast) do
    # No more tokens
    {:ok, command_path, current_ast, []}
  end

  ## Lookup Functions

  defp find_root(name, ast) do
    case Enum.find(ast, &(&1.name == name)) do
      nil -> {:error, "Command '#{name}' not found"}
      program -> {:ok, program}
    end
  end

  ## Parsing Flags and Arguments

  defp parse_flags_and_args(tokens) do
    parse_flags_and_args(tokens, [{:help_flag, "help", false}], [])
  end

  defp parse_flags_and_args([], flags, args) do
    {:ok, Enum.reverse(uniq_flag_by_name(flags)), Enum.reverse(args)}
  end

  defp parse_flags_and_args([token | rest] = tokens, flags, args) do
    cond do
      "--help" in tokens or "-h" in tokens ->
        flags = [{:help_flag, "help", true} | flags]
        {:ok, Enum.reverse(uniq_flag_by_name(flags)), Enum.reverse(args)}

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

  defp uniq_flag_by_name(flags) do
    Enum.uniq_by(flags, &elem(&1, 1))
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

  defp verify_help_presence(flags) when is_list(flags) do
    help = Enum.find(flags, &help_flag?/1)
    {:ok, if(help, do: elem(help, 2), else: false)}
  end

  defp help_flag?({_type, "help", _v}), do: true
  defp help_flag?(_), do: false

  ## Processing Flags

  defp process_flags(_flag_tokens, _defined_flags, help: true) do
    {:ok, %{help: true}}
  end

  defp process_flags(flag_tokens, defined_flags, _help) do
    flags = Enum.reduce(flag_tokens, %{}, &parse_flag(&1, &2, defined_flags))

    missing_required_flags = list_missing_required_flags(flags, defined_flags)

    if Enum.empty?(missing_required_flags) do
      non_parsed_flags = list_non_parsed_flags(flags, defined_flags)

      {:ok, Map.merge(flags, non_parsed_flags)}
    else
      {:error, "Missing required flags: #{Enum.join(missing_required_flags, ", ")}"}
    end
  end

  defp defined_flag?(name, %Flag{short: nil} = flag), do: name == to_string(flag.name)

  defp defined_flag?(name, %Flag{} = flag) do
    to_string(flag.name) == name or to_string(flag.short) == name
  end

  defp parse_flag({_flag_type, "help", value}, parsed, _defined) do
    Map.put(parsed, :help, value)
  end

  defp parse_flag({_flag_type, name, value}, parsed, defined) do
    flag_def = Enum.find(defined, &defined_flag?(name, &1))

    if flag_def do
      parsed_value = parse_value(value, flag_def.type)

      Map.put(parsed, flag_def.name, parsed_value)
    else
      parsed
    end
  end

  defp list_missing_required_flags(parsed, defined) do
    defined
    |> Enum.filter(fn flag ->
      flag.required and not Map.has_key?(parsed, flag.name)
    end)
    |> Enum.map(&Atom.to_string/1)
  end

  defp list_non_parsed_flags(parsed, defined) do
    defined
    |> Enum.filter(&(not Map.has_key?(parsed, &1.name)))
    |> Map.new(&{&1.name, &1.default})
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
  defp process_args(_arg_tokens, _defined_args, help: true) do
    {:ok, %{}}
  end

  defp process_args(arg_tokens, defined_args, _help) do
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
        acc = Map.put(acc, arg_def.name, parse_value(value, arg_def.type))
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
      {:ok, Enum.map(tokens, &parse_value(&1, arg_def)), []}
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
