defmodule Nexus.CLI do
  @moduledoc """
  Define callback that a CLI module needs to follow to be able
  to be runned and also define helper functions to parse a single
  command againts a raw input.
  """

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
      Enum.reduce(cmds, acc, fn spec, {cli, raw} ->
        {:ok, value} = parse_command(spec, raw)
        {Map.put(cli, spec.name, value), raw}
      end)

    {:ok, cli}
  end

  def parse_command(spec, raw) do
    value = Nexus.parse_to(spec.type, raw)
    {:ok, value}
  end
end
