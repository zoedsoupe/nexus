defmodule Nexus.CLI do
  @moduledoc """
  Define callback that a CLI module needs to follow to be able
  to be runned and also define helper functions to parse a single
  command againts a raw input.
  """
  alias Nexus.Parser

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
        input = Parser.run!(raw, spec)
        {Map.put(cli, spec.name, input), raw}
      end)

    {:ok, struct(module, cli)}
  end
end
