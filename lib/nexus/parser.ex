defmodule Nexus.Parser do
  @moduledoc "Should parse the command and return the value"

  import Nexus.Parser.DSL

  alias Nexus.Command.Input
  alias Nexus.Command
  alias Nexus.FailedCommandParsing, as: Error

  @spec run(binary, Command.t()) :: Input.t()
  def run(raw, %Command{} = cmd) do
    raw
    |> String.trim_trailing()
    |> String.trim_leading()
    |> parse_command(cmd)
    |> case do
      {:ok, input} -> input
      {:error, _} -> raise Error, "Failed to parse command #{inspect(cmd)}"
    end
  end

  defp parse_command(input, %Command{type: :null} = cmd) do
    with {:ok, {_, rest}} <- literal(input, cmd.name) do
      {:ok, Input.parse!(nil, rest)}
    end
  end

  defp parse_command(input, %Command{type: :string} = cmd) do
    with {:ok, {_, rest}} <- literal(input, cmd.name),
         {:ok, value} <- maybe_parse_required(cmd, fn -> string(rest) end) do
      {:ok, Input.parse!(value, input)}
    end
  end

  defp parse_command(input, %Command{type: :integer} = cmd) do
    with {:ok, {_, rest}} <- literal(input, cmd.name),
         {:ok, value} <- maybe_parse_required(cmd, fn -> integer(rest) end) do
      {:ok,
       value
       |> string_to!(:integer)
       |> Input.parse!(input)}
    end
  end

  defp parse_command(input, %Command{type: :float} = cmd) do
    with {:ok, {_, rest}} <- literal(input, cmd.name),
         {:ok, value} <- maybe_parse_required(cmd, fn -> float(rest) end) do
      {:ok,
       value
       |> string_to!(:float)
       |> Input.parse!(input)}
    end
  end

  defp parse_command(input, %Command{type: :atom} = cmd) do
    with {:ok, {_, rest}} <- literal(input, cmd.name),
         {:ok, value} <- maybe_parse_required(cmd, fn -> string(rest) end) do
      {:ok,
       value
       |> string_to!(:atom)
       |> Input.parse!(input)}
    end
  end

  @spec string_to!(binary, atom) :: term
  defp string_to!(raw, :integer) do
    case Integer.parse(raw) do
      {int, ""} -> int
      _ -> raise Error, "#{raw} is not a valid integer"
    end
  end

  defp string_to!(raw, :float) do
    case Float.parse(raw) do
      {float, ""} -> float
      _ -> raise Error, "#{raw} is not a valid float"
    end
  end

  # final user shoul not be use very often
  defp string_to!(raw, :atom) do
    String.to_atom(raw)
  end

  @spec maybe_parse_required(Command.t(), function) :: {:ok, term} | {:error, term}
  defp maybe_parse_required(%Command{required: true}, fun) do
    with {:ok, {value, _}} <- fun.() do
      {:ok, value}
    end
  end

  defp maybe_parse_required(%Command{required: false} = cmd, fun) do
    case fun.() do
      {:ok, {value, _}} -> {:ok, value}
      {:error, _} -> {:ok, cmd.default}
    end
  end
end
