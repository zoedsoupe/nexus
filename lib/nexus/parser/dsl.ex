defmodule Nexus.Parser.DSL do
  @moduledoc """
  A parsing combinator DSL for command-line input parsing in pure Elixir.

  This module provides functional parsing combinators that can be composed
  to build complex parsers from simple building blocks. The combinators
  follow functional programming principles and are designed to be both
  efficient and easy to reason about.

  ## Basic Combinators

  - `literal/1` - Matches exact string literals
  - `choice/1` - Tries multiple parsers, returning the first successful one
  - `many/1` - Applies a parser zero or more times
  - `sequence/1` - Applies a list of parsers in order
  - `optional/1` - Makes a parser optional (succeeds with nil if parser fails)

  ## High-Level Combinators

  - `flag_parser/1` - Parses command-line flags (--flag, -f)
  - `command_parser/1` - Parses command names and subcommands
  - `value_parser/1` - Parses typed values (strings, integers, floats, etc.)
  - `quoted_string_parser/0` - Handles quoted strings with escape sequences

  ## Usage

      iex> import Nexus.Parser.DSL
      iex> parser = sequence([literal("git"), literal("commit")])
      iex> parse(parser, ["git", "commit", "--message", "hello"])
      {:ok, ["git", "commit"], ["--message", "hello"]}

  ## Parser Result Format

  All parsers return a tuple in the format:
  - `{:ok, result, remaining_input}` on success
  - `{:error, reason}` on failure

  Where:
  - `result` is the parsed value
  - `remaining_input` is the unconsumed input tokens
  - `reason` is a descriptive error message
  """

  @typedoc "Input tokens to be parsed"
  @type input :: [String.t()]

  @typedoc "Parsed result value"
  @type result :: term()

  @typedoc "Parser success result"
  @type success :: {:ok, result(), input()}

  @typedoc "Parser error result"
  @type error :: {:error, String.t()}

  @typedoc "Parser result"
  @type parser_result :: success() | error()

  @typedoc "A parser function"
  @type parser :: (input() -> parser_result())

  @typedoc "Flag type specification"
  @type flag_type :: :boolean | :string | :integer | :float

  @doc """
  Executes a parser against the given input.

  ## Examples

      iex> import Nexus.Parser.DSL
      iex> parser = literal("hello")
      iex> parse(parser, ["hello", "world"])
      {:ok, "hello", ["world"]}

      iex> import Nexus.Parser.DSL
      iex> parser = literal("goodbye")
      iex> parse(parser, ["hello", "world"])
      {:error, "Expected 'goodbye', got 'hello'"}
  """
  @spec parse(parser(), input()) :: parser_result()
  def parse(parser, input) when is_function(parser, 1) and is_list(input) do
    parser.(input)
  end

  # =============================================================================
  # Basic Combinators
  # =============================================================================

  @doc """
  Creates a parser that matches an exact string literal.

  ## Examples

      iex> import Nexus.Parser.DSL
      iex> parser = literal("commit")
      iex> parse(parser, ["commit", "message"])
      {:ok, "commit", ["message"]}

      iex> import Nexus.Parser.DSL
      iex> parser = literal("push")
      iex> parse(parser, ["commit", "message"])
      {:error, "Expected 'push', got 'commit'"}
  """
  @spec literal(String.t()) :: parser()
  def literal(expected) when is_binary(expected) do
    fn
      [^expected | rest] -> {:ok, expected, rest}
      [actual | _] -> {:error, "Expected '#{expected}', got '#{actual}'"}
      [] -> {:error, "Expected '#{expected}', got end of input"}
    end
  end

  @doc """
  Creates a parser that tries multiple parsers in order, returning the first success.

  ## Examples

      iex> import Nexus.Parser.DSL
      iex> parser = choice([literal("git"), literal("svn"), literal("hg")])
      iex> parse(parser, ["git", "status"])
      {:ok, "git", ["status"]}

      iex> import Nexus.Parser.DSL
      iex> parser = choice([literal("add"), literal("commit")])
      iex> parse(parser, ["push", "origin"])
      {:error, "No choice matched: Expected 'add', got 'push', Expected 'commit', got 'push'"}
  """
  @spec choice([parser()]) :: parser()
  def choice(parsers) when is_list(parsers) do
    fn input ->
      choice_impl(parsers, input, [])
    end
  end

  defp choice_impl([], _input, errors) do
    {:error, "No choice matched: #{Enum.join(Enum.reverse(errors), ", ")}"}
  end

  defp choice_impl([parser | rest], input, errors) do
    case parse(parser, input) do
      {:ok, result, remaining} -> {:ok, result, remaining}
      {:error, reason} -> choice_impl(rest, input, [reason | errors])
    end
  end

  @doc """
  Creates a parser that applies another parser zero or more times.

  ## Examples

      iex> import Nexus.Parser.DSL
      iex> parser = many(literal("very"))
      iex> parse(parser, ["very", "very", "good"])
      {:ok, ["very", "very"], ["good"]}

      iex> import Nexus.Parser.DSL
      iex> parser = many(literal("not"))
      iex> parse(parser, ["good", "day"])
      {:ok, [], ["good", "day"]}
  """
  @spec many(parser()) :: parser()
  def many(parser) when is_function(parser, 1) do
    fn input ->
      many_impl(parser, input, [])
    end
  end

  defp many_impl(parser, input, acc) do
    case parse(parser, input) do
      {:ok, result, remaining} -> many_impl(parser, remaining, [result | acc])
      {:error, _} -> {:ok, Enum.reverse(acc), input}
    end
  end

  @doc """
  Creates a parser that applies parsers in sequence.

  ## Examples

      iex> import Nexus.Parser.DSL
      iex> parser = sequence([literal("git"), literal("commit")])
      iex> parse(parser, ["git", "commit", "--all"])
      {:ok, ["git", "commit"], ["--all"]}
  """
  @spec sequence([parser()]) :: parser()
  def sequence(parsers) when is_list(parsers) do
    fn input ->
      sequence_impl(parsers, input, [])
    end
  end

  defp sequence_impl([], input, acc) do
    {:ok, Enum.reverse(acc), input}
  end

  defp sequence_impl([parser | rest], input, acc) do
    case parse(parser, input) do
      {:ok, result, remaining} -> sequence_impl(rest, remaining, [result | acc])
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Creates a parser that makes another parser optional.

  ## Examples

      iex> import Nexus.Parser.DSL
      iex> parser = optional(literal("--verbose"))
      iex> parse(parser, ["--verbose", "file.txt"])
      {:ok, "--verbose", ["file.txt"]}

      iex> import Nexus.Parser.DSL
      iex> parser = optional(literal("--verbose"))
      iex> parse(parser, ["file.txt"])
      {:ok, nil, ["file.txt"]}
  """
  @spec optional(parser()) :: parser()
  def optional(parser) when is_function(parser, 1) do
    fn input ->
      case parse(parser, input) do
        {:ok, result, remaining} -> {:ok, result, remaining}
        {:error, _} -> {:ok, nil, input}
      end
    end
  end

  @doc """
  Creates a parser that applies another parser one or more times.

  ## Examples

      iex> import Nexus.Parser.DSL
      iex> parser = many1(literal("file"))
      iex> parse(parser, ["file", "file", "done"])
      {:ok, ["file", "file"], ["done"]}

      iex> import Nexus.Parser.DSL
      iex> parser = many1(literal("file"))
      iex> parse(parser, ["done"])
      {:error, "Expected at least one match"}
  """
  @spec many1(parser()) :: parser()
  def many1(parser) when is_function(parser, 1) do
    fn input ->
      case parse(many(parser), input) do
        {:ok, [], _} -> {:error, "Expected at least one match"}
        result -> result
      end
    end
  end

  # =============================================================================
  # High-Level Combinators
  # =============================================================================

  @doc """
  Creates a parser for command-line flags.

  Handles both long flags (--flag) and short flags (-f), with optional values.

  ## Examples

      iex> import Nexus.Parser.DSL
      iex> parser = flag_parser()
      iex> parse(parser, ["--verbose"])
      {:ok, {:flag, :long, "verbose", true}, []}

      iex> import Nexus.Parser.DSL
      iex> parser = flag_parser()
      iex> parse(parser, ["--output=file.txt"])
      {:ok, {:flag, :long, "output", "file.txt"}, []}

      iex> import Nexus.Parser.DSL
      iex> parser = flag_parser()
      iex> parse(parser, ["-v"])
      {:ok, {:flag, :short, "v", true}, []}
  """
  @spec flag_parser() :: parser()
  def flag_parser do
    choice([long_flag_parser(), short_flag_parser()])
  end

  @doc """
  Creates a parser for long flags (--flag or --flag=value).
  """
  @spec long_flag_parser() :: parser()
  def long_flag_parser do
    fn
      ["--" <> flag_text | rest] ->
        case String.split(flag_text, "=", parts: 2) do
          [flag_name] -> {:ok, {:flag, :long, flag_name, true}, rest}
          [flag_name, value] -> {:ok, {:flag, :long, flag_name, value}, rest}
        end

      [other | _] ->
        {:error, "Expected long flag (--flag), got '#{other}'"}

      [] ->
        {:error, "Expected long flag (--flag), got end of input"}
    end
  end

  @doc """
  Creates a parser for short flags (-f or -f=value).
  """
  @spec short_flag_parser() :: parser()
  def short_flag_parser do
    fn
      ["-" <> flag_text | rest] when flag_text != "" ->
        if String.starts_with?(flag_text, "-") do
          {:error, "Expected short flag (-f), got '--#{String.trim_leading(flag_text, "-")}'"}
        else
          case String.split(flag_text, "=", parts: 2) do
            [flag_name] -> {:ok, {:flag, :short, flag_name, true}, rest}
            [flag_name, value] -> {:ok, {:flag, :short, flag_name, value}, rest}
          end
        end

      [other | _] ->
        {:error, "Expected short flag (-f), got '#{other}'"}

      [] ->
        {:error, "Expected short flag (-f), got end of input"}
    end
  end

  @doc """
  Creates a parser for command names.

  ## Examples

      iex> import Nexus.Parser.DSL
      iex> parser = command_parser(["commit", "push", "pull"])
      iex> parse(parser, ["commit", "--message"])
      {:ok, "commit", ["--message"]}

      iex> import Nexus.Parser.DSL
      iex> parser = command_parser(["add", "remove"])
      iex> parse(parser, ["commit", "--message"])
      {:error, "Expected one of [add, remove], got 'commit'"}
  """
  @spec command_parser([String.t()]) :: parser()
  def command_parser(valid_commands) when is_list(valid_commands) do
    fn
      [command | rest] ->
        if command in valid_commands do
          {:ok, command, rest}
        else
          {:error, "Expected one of [#{Enum.join(valid_commands, ", ")}], got '#{command}'"}
        end

      [] ->
        {:error, "Expected command, got end of input"}
    end
  end

  @doc """
  Creates a parser for typed values.

  ## Examples

      iex> import Nexus.Parser.DSL
      iex> parser = value_parser(:integer)
      iex> parse(parser, ["42", "rest"])
      {:ok, 42, ["rest"]}

      iex> import Nexus.Parser.DSL
      iex> parser = value_parser(:string)
      iex> parse(parser, ["hello", "world"])
      {:ok, "hello", ["world"]}
  """
  @spec value_parser(flag_type()) :: parser()
  def value_parser(type) do
    fn
      [value | rest] ->
        case parse_typed_value(value, type) do
          {:ok, parsed_value} -> {:ok, parsed_value, rest}
          {:error, reason} -> {:error, reason}
        end

      [] ->
        {:error, "Expected #{type} value, got end of input"}
    end
  end

  @doc """
  Creates a parser for quoted strings with escape sequence handling.

  ## Examples

      iex> import Nexus.Parser.DSL
      iex> parser = quoted_string_parser()
      iex> parse(parser, ["\\"hello world\\"", "rest"])
      {:ok, "hello world", ["rest"]}

      iex> import Nexus.Parser.DSL
      iex> parser = quoted_string_parser()
      iex> parse(parser, ["unquoted", "rest"])
      {:ok, "unquoted", ["rest"]}
  """
  @spec quoted_string_parser() :: parser()
  def quoted_string_parser do
    fn
      [string | rest] ->
        {:ok, unquote_string(string), rest}

      [] ->
        {:error, "Expected string, got end of input"}
    end
  end

  @doc """
  Creates a parser that consumes remaining input as a list.

  ## Examples

      iex> import Nexus.Parser.DSL
      iex> parser = rest_parser()
      iex> parse(parser, ["file1", "file2", "file3"])
      {:ok, ["file1", "file2", "file3"], []}
  """
  @spec rest_parser() :: parser()
  def rest_parser do
    fn input ->
      {:ok, input, []}
    end
  end

  # =============================================================================
  # Utility Functions
  # =============================================================================

  @doc """
  Parses a string value into the specified type.

  ## Examples

      iex> Nexus.Parser.DSL.parse_typed_value("42", :integer)
      {:ok, 42}

      iex> Nexus.Parser.DSL.parse_typed_value("3.14", :float)
      {:ok, 3.14}

      iex> Nexus.Parser.DSL.parse_typed_value("true", :boolean)
      {:ok, true}
  """
  @spec parse_typed_value(String.t(), flag_type()) :: {:ok, term()} | {:error, String.t()}
  def parse_typed_value(value, :string), do: {:ok, value}

  def parse_typed_value(value, :boolean) when value in ["true", "false"] do
    {:ok, value == "true"}
  end

  def parse_typed_value(value, :boolean) do
    {:error, "Invalid boolean value: #{value}. Expected 'true' or 'false'"}
  end

  def parse_typed_value(value, :integer) do
    case Integer.parse(value) do
      {int, ""} -> {:ok, int}
      _ -> {:error, "Invalid integer value: #{value}"}
    end
  end

  def parse_typed_value(value, :float) do
    case Float.parse(value) do
      {float, ""} -> {:ok, float}
      _ -> {:error, "Invalid float value: #{value}"}
    end
  end

  @doc """
  Removes quotes from a string if present.

  ## Examples

      iex> Nexus.Parser.DSL.unquote_string("\\"hello world\\"")
      "hello world"

      iex> Nexus.Parser.DSL.unquote_string("hello")
      "hello"
  """
  @spec unquote_string(String.t()) :: String.t()
  def unquote_string("\"" <> rest) do
    if String.ends_with?(rest, "\"") do
      String.slice(rest, 0..-2//1)
    else
      rest
    end
  end

  def unquote_string(string), do: string

  # =============================================================================
  # Combinator Utilities
  # =============================================================================

  @doc """
  Creates a parser that applies a transformation function to the result.

  ## Examples

      iex> import Nexus.Parser.DSL
      iex> parser = literal("hello") |> map(&String.upcase/1)
      iex> parse(parser, ["hello", "world"])
      {:ok, "HELLO", ["world"]}
  """
  @spec map(parser(), (term() -> term())) :: parser()
  def map(parser, transform_fn) when is_function(parser, 1) and is_function(transform_fn, 1) do
    fn input ->
      case parse(parser, input) do
        {:ok, result, remaining} -> {:ok, transform_fn.(result), remaining}
        error -> error
      end
    end
  end

  @doc """
  Creates a parser that tags the result with a label.

  ## Examples

      iex> import Nexus.Parser.DSL
      iex> parser = literal("commit") |> tag(:command)
      iex> parse(parser, ["commit", "message"])
      {:ok, {:command, "commit"}, ["message"]}
  """
  @spec tag(parser(), atom()) :: parser()
  def tag(parser, label) when is_function(parser, 1) and is_atom(label) do
    map(parser, &{label, &1})
  end

  @doc """
  Creates a parser that ignores the result of another parser.

  ## Examples

      iex> import Nexus.Parser.DSL
      iex> parser = ignore(literal("--"))
      iex> parse(parser, ["--", "args"])
      {:ok, nil, ["args"]}
  """
  @spec ignore(parser()) :: parser()
  def ignore(parser) when is_function(parser, 1) do
    map(parser, fn _ -> nil end)
  end

  @doc """
  Creates a parser that applies multiple parsers separated by a separator.

  ## Examples

      iex> import Nexus.Parser.DSL
      iex> parser = separated_by(literal("file"), literal(","))
      iex> parse(parser, ["file", ",", "file", ",", "file"])
      {:ok, ["file", "file", "file"], []}
  """
  @spec separated_by(parser(), parser()) :: parser()
  def separated_by(element_parser, separator_parser) do
    fn input ->
      case parse(element_parser, input) do
        {:ok, first, remaining} ->
          case parse(many(sequence([separator_parser, element_parser])), remaining) do
            {:ok, rest_pairs, final_remaining} ->
              rest_elements = Enum.map(rest_pairs, fn [_, element] -> element end)
              {:ok, [first | rest_elements], final_remaining}

            {:error, reason} ->
              {:error, reason}
          end

        error ->
          error
      end
    end
  end
end
