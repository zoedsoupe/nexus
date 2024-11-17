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
[![ci](https://github.com/zoedsoupe/nexus/actions/workflows/ci.yml/badge.svg)](https://github.com/zoedsoupe/nexus/actions/workflows/ci.yml)

## Example

```elixir
defmodule MyCLI do
  @moduledoc "This will be used into as help"

  use Nexus.CLI

  defcommand :fizzbuzz do
    description "Plays fizzbuzz - this will also be used as help"

    value :integer, required: true
  end

  @impl Nexus.CLI
  def handle_input(:fizzbuzz, %{args: [input]}) do
    # plays fizzbuzz
  end
end
```

More different ways to use this library can be found on the [examples](./examples) folder

## Why "Nexus"

Nexus is a connection from two different worlds! This library connects the world of CLIs with the magic world of `Elixir`!

## Inspirations

Highly inspired in [clap-rs](https://github.com/clap-rs/clap/)
