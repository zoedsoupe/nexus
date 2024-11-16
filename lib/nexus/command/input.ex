defmodule Nexus.Command.Input do
  @moduledoc """
  Define a structure to easy pattern matching the input
  on commands dispatched

  Input represents a data input for your CLI command, it have context of the inputed
  data from user, like:
  - value: the value of the command the user issued, for example, for a string command it will be a string, for a no value or subcommand parent it will be `nil`
  - raw: the raw input string, it consists on your command definition not parsed
  - subcommand: to easily match on what subcommand the input refers to. Note that in case of deeply nested subcommand tree, this field will be a list of atoms
  - command: to easily match on what command the input refers to
  - options: a map that hold flags and their values

  ## Examples
      iex> raw = ~s|mv -v -f foo ../bar|
      iex> Nexus.Parser.parse(cmd)
      iex> %Nexus.Command.Input{
      ...>   value: ["foo", "../bar"],
      ...>   raw: ^cmd,
      ...>   subcommand: nil,
      ...>   command: :mv,
      ...>   options: %{verbose: true, force: true}
      ...> }
  """

  @type t :: %__MODULE__{
          value: term | list(term),
          raw: binary,
          subcommand: list(atom) | nil,
          command: atom | nil,
          options: %{atom => term} | nil
        }

  defstruct ~w(value raw subcommand command options)a
end
