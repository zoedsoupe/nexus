defmodule Nexus do
  @moduledoc """
  Nexus can be used to define simple to complex CLI applications.

  The main component of Nexus is the macro `defcommand/2`, used
  to register CLI commands. Notice that the module that uses `Nexus`
  is defined as a complete CLI, with own commands and logic.

  To define a command you need to name it and pass some options:

  - `:type`: the argument type to be parsed to. The absense of this option
  will define a command without arguments, which can be used to define a subcommand
  group. See more on the [Types](#types) section.
  - `:required`: defines if the presence of the command is required or not. All commands are required by default. If you define a command as not required, you also need to define a default value.
  - `:default`: defines a default value for the command. It can be any term, but it must be of the same type as the `:type` option.

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

  ## Types

  Nexus supports the following types:
  - `:string`: parses the argument as a string. This is the default type.
  - `:integer`: parses the argument as an integer.
  - `:float`: parses the argument as a float.
  - `:null`: parses the argument as a null value. This is useful to define subcommands.
  - `{:enum, values_list}`: parses the argument as a literal, but only if it is included into the `values_list` list. Note that current it only support string or atom values.
  """

  @type command :: Nexus.Command.t()

  defmacro __using__(_opts) do
    quote do
      Module.register_attribute(__MODULE__, :commands, accumulate: true)
      Module.register_attribute(__MODULE__, :subcommands, accumulate: true)

      import Nexus, only: [defcommand: 2, defcommand: 3]
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
    quote location: :keep do
      @commands Nexus.__make_command__!(__MODULE__, unquote(cmd), unquote(opts))
    end
  end

  defmacro defcommand(cmd, opts, do: ast) do
    subcommands = build_subcommands(ast)

    quote location: :keep do
      @commands Nexus.__make_command__!(
                  __MODULE__,
                  unquote(cmd),
                  Keyword.put(unquote(opts), :subcommands, unquote(subcommands))
                )
    end
  end

  defp build_subcommands({:__block__, _, subs}) do
    Enum.map(subs, &build_subcommands/1)
  end

  defp build_subcommands({:defcommand, _, [cmd, opts]}) do
    quote do
      Nexus.__make_command__!(__MODULE__, unquote(cmd), unquote(opts))
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
      Nexus.defcommand(:help, type: :null, doc: "Prints this help message.")

      @impl Nexus.CLI
      def handle_input(:help, _args) do
        __MODULE__
        |> Nexus.help()
        |> IO.puts()
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
      defstruct Enum.map(@commands, &{&1.name, nil})

      def __commands__, do: @commands

      def run(args) do
        raw = Enum.join(args, " ")
        Nexus.CommandDispatcher.dispatch!(__MODULE__, raw)
      end

      @spec parse(list(binary)) :: {:ok, Nexus.CLI.t()} | {:error, atom}
      def parse(args \\ System.argv()) do
        if is_list(args) do
          args
          |> Enum.join(" ")
          |> Nexus.CLI.build(__MODULE__)
        else
          Nexus.CLI.build(args, __MODULE__)
        end
      end
    end
  end

  @doc """
  Given a module which defines a CLI with `Nexus`, builds
  a default help string that can be printed safelly.

  This function is used when you use the `help/0` macro.
  """
  def help(cli_module) do
    cmds = cli_module.__commands__()

    banner =
      if function_exported?(cli_module, :banner, 0) do
        "#{cli_module.banner()}\n\n"
      end

    """
    #{banner}
    COMMANDS:
    #{Enum.map_join(cmds, "\n", fn cmd -> "  #{cmd.name} - #{cmd.doc}" end)}
    """
  end

  def __make_command__!(module, cmd_name, opts) do
    opts
    |> Keyword.put(:name, cmd_name)
    |> Keyword.put(:module, module)
    |> Keyword.put_new(:required, false)
    |> Keyword.put_new(:type, :string)
    |> Nexus.Command.parse!()
  end
end
