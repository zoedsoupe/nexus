defmodule Escript.Example do
  @moduledoc """
  This is an example on how to use `Nexus` with an
  escript application.

  After defined `:escript` entry into your `project/0` function
  on `mix.exs` and set the `main_module` option, you can safely
  define your commands as usual with `defcommand/2`, CLI config
  and handlers.

  Then you need to call `parse/0` macro, which will inject both
  `parse/1` and `run/1` function, which the latter you can delegate
  from the `main/1` escript funciton, as can seen below.
  """

  use Nexus.CLI

  defcommand :foo do
    description "Command that receives a string as argument and prints it."

    value :string, required: true
  end

  defcommand :fizzbuzz do
    description "Fizz bUZZ"

    value {:enum, ~w(fizz buzz)a}, required: true
  end

  defcommand :foo_bar do
    description "Teste"

    subcommand :foo do
      description "hello"

      value :string, required: false, default: "hello"
    end

    subcommand :bar do
      description "hello"

      value :string, required: false, default: "hello"
    end
  end

  @impl true
  def version, do: "0.1.0"

  @impl true
  def handle_input(:foo, input) do
    IO.puts(inspect(input))
  end

  def handle_input(:fizzbuzz, %{value: :fizz}) do
    IO.puts("buzz")
  end

  def handle_input(:fizzbuzz, %{value: :buzz}) do
    IO.puts("fizz")
  end

  def handle_input(:foo_bar, %{value: _, subcommand: :foo}) do
    # do something wth "foo" value
    :ok
  end

  def handle_input(:foo_bar, %{value: _, subcommand: :bar}) do
    # do something wth "bar" value
    :ok
  end

  # defdelegate main(args), to: __MODULE__, as: :run
end
