defmodule Nexus do
  @moduledoc """
  Use this module in another module to mark it for
  command and documentation formatting.
  """

  defmacro __using__(opts) do
  end

  @doc """
  Like `def/2`, but the generates a function tha can be invoked
  from the command line. The `@doc` module attribute and the
  arguments metadata are used to generate the CLI options.

  Each defined command produces events that can be handled using
  the `Nexus.Handle` behaviour, where the event is the command
  name as an atom.

  ## Example
      use Nexus

      @behaviour Nexus.Handler

      @doc \"\"\"
      Answer "fizz" on "buzz" input and "buzz" on "fizz" input.
      \"\"\"
      defcmd :fizzbuzz,
        type: {:enum, ["fizz", "buzz"]},
        required: true

      @impl Nexus.Handler
      # input can be named to anything
      def handle_input(:fizzbuzz, input) do
        # logic to answer "fizz" or "buzz"
      end
  """
  defmacro defcmd(cmd, opts) do
  end
end
