# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Nexus is an Elixir library for building command-line interfaces (CLIs) using a declarative macro-based DSL. It provides a clean way to define commands, subcommands, flags, and arguments with automatic help generation and input parsing.

## Core Architecture

### Main Components

- **`Nexus.CLI`** - Core module providing the macro-based DSL (`defcommand`, `flag`, `value`, etc.) and the main behavior
- **`Nexus.Parser`** - Handles tokenization and parsing of command-line input against the defined CLI AST
- **`Nexus.CLI.Dispatcher`** - Dispatches parsed commands to handler functions
- **`Nexus.CLI.Help`** - Generates help documentation from CLI definitions
- **`Nexus.CLI.Validation`** - Validates command and flag definitions

### Key Concepts

- CLI definitions are built into an AST (Abstract Syntax Tree) of `Command` structs
- Commands can have subcommands, flags, and positional arguments
- The `handle_input/2` callback receives the command path and an `Input` struct with parsed flags/args
- Help flags (`--help`, `-h`) are automatically injected into all commands

## Development Commands

### Testing
```bash
mix test                    # Run all tests
mix test test/specific_test.exs  # Run specific test file
```

### Code Quality
```bash
mix credo                   # Run code analysis (currently clean)
mix dialyzer               # Run type checking (has 1 known issue in examples/)
```

### Dependencies
```bash
mix deps.get               # Get dependencies
mix deps.compile           # Compile dependencies
```

### Build & Distribution
```bash
mix escript.build          # Build executable script
mix compile                # Compile the library
```

## CLI Usage Patterns

### Basic CLI Definition
```elixir
defmodule MyCLI do
  use Nexus.CLI, otp_app: :my_app

  defcommand :my_command do
    description "Command description"
    value :string, required: true, as: :filename
    
    flag :verbose do
      short :v
      description "Enable verbose output"
    end
  end

  @impl Nexus.CLI
  def handle_input(:my_command, %{flags: flags, args: args}) do
    # Implementation
    :ok
  end
end
```

### Command Execution
- Use `execute/1` function with string or list of arguments
- Returns `:ok` for success or `{:error, {code, reason}}` for errors
- Help is automatically available via `--help` or `-h` flags

## Important Notes

- All CLI modules must implement the `Nexus.CLI` behavior
- The `:otp_app` option is required when using `Nexus.CLI`
- Commands with multiple arguments must specify names via `:as` option
- Help flags are automatically injected into all commands
- The library supports escript compilation for standalone executables