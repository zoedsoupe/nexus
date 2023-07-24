defmodule Nexus do
  @moduledoc """
  Nexus can be used to define simple to complex CLI applications.

  The main component of Nexus is the macro `defcommand/2`, used
  to register CLI commands. Notice that the module that uses `Nexus`
  is defined as a complete CLI, with own commands and logic.

  To define a command you need to name it and pass some options:

  - `:type`: the argument type to be parsed to. It can be `:string` (default),
  `:integer`, `:float`, `{:enum, list(option)}`. The absense of this option
  will define a command without arguments, which can be used to define a subcommand
  group.
  - `:required?`: defines if the presence of the command is required or not. All commands are required by default.

  ## Usage

      defmodule MyCLI do
        use Nexus

        defcommand :foo, type: :string, required?: true

        @impl true
        def handle_input(:foo, _args) do
          IO.puts("Hello :foo command!")
        end

        Nexus.parse()

        __MODULE__.run(System.argv())
      end
  """

  @type command :: {atom, Nexus.Command.t()}

  defmacro __using__(_opts) do
    quote do
      @commands %{}

      import Nexus, only: [defcommand: 2]
      require Nexus

      @behaviour Nexus.CLI
    end
  end

  @doc """
  Like `def/2`, but registers a command that can be invoked
  from the command line. The `@doc` module attribute and the
  arguments metadata are used to generate the CLI options.

  Each defined command produces events that can be handled using
  the `Nexus.CLI` behaviour, where the event is the command
  name as an atom and the second argument is a list of arguments.
  """
  @spec defcommand(atom, keyword) :: Macro.t()
  defmacro defcommand(cmd, opts) do
    quote do
      command =
        unquote(opts)
        |> Keyword.put(:module, __MODULE__)
        |> Nexus.Command.parse!()

      @commands Map.put(@commands, unquote(cmd), command)
    end
  end

  @doc """
  Generates a default `help` command for your CLI. It uses the
  optional `banner/0` callback from `Nexus.CLI` to complement
  description.

  You can also define your own `help` command, copying the `quote/2`
  block of this macro.
  """
  defmacro help do
    quote do
      Nexus.defcommand(:help, type: :string, required?: false)

      @impl Nexus.CLI
      def handle_input(:help, _args) do
        IO.puts("Hello, I'm a help")
      end
    end
  end

  @doc """
  Generates three functions that can be used to manage and run
  your CLI.

  ### `__commands__/0`

  Return all commands that were defined into your CLI module.

  ### `run/1`

  Run your CLI against argv content. Notice that this function only runs
  a single command and returns `:ok`. It can be used to easily define
  mix tasks.

  Also this function expects that the `handle_input/2` callback from `Nexus.CLI`
  would have some implementation for the a comand `N` that would be parsed.

  ### `parse/1`

  Build a CLI based on argv content. It can be used if you want to manage
  your CLI or decide how you want to execute functions. It builds a map
  where given commands and options parsed will be keys and those values.

  #### Example

      {:ok, cli} = MyCLI.parse(System.argv)
      cli.mycommand # `arg` to `mycommand`
  """
  defmacro parse do
    quote do
      def __commands__, do: @commands

      def run([name | args]) do
        cmd = Enum.find(@commands, fn {cmd, _spec} -> to_string(cmd) == name end)
        Nexus.CommandDispatcher.dispatch!(cmd, args)
      end

      @spec parse(list(binary)) :: {:ok, Nexus.CLI.t()} | {:error, atom}
      def parse(args \\ System.argv()) do
        Nexus.CLI.build(args, __MODULE__)
      end
    end
  end

  def parse_to(:string, value) do
    to_string(value)
  end
end
