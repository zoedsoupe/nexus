defmodule Nexus.Parser do
  @moduledoc """
  Nexus.Parser provides functionalities to parse raw input strings based on the CLI AST.
  This implementation uses functional parser combinators for clean, composable parsing.
  """

  alias Nexus.CLI.Command
  alias Nexus.CLI.Flag
  alias Nexus.Parser.DSL

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
    case tokenize(input) do
      {:ok, []} -> {:error, ["No program specified"]}
      {:ok, tokens} -> parse_ast(cli, tokens)
      {:error, msg} -> {:error, [msg]}
    end
  end

  def parse_ast(%Nexus.CLI{} = cli, tokens) when is_list(tokens) do
    with {:ok, root_cmd, tokens} <- extract_root_cmd_name(tokens),
         {:ok, root_ast} <- find_root_or_use_cli(root_cmd, cli),
         {:ok, command_path, command_ast, tokens} <- extract_commands(tokens, root_ast, cli),
         {:ok, flags, args} <- parse_flags_and_args_with_context(tokens, command_ast.flags, cli.root_flags),
         {:ok, help_issued?} <- verify_help_presence(flags),
         {:ok, processed_flags} <- process_flags(flags, command_ast.flags ++ cli.root_flags, help: help_issued?),
         {:ok, processed_args} <- process_args(args, command_ast.args, help: help_issued?) do
      {:ok,
       %{
         program: cli.name,
         command: if(root_ast, do: [root_cmd | Enum.map(command_path, &String.to_atom/1)], else: []),
         flags: processed_flags,
         args: processed_args
       }}
    else
      {:error, reason} -> {:error, List.wrap(reason)}
    end
  end

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
    unquoted = String.slice(token, 1..-2//1)
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

  defp extract_root_cmd_name([program_name | rest]) do
    {:ok, String.to_existing_atom(program_name), rest}
  rescue
    ArgumentError ->
      {:error, "Command '#{program_name}' not found"}
  end

  defp extract_root_cmd_name([]), do: {:error, "No program specified"}

  defp extract_commands(tokens, program_ast, _cli) do
    if program_ast do
      extract_commands_recursive(tokens, [], program_ast)
    else
      # No command found, this might be a root flag invocation
      {:ok, [], %Command{flags: [], args: []}, tokens}
    end
  end

  defp extract_commands_recursive([token | rest_tokens], command_path, current_ast) do
    subcommand_ast =
      Enum.find(current_ast.subcommands || [], fn cmd ->
        to_string(cmd.name) == token
      end)

    if subcommand_ast do
      extract_commands_recursive(rest_tokens, command_path ++ [token], subcommand_ast)
    else
      {:ok, command_path, current_ast, [token | rest_tokens]}
    end
  end

  defp extract_commands_recursive([], command_path, current_ast) do
    {:ok, command_path, current_ast, []}
  end

  defp parse_flags_and_args_with_context(tokens, flag_definitions, root_flags) do
    all_flags = flag_definitions ++ root_flags
    flag_lookup = build_flag_lookup_maps(all_flags)
    parse_flags_and_args_with_context_impl(tokens, [{:help_flag, "help", false}], [], flag_lookup)
  end

  defp parse_flags_and_args_with_context_impl([], flags, args, _flag_definitions) do
    {:ok, Enum.reverse(uniq_flag_by_name(flags)), Enum.reverse(args)}
  end

  defp parse_flags_and_args_with_context_impl([token | rest] = tokens, flags, args, flag_definitions) do
    cond do
      help_flag_present?(tokens) ->
        finish_parsing_with_help(flags, args)

      String.starts_with?(token, "--") ->
        parse_long_flag_with_context(token, rest, flags, args, flag_definitions)

      String.starts_with?(token, "-") and token != "-" ->
        parse_short_flag_with_context(token, rest, flags, args, flag_definitions)

      true ->
        parse_argument_with_context(token, rest, flags, args, flag_definitions)
    end
  end

  defp help_flag_present?(tokens) do
    "--help" in tokens or "-h" in tokens
  end

  defp finish_parsing_with_help(flags, args) do
    flags = [{:help_flag, "help", true} | flags]
    {:ok, Enum.reverse(uniq_flag_by_name(flags)), Enum.reverse(args)}
  end

  defp parse_long_flag_with_context(token, rest, flags, args, flag_definitions) do
    case DSL.parse(DSL.long_flag_parser(), [token]) do
      {:ok, {:flag, :long, name, true}, _} ->
        handle_flag_value_consumption(:long, name, true, rest, flags, args, flag_definitions)

      {:ok, {:flag, :long, name, value}, _} ->
        parse_flags_and_args_with_context_impl(rest, [{:long_flag, name, value} | flags], args, flag_definitions)

      {:error, _} ->
        parse_flags_and_args_with_context_impl(rest, flags, [token | args], flag_definitions)
    end
  end

  defp parse_short_flag_with_context(token, rest, flags, args, flag_definitions) do
    case DSL.parse(DSL.short_flag_parser(), [token]) do
      {:ok, {:flag, :short, name, true}, _} ->
        handle_flag_value_consumption(:short, name, true, rest, flags, args, flag_definitions)

      {:ok, {:flag, :short, name, value}, _} ->
        parse_flags_and_args_with_context_impl(rest, [{:short_flag, name, value} | flags], args, flag_definitions)

      {:error, _} ->
        parse_flags_and_args_with_context_impl(rest, flags, [token | args], flag_definitions)
    end
  end

  defp parse_argument_with_context(token, rest, flags, args, flag_definitions) do
    unquoted_arg = DSL.unquote_string(token)
    parse_flags_and_args_with_context_impl(rest, flags, [unquoted_arg | args], flag_definitions)
  end

  defp handle_flag_value_consumption(flag_type, name, _default_value, rest, flags, args, flag_definitions) do
    flag_def = find_flag_definition(name, flag_definitions)

    case flag_def do
      %Flag{type: :boolean} ->
        flag_entry = {flag_type_to_atom(flag_type), name, true}
        parse_flags_and_args_with_context_impl(rest, [flag_entry | flags], args, flag_definitions)

      %Flag{type: type} when type != :boolean and rest != [] ->
        [value | remaining_rest] = rest
        flag_entry = {flag_type_to_atom(flag_type), name, value}
        parse_flags_and_args_with_context_impl(remaining_rest, [flag_entry | flags], args, flag_definitions)

      %Flag{type: type} when type != :boolean ->
        {:error, "Flag --#{name} expects a #{type} value but none was provided"}

      nil ->
        flag_entry = {flag_type_to_atom(flag_type), name, true}
        parse_flags_and_args_with_context_impl(rest, [flag_entry | flags], args, flag_definitions)
    end
  end

  defp build_flag_lookup_maps(flag_definitions) do
    long_map =
      Map.new(flag_definitions, fn flag_def ->
        {to_string(flag_def.name), flag_def}
      end)

    short_map =
      flag_definitions
      |> Enum.filter(& &1.short)
      |> Map.new(fn flag_def ->
        {to_string(flag_def.short), flag_def}
      end)

    %{long: long_map, short: short_map}
  end

  defp find_flag_definition(name, %{long: long_map, short: short_map}) do
    Map.get(long_map, name) || Map.get(short_map, name)
  end

  defp flag_type_to_atom(:long), do: :long_flag
  defp flag_type_to_atom(:short), do: :short_flag

  defp uniq_flag_by_name(flags) do
    Enum.uniq_by(flags, &elem(&1, 1))
  end

  defp find_root_or_use_cli(name, cli) do
    case Enum.find(cli.spec, &(&1.name == name)) do
      nil ->
        # Check if the name is the CLI itself (program name for root flags)
        if name == cli.name and Enum.any?(cli.root_flags) do
          # No command, just root flags
          {:ok, nil}
        else
          {:error, "Command '#{name}' not found"}
        end

      program ->
        {:ok, program}
    end
  end

  defp verify_help_presence(flags) when is_list(flags) do
    help = Enum.find(flags, &help_flag?/1)
    {:ok, if(help, do: elem(help, 2), else: false)}
  end

  defp help_flag?({_type, "help", _v}), do: true
  defp help_flag?({_type, "h", _v}), do: true
  defp help_flag?(_), do: false

  defp process_flags(_flag_tokens, _defined_flags, help: true) do
    {:ok, %{help: true}}
  end

  defp process_flags(flag_tokens, defined_flags, _help) do
    flag_lookup = build_flag_lookup_maps(defined_flags)

    case parse_all_flags(flag_tokens, flag_lookup, %{}) do
      {:ok, flags} ->
        missing_required_flags = list_missing_required_flags(flags, defined_flags)

        if Enum.empty?(missing_required_flags) do
          non_parsed_flags = list_non_parsed_flags(flags, defined_flags)
          {:ok, Map.merge(flags, non_parsed_flags)}
        else
          {:error, "Missing required flags: #{Enum.join(missing_required_flags, ", ")}"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_all_flags([], _defined_flags, acc), do: {:ok, acc}

  defp parse_all_flags([flag_token | rest], defined_flags, acc) do
    case parse_flag(flag_token, acc, defined_flags) do
      {:ok, updated_acc} ->
        parse_all_flags(rest, defined_flags, updated_acc)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_flag({_flag_type, "help", value}, parsed, _defined) do
    {:ok, Map.put(parsed, :help, value)}
  end

  defp parse_flag({_flag_type, name, value}, parsed, %{long: _, short: _} = flag_lookup) do
    flag_def = find_flag_definition(name, flag_lookup)

    if flag_def do
      case parse_value(value, flag_def.type) do
        {:ok, parsed_value} ->
          {:ok, Map.put(parsed, flag_def.name, parsed_value)}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:ok, parsed}
    end
  end

  defp list_missing_required_flags(parsed, defined) do
    defined
    |> Enum.filter(fn flag ->
      flag.required and not Map.has_key?(parsed, flag.name)
    end)
    |> Enum.map(&to_string(&1.name))
  end

  defp list_non_parsed_flags(parsed, defined) do
    defined
    |> Enum.filter(&(not Map.has_key?(parsed, &1.name)))
    |> Map.new(&{&1.name, &1.default})
  end

  defp parse_value(value, :boolean) when is_boolean(value), do: {:ok, value}
  defp parse_value("true", :boolean), do: {:ok, true}
  defp parse_value("false", :boolean), do: {:ok, false}

  defp parse_value(value, :integer) when is_integer(value), do: {:ok, value}

  defp parse_value(value, :integer) do
    case Integer.parse(value) do
      {int, ""} -> {:ok, int}
      _ -> {:error, "Invalid integer value: #{value}"}
    end
  end

  defp parse_value(value, :float) when is_float(value), do: {:ok, value}

  defp parse_value(value, :float) do
    case Float.parse(value) do
      {float, ""} -> {:ok, float}
      _ -> {:error, "Invalid float value: #{value}"}
    end
  end

  defp parse_value(value, _), do: {:ok, value}

  defp process_args(_arg_tokens, _defined_args, help: true) do
    {:ok, %{}}
  end

  defp process_args(arg_tokens, defined_args, _help) do
    case process_args_recursive(arg_tokens, defined_args, %{}) do
      {:ok, acc} -> {:ok, acc}
      {:error, reason} -> {:error, [reason]}
    end
  end

  defp process_args_recursive([], [], acc), do: {:ok, acc}

  defp process_args_recursive([token | _rest], [], _acc) do
    {:error, ["Unexpected argument '#{token}' - command does not accept arguments"]}
  end

  defp process_args_recursive(tokens, [arg_def | rest_args], acc) do
    case process_single_arg(tokens, arg_def) do
      {:ok, value, rest_tokens} ->
        case parse_value(value, arg_def.type) do
          {:ok, parsed_value} ->
            acc = Map.put(acc, arg_def.name, parsed_value)
            process_args_recursive(rest_tokens, rest_args, acc)

          {:error, reason} ->
            {:error, reason}
        end

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
      inner_type =
        case arg_def.type do
          {:list, type} -> type
          _ -> :string
        end

      case parse_list_values(tokens, inner_type, []) do
        {:ok, parsed_values} -> {:ok, parsed_values, []}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp parse_list_values([], _type, acc), do: {:ok, Enum.reverse(acc)}

  defp parse_list_values([token | rest], type, acc) do
    case parse_value(token, type) do
      {:ok, parsed_value} ->
        parse_list_values(rest, type, [parsed_value | acc])

      {:error, reason} ->
        {:error, reason}
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
