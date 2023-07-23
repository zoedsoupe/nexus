defmodule Nexus do
  @moduledoc """
  Use this module in another module to mark it for
  command and documentation formatting.
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
  Like `def/2`, but the generates a function that can be invoked
  from the command line. The `@doc` module attribute and the
  arguments metadata are used to generate the CLI options.

  Each defined command produces events that can be handled using
  the `Nexus.Handle` behaviour, where the event is the command
  name as an atom.
  """
  defmacro defcommand(cmd, opts) do
    quote do
      command =
        unquote(opts)
        |> Keyword.put(:module, __MODULE__)
        |> Nexus.Command.parse!()

      @commands Map.put(@commands, unquote(cmd), command)
    end
  end

  defmacro help do
    quote do
      Nexus.defcommand(:help, type: :string, required?: false)

      @impl Nexus.CLI
      def handle_input(:help, _args) do
        IO.puts("Hello, I'm a help")
      end
    end
  end

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
