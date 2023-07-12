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

## Example

```elixir dark
defmodule MyCommand do
  use Nexus

  @behaviour Nexus.Handler

  @doc """
  Answer "fizz" on "buzz" input and "buzz" on "fizz" input.
  """
  defcommand :fizzbuzz, type: {:enum, ["fizz", "buzz"]}, required: true

  @impl Nexus.Handler
  # input can be named to anything
  def handle_input(:fizzbuzz, input) do
    # logic to answer "fizz" or "buzz"
  end
end
```

## Why "Nexus"

Nexus is a connection from two different worlds! This library connects the world of CLIs with the magic world of `Elixir`!
