defmodule Nexus.CLI do
  @moduledoc """
  Define callback that a CLI module needs to follow to be able
  to be runned and also define helper functions to parse a single
  command againts a raw input.
  """
  alias Nexus.Parser

  @callback version :: String.t()
  @callback banner :: String.t()
  @callback handle_input(cmd) :: :ok
            when cmd: atom
  @callback handle_input(cmd, args) :: :ok
            when cmd: atom,
                 args: Nexus.Command.Input.t()

  @optional_callbacks banner: 0, handle_input: 2, handle_input: 1

  @type t :: map

  @spec build(list(binary), module) :: {:ok, Nexus.CLI.t()} | {:error, atom}
  def build(raw, module) do
    cmds = module.__commands__()
    acc = {%{}, raw}

    {cli, _raw} =
      Enum.reduce_while(cmds, acc, fn spec, {cli, raw} ->
        try do
          input = Parser.run!(raw, spec)
          {:halt, {Map.put(cli, spec.name, input), raw}}
        rescue
          _ -> {:cont, {cli, raw}}
        end
      end)

    {:ok, struct(module, cli)}
  end
end
