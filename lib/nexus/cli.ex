defmodule Nexus.CLI do
  @moduledoc false

  @callback version :: String.t()
  @callback banner :: String.t()
  @callback handle_input(cmd, args) :: :ok
            when cmd: atom,
                 args: list

  @optional_callbacks banner: 0, handle_input: 2

  @type t :: map

  @spec build(list(binary), module) :: {:ok, Nexus.CLI.t()} | {:error, atom}
  def build(raw, module) do
    cmds = module.__commands__()
    acc = {%{}, raw}

    {cli, _raw} =
      Enum.reduce(cmds, acc, fn {cmd, spec}, {cli, raw} ->
        {:ok, value} = parse_command({cmd, spec}, raw)
        {Map.put(cli, cmd, value), raw}
      end)

    {:ok, cli}
  end

  def parse_command({_cmd, spec}, raw) do
    value = Nexus.parse_to(spec.type, raw)
    {:ok, value}
  end
end
