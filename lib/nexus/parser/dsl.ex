defmodule Nexus.Parser.DSL do
  @moduledoc """
  Simple DSL to generate Regex "parsers" for Nexus.
  """

  def boolean(input) do
    consume(input, ~r/(true|false)/)
  end

  def integer(input) do
    consume(input, ~r/-?\d+/)
  end

  def float(input) do
    consume(input, ~r/-?\d+\.\d+/)
  end

  def string(input) do
    consume(input, ~r/\w+/)
  end

  def literal(input, lit) do
    consume(input, ~r/\b#{lit}\b/)
  end

  def enum(input, values) do
    consume(input, ~r/\b(#{Enum.join(values, "|")}){1}\b/)
  end

  defp consume(input, regex) do
    if Regex.match?(regex, input) do
      cap = List.first(Regex.run(regex, input, capture: :first) || [])
      rest = Regex.replace(regex, input, "")

      (cap && {:ok, {cap, rest}}) || {:error, :no_match}
    else
      {:error, input}
    end
  end
end
