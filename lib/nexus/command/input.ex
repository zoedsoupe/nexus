defmodule Nexus.Command.Input do
  @moduledoc """
  Define a structure to easy pattern matching the input
  on commands dispatched
  """

  @type t :: %__MODULE__{value: term, raw: binary, subcommand: atom}

  @enforce_keys ~w(value raw)a
  defstruct value: nil, raw: nil, subcommand: nil

  @spec parse!(term, binary) :: Nexus.Command.Input.t()
  def parse!(value, raw) do
    %__MODULE__{value: value, raw: raw}
  end
end
