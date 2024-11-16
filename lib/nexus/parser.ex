defmodule Nexus.Parser do
  @moduledoc """
  Nexus.Parser provides functionalities to parse raw input strings based on the CLI AST
  using the NimbleParsec library. This implementation specifically handles nested commands,
  typed arguments, and flag variations according to the Nexus.CLI specification.
  """

  import NimbleParsec

  alias Nexus.CLI.Command

  # Basic combinators
  whitespace = ascii_char([?\s, ?\t]) |> label("whitespace")
  defcombinatorp :ws, repeat(whitespace) |> ignore()

  # Command name combinator
  defcombinatorp :command_name,
                 ascii_string([?a..?z, ?A..?Z, ?0..?9, ?_], min: 1)
                 |> reduce({List, :to_string, []})
                 |> map({String, :to_atom, []})
                 |> label("command")

  # String value combinator
  defcombinatorp :string_value,
                 choice([
                   ignore(string("\""))
                   |> repeat(
                     choice([
                       string("\\\"") |> replace("\""),
                       utf8_char(not: ?")
                     ])
                   )
                   |> ignore(string("\""))
                   |> reduce({List, :to_string, []}),
                   ascii_string([not: ?\s], min: 1)
                   |> reduce({List, :to_string, []})
                 ])
                 |> label("string value")

  # Number value combinators
  defcombinatorp :integer_value,
                 optional(string("-"))
                 |> concat(ascii_string([?0..?9], min: 1))
                 |> reduce(:parse_integer_value)

  defp parse_integer_value([sign, digits]) do
    String.to_integer("#{sign}#{digits}")
  end

  defp parse_integer_value([digits]) do
    String.to_integer("#{digits}")
  end

  defcombinatorp :float_value,
                 optional(string("-"))
                 |> concat(ascii_string([?0..?9], min: 1))
                 |> ignore(string("."))
                 |> concat(ascii_string([?0..?9], min: 1))
                 |> reduce(:parse_float_value)

  defp parse_float_value([sign, int_part, frac_part]) do
    String.to_float("#{sign}#{int_part}.#{frac_part}")
  end

  defp parse_float_value([int_part, frac_part]) do
    String.to_float("#{int_part}.#{frac_part}")
  end

  defcombinatorp :number_value,
                 choice([
                   parsec(:float_value),
                   parsec(:integer_value)
                 ])

  defcombinatorp :value,
                 choice([
                   parsec(:number_value),
                   parsec(:string_value)
                 ])

  # Flag name combinator
  defcombinatorp :flag_name,
                 ascii_string([?a..?z, ?A..?Z, ?0..?9, ?_], min: 1)
                 |> reduce({List, :to_string, []})
                 |> map({String, :to_atom, []})

  # Flag combinators
  defcombinatorp :short_flag,
                 ignore(string("-"))
                 |> concat(parsec(:flag_name))
                 |> map({:handle_short_flag, []})
                 |> label("short flag")

  defcombinatorp :long_flag,
                 ignore(string("--"))
                 |> concat(parsec(:flag_name))
                 |> map({:handle_long_flag, []})
                 |> label("long flag")

  defcombinatorp :short_flag_with_value,
                 ignore(string("-"))
                 |> parsec(:flag_name)
                 |> ignore(string("="))
                 |> concat(parsec(:value))
                 |> reduce({:handle_short_flag_with_value, []})
                 |> label("short flag with value")

  defcombinatorp :long_flag_with_value,
                 ignore(string("--"))
                 |> parsec(:flag_name)
                 |> ignore(string("="))
                 |> concat(parsec(:value))
                 |> reduce({:handle_long_flag_with_value, []})
                 |> label("long flag with value")

  defcombinatorp :flag,
                 choice([
                   parsec(:long_flag_with_value),
                   parsec(:short_flag_with_value),
                   parsec(:long_flag),
                   parsec(:short_flag)
                 ])

  # Command parser with nested structure
  defparsec :command_parser,
            parsec(:command_name)
            |> optional(
              parsec(:ws)
              |> parsec(:command_name)
            )
            |> optional(
              parsec(:ws)
              |> repeat(
                parsec(:flag)
                |> optional(parsec(:ws))
              )
            )
            |> optional(
              parsec(:ws)
              |> repeat(
                parsec(:string_value)
                |> optional(parsec(:ws))
              )
            )
            |> eos()

  # Helper functions for flag handling
  defp handle_short_flag(name) do
    {:short_flag, name, true}
  end

  defp handle_long_flag(name) do
    {:long_flag, name, true}
  end

  defp handle_short_flag_with_value([name, value]) do
    {:short_flag, name, value}
  end

  defp handle_long_flag_with_value([name, value]) do
    {:long_flag, name, value}
  end

  @doc """
  Parses the raw input string based on the given AST.
  """
  @spec parse_ast([Command.t()], String.t()) ::
          {:ok, map()} | {:error, list(String.t())}
  def parse_ast(ast, input) when is_list(ast) and is_binary(input) do
    case command_parser(input) do
      {:ok, parsed, "", _, _, _} ->
        process_parsed_command(parsed, ast)

      {:error, _reason, _, _, _, _} ->
        {:error, ["Invalid input."]}

      _ ->
        {:error, ["No command found."]}
    end
  end

  defp process_parsed_command(parsed, ast) do
    case extract_command_structure(parsed) do
      {program, command, flags, args} ->
        with {:ok, program_ast} <- find_program(program, ast),
             {:ok, command_ast} <- find_command(command, program_ast),
             {:ok, processed_flags} <- process_flags(flags, command_ast.flags),
             {:ok, processed_args} <- process_args(args, command_ast.args) do
          {:ok,
           %{
             command: Atom.to_string(command),
             flags: processed_flags,
             args: processed_args
           }}
        else
          {:error, msg} when is_binary(msg) -> {:error, [msg]}
          err -> err
        end

      _ ->
        {:error, ["Invalid command structure"]}
    end
  end

  defp extract_command_structure(parsed) do
    Enum.reduce(parsed, {nil, nil, [], []}, fn
      atom, {nil, nil, flags, args} when is_atom(atom) ->
        {atom, nil, flags, args}

      atom, {program, nil, flags, args} when is_atom(atom) ->
        {program, atom, flags, args}

      {:short_flag, name, value}, {program, command, flags, args} ->
        {program, command, [{:short, name, value} | flags], args}

      {:long_flag, name, value}, {program, command, flags, args} ->
        {program, command, [{:long, name, value} | flags], args}

      string, {program, command, flags, args} when is_binary(string) ->
        {program, command, flags, [string | args]}
    end)
  end

  defp find_program(name, ast) do
    case Enum.find(ast, &(&1.name == name)) do
      nil -> {:error, "Program '#{name}' not found"}
      program -> {:ok, program}
    end
  end

  defp find_command(name, program) do
    case Enum.find(program.subcommands, &(&1.name == name)) do
      nil -> {:error, "Unknown subcommand: #{name}"}
      command -> {:ok, command}
    end
  end

  defp process_flags(flag_tokens, defined_flags) do
    {:ok,
     Enum.reduce(flag_tokens, %{}, fn {_type, name, value}, acc ->
       flag_def = find_flag_definition(name, defined_flags)

       if flag_def do
         Map.put(acc, flag_def.name, value)
       else
         acc
       end
     end)}
  end

  defp find_flag_definition(name, defined_flags) do
    Enum.find(defined_flags, fn flag ->
      name == flag.name || name == flag.short
    end)
  end

  defp process_args(arg_tokens, defined_args) do
    arg_tokens = Enum.reverse(arg_tokens)

    args_result =
      Enum.reduce_while(Enum.with_index(defined_args), %{}, fn {arg_def, index}, acc ->
        case arg_def.type do
          {:list, _} ->
            values = Enum.drop(arg_tokens, index)

            if values == [] and arg_def.required do
              {:halt, {:error, "Invalid input."}}
            else
              {:cont, Map.put(acc, arg_def.name, values)}
            end

          {:enum, values} ->
            value = Enum.at(arg_tokens, index)

            cond do
              is_nil(value) and arg_def.required -> {:halt, {:error, "Invalid input."}}
              value not in Enum.map(values, &to_string/1) -> {:halt, {:error, "Invalid input."}}
              true -> {:cont, Map.put(acc, arg_def.name, value)}
            end

          _ ->
            value = Enum.at(arg_tokens, index)

            if is_nil(value) and arg_def.required do
              {:halt, {:error, "Invalid input."}}
            else
              {:cont, Map.put(acc, arg_def.name, value)}
            end
        end
      end)

    case args_result do
      {:error, reason} -> {:error, [reason]}
      args -> {:ok, args}
    end
  end
end
