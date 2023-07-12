defmodule Nexus do
  @moduledoc """
  Use this module in another module to mark it for
  command and documentation formatting.
  """

  @doc """
  Like `def/2`, but the generates a function that can be invoked
  from the command line. The `@doc` module attribute and the
  arguments metadata are used to generate the CLI options.

  Each defined command produces events that can be handled using
  the `Nexus.Handle` behaviour, where the event is the command
  name as an atom.
  """
  defmacro defcommand(cmd, opts) do
  end
end
