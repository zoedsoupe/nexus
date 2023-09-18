# Nexus

⚠️ This library is highly experimental and not ready for production use! Expect breaking changes! ⚠️

**YOU HAVE BEEN WARNED!**

```sh
     _      __
|\ ||_\/| |(_
| \||_/\|_|__)
```

> Create CLIs in a magic and declarative way!

An `Elixir` library to write command line apps in a cleaner and elegant way!

[![Hex.pm](https://img.shields.io/hexpm/v/nexus_cli.svg)](https://hex.pm/packages/nexus_cli)
[![Downloads](https://img.shields.io/hexpm/dt/nexus_cli.svg)](https://hex.pm/packages/nexus_cli)
[![Documentation](https://img.shields.io/badge/documentation-gray)](https://hexdocs.pm/nexus_cli)
[![lint](https://github.com/zoedsoupe/nexus/actions/workflows/lint.yml/badge.svg)](https://github.com/zoedsoupe/nexus/actions/workflows/lint.yml)
[![test](https://github.com/zoedsoupe/nexus/actions/workflows/test.yml/badge.svg)](https://github.com/zoedsoupe/nexus/actions/workflows/test.yml)

## Example

```elixir dark
defmodule MyCLI do
  use Nexus

  defcommand :ping, type: :null, doc: "Answers 'pong'"
  defcommand :fizzbuzz, type: :integer, required: true, doc: "Plays fizzbuzz"
  defcommand :mode, type: {:enum, ~w[fast slow]a}, required: true, doc: "Defines the command mode"

  @impl Nexus.CLI
  # no input as type == :null
  def handle_input(:ping), do: IO.puts("pong")

  @impl Nexus.CLI
  # input can be named to anything
  @spec handle_input(atom, input) :: :ok
        when input: Nexus.Command.Input.t()
  def handle_input(:fizzbuzz, %{value: value}) do
    cond do
      rem(value, 3) == 0 -> IO.puts("fizz")
      rem(value, 5) == 0 -> IO.puts("buzz")
      rem(value, 3) == 0 and rem(value, 5) == 0 -> IO.puts("fizzbuzz")
      true -> IO.puts value
    end
  end

  def handle_input(:mode, %{value: :fast), do: IO.puts "Hare"
  def handle_input(:mode, %{value: :slow), do: IO.puts "Tortoise"
end
```

More different ways to use this library can be found on the [examples](./examples) folder

## Why "Nexus"

Nexus is a connection from two different worlds! This library connects the world of CLIs with the magic world of `Elixir`!

## Inspirations

Highly inspired in [clap-rs](https://github.com/clap-rs/clap/)
