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
    consume(input, ~r/[a-zA-Z]+/)
  end

  def literal(input, lit) do
    consume(input, ~r/\b#{lit}\b/)
  end

  def enum(input, values) do
    consume(input, ~r/\b(#{Enum.join(values, "|")})\b/)
  end

  defp consume(input, regex) do
    if Regex.match?(regex, input) do
      cap = hd(Regex.run(regex, input, capture: :first))
      rest = Regex.replace(regex, input, "")
      {:ok, {cap, rest}}
    else
      {:error, input}
    end
  end
end
