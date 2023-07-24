defmodule Nexus.CommandDispatcher do
  @moduledoc false

  alias Nexus.Command

  @spec dispatch!(Nexus.command(), list(binary)) :: :ok
  def dispatch!({cmd, %Command{} = spec}, raw) do
    {:ok, cli} = Nexus.CLI.parse_command({cmd, spec}, raw)
    spec.module.handle_input(cmd, cli)

    :ok
  end
end
