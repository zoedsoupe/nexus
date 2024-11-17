defmodule Nexus do
  @moduledoc """
  Nexus is a comprehensive toolkit for building Command-Line Interfaces (CLI) and Terminal User Interfaces (TUI) in Elixir. It provides a unified framework that simplifies the development of interactive applications running in the terminal.

  ## Overview

  The Nexus ecosystem is designed to be modular and extensible, comprising different namespaces to organize its functionalities:

  - `Nexus.CLI`: Tools and macros for building robust command-line interfaces.
  - `Nexus.TUI`: *(Upcoming)* A toolkit leveraging Phoenix LiveView and The Elm Architecture (TEA) to create rich terminal user interfaces.

  By leveraging Elixir's strengths and integrating with powerful frameworks like Phoenix LiveView, Nexus aims to streamline the process of creating both CLIs and TUIs with minimal boilerplate and maximum flexibility.

  ## Features

  - **Declarative Command Definitions**: Use expressive macros to define commands, subcommands, arguments, and flags in a clean and readable manner.
  - **Automatic Help Generation**: Automatically generate help messages and usage instructions based on your command definitions.
  - **Extensible Architecture**: Designed to be extended and integrated with other tools, making it adaptable to a wide range of applications.

  ## Getting Started with Nexus

  To start using Nexus for building CLIs, add it as a dependency in your `mix.exs` file:

  ```elixir
  def deps do
    [
      {:nexus_cli, "~> 0.5"}
    ]
  end
  ```

  Then, create your CLI module:

  ```elixir
  defmodule MyCLI do
    use Nexus.CLI, otp_app: :my_app

    # no value root command
    defcommand :version do
      description "Shows the program version"
    end

    # nested subcommand
    defcommand :file do
      description "Performs file operations such as copy, move, and delete."

      # multi value nested subcommand
      subcommand :copy do
        description "Copies files from source to destination."

        value :string, required: true, as: :source
        value :string, required: true, as: :dest

        flag :verbose do
          short :v
          description "Enables verbose output."
        end

        flag :recursive do
          short :r
          description "Copies directories recursively."
        end
      end

      # Define more subcommands as needed
    end

    @impl Nexus.CLI
    def handle_input(:version, %{value: true}) do
      # `version/1` is auto injected or you can define the callback yourself
      IO.puts(version())
    end

    def handle_input([:file, :copy], %{args: args, flags: flags}) do
      if flags[:verbose] do
        IO.puts("Copying from \#{args[:source]} to \#{args[:dest]}...")
      end

      with {:error, reason} <- do_copy(args) do
        {:error, {1, reason}}
      end
    end

    @spec do_copy(map) :: :ok | {:error, term}
    defp do_copy(%{source: _, dest: _}) do
      # Implement the copy logic here
    end
  end
  ```

  Check `Nexus.CLI` module for more information about callbacks and function returns

  > Get started today and build amazing CLI and TUI applications with Nexus!
  """
end
