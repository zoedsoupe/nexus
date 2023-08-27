# Nexus

```sh
     _      __
|\ ||_\/| |(_
| \||_/\|_|__)
```

> Create CLIs in a magic and declarative way!

An `Elixir` library to write command line apps in a cleaner and elegant way!

[![lint](https://github.com/zoedsoupe/nexus/actions/workflows/lint.yml/badge.svg)](https://github.com/zoedsoupe/nexus/actions/workflows/lint.yml)
[![test](https://github.com/zoedsoupe/nexus/actions/workflows/test.yml/badge.svg)](https://github.com/zoedsoupe/nexus/actions/workflows/test.yml)
[![Hex.pm](https://img.shields.io/hexpm/v/phoenix.svg)](https://hex.pm/packages/nexus_cli)
[![Documentation](https://img.shields.io/badge/documentation-gray)](https://hexdocs.pm/nexus_cli)

## Example

```elixir dark
defmodule MyCLI do
  use Nexus

  @doc """
  Answer "fizz" on "buzz" input and "buzz" on "fizz" input.
  """
  defcommand :fizzbuzz, type: {:enum, ["fizz", "buzz"]}, required?: true

  @impl Nexus.CLI
  # input can be named to anything
  @spec handle_input(atom, input) :: :ok
        when input: Nexus.Command.Input.t()
  def handle_input(:fizzbuzz, %{value: value}) do
    # logic to answer "fizz" or "buzz"
    :ok
  end
end
```

## Why "Nexus"

Nexus is a connection from two different worlds! This library connects the world of CLIs with the magic world of `Elixir`!
