defmodule Nexus.CLI.Helpers do
  @moduledoc """
  Common CLI helper functions.
  """

  @doc """
  Prints a success message to the console.
  """
  def say_success(message) do
    IO.puts(IO.ANSI.green() <> message <> IO.ANSI.reset())
  end

  @doc """
Asks a question and returns the user's input as a string.

## Examples
    iex> ask("What's your name?")
    "John"

    iex> ask("Enter a number:", "> ")
    "42"
"""
@spec ask(question :: String.t()) :: String.t()
@spec ask(question :: String.t(), prompt_symbol :: String.t()) :: String.t()
def ask(question, prompt_symbol \\ " ") do
  IO.gets(question <> prompt_symbol) |> String.trim()
end

  @doc """
  Asks a yes/no question and returns true for yes and false for no.

  ## Options
  - confirmations: A list of strings that are considered affirmative responses.
                    Defaulting to ["y", "yes"].
  - negations: A list of strings that are considered negative responses.
                Defaulting to `["n", "no"]`.
  """
  @spec yes?(question :: String.t(), confirmations :: list(String.t()), negations :: list(String.t())) :: boolean
  def yes?(question, confirmations \\ ["y", "yes"], negations \\ ["n", "no"]) do
    response = ask(question <> " (y/n)") |> String.downcase()

    cond do
      response in confirmations -> true
      response in negations -> false
      true -> yes?(question, confirmations, negations)
    end
  end

  @doc """
  Asks a yes/no question and returns true for no and false for yes.
  """
  def no?(question) do
    not yes?(question)
  end
end
