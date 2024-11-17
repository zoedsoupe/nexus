defmodule Nexus.CLI do
  @moduledoc """
  Nexus.CLI provides a macro-based DSL for defining command-line interfaces with commands,
  flags, and positional arguments using structured ASTs with structs.
  """

  defmodule Command do
    @moduledoc "Represents a command or subcommand."

    alias Nexus.CLI.Argument
    alias Nexus.CLI.Flag

    @type t :: %__MODULE__{
            name: atom | nil,
            description: String.t() | nil,
            subcommands: list(t),
            flags: list(Flag.t()),
            args: list(Argument.t())
          }

    defstruct name: nil,
              description: nil,
              subcommands: [],
              flags: [],
              args: []
  end

  defmodule Flag do
    @moduledoc "Represents a flag (option) for a command."

    @type t :: %__MODULE__{
            name: atom | nil,
            short: atom | nil,
            type: Nexus.CLI.value(),
            required: boolean,
            default: term,
            description: String.t() | nil
          }

    defstruct name: nil,
              short: nil,
              type: :boolean,
              required: false,
              default: false,
              description: nil
  end

  defmodule Argument do
    @moduledoc "Represents a positional argument for a command."

    @type t :: %__MODULE__{
            name: atom | nil,
            type: Nexus.CLI.value(),
            required: boolean
          }

    defstruct name: nil,
              type: :string,
              required: false
  end

  alias Nexus.CLI.Argument
  alias Nexus.CLI.Command
  alias Nexus.CLI.Flag

  @type ast :: list(Command.t())
  @type value ::
          :boolean
          | :string
          | :integer
          | :float
          | {:list, value}
          | {:enum, list(atom | String.t())}

  defmacro __using__(_opts) do
    quote do
      import Nexus.CLI,
        only: [
          defcommand: 2,
          subcommand: 2,
          value: 2,
          flag: 2,
          short: 1,
          description: 1
        ]

      Module.register_attribute(__MODULE__, :cli_commands, accumulate: true)
      Module.register_attribute(__MODULE__, :cli_command_stack, accumulate: false)
      Module.register_attribute(__MODULE__, :cli_flag_stack, accumulate: false)

      @before_compile Nexus.CLI
    end
  end

  # Macro to define a top-level command
  defmacro defcommand(name, do: block) do
    quote do
      # Initialize a new Command struct
      command = %Command{name: unquote(name)}

      # Push the command onto the command stack
      Nexus.CLI.__push_command__(command, __MODULE__)

      # Execute the block to populate subcommands, flags, and args
      unquote(block)

      # Finalize the command and accumulate it
      Nexus.CLI.__finalize_command__(__MODULE__)
    end
  end

  # Macro to define a subcommand within the current command
  defmacro subcommand(name, do: block) do
    quote do
      # Initialize a new Command struct for the subcommand
      subcommand = %Command{name: unquote(name)}

      # Push the subcommand onto the command stack
      Nexus.CLI.__push_command__(subcommand, __MODULE__)

      # Execute the block to populate subcommands, flags, and args
      unquote(block)

      # Finalize the subcommand and attach it to its parent
      Nexus.CLI.__finalize_subcommand__(__MODULE__)
    end
  end

  # Macro to define a positional argument
  defmacro value(type, opts \\ []) do
    quote do
      arg = %Argument{
        name: Keyword.get(unquote(opts), :as),
        type: unquote(type),
        required: Keyword.get(unquote(opts), :required, false)
      }

      Nexus.CLI.__add_argument__(arg, __MODULE__)
    end
  end

  # Macro to define a flag
  defmacro flag(name, do: block) do
    quote do
      # Initialize a new Flag struct
      flag = %Flag{name: unquote(name)}

      # Push the flag onto the flag stack
      Nexus.CLI.__push_flag__(flag, __MODULE__)

      # Execute the block to set flag properties
      unquote(block)

      # Finalize the flag and add it to its parent
      Nexus.CLI.__finalize_flag__(__MODULE__)
    end
  end

  # Macro to define a short alias for a flag
  defmacro short(short_name) do
    quote do
      Nexus.CLI.__set_flag_short__(unquote(short_name), __MODULE__)
    end
  end

  # Macro to define a description for a command, subcommand, or flag
  defmacro description(desc) do
    quote do
      Nexus.CLI.__set_description__(unquote(desc), __MODULE__)
    end
  end

  # Internal functions to manage the command stack and build the AST

  # Push a command or subcommand onto the command stack
  def __push_command__(command, module) do
    Module.put_attribute(module, :cli_command_stack, [
      command | Module.get_attribute(module, :cli_command_stack) || []
    ])
  end

  def __finalize_command__(module) do
    [command | rest] = Module.get_attribute(module, :cli_command_stack)

    if Enum.any?(rest, &(&1.name == command.name)) do
      raise "Duplicate command name: #{command.name}"
    end

    Module.put_attribute(module, :cli_commands, command)
    Module.put_attribute(module, :cli_command_stack, rest)
  end

  def __finalize_subcommand__(module) do
    [subcommand, parent | rest] = Module.get_attribute(module, :cli_command_stack)

    # Ensure no duplicate subcommand names within the parent
    if Enum.any?(parent.subcommands, &(&1.name == subcommand.name)) do
      raise "Duplicate subcommand name: #{subcommand.name} within command #{parent.name}"
    end

    updated_parent = Map.update!(parent, :subcommands, fn subs -> [subcommand | subs] end)
    Module.put_attribute(module, :cli_command_stack, [updated_parent | rest])
  end

  # Push a flag onto the flag stack
  def __push_flag__(flag, module) do
    Module.put_attribute(module, :cli_flag_stack, [
      flag | Module.get_attribute(module, :cli_flag_stack) || []
    ])
  end

  def __set_flag_short__(short_name, module) do
    [flag | rest] = Module.get_attribute(module, :cli_flag_stack)
    updated_flag = Map.put(flag, :short, short_name)
    Module.put_attribute(module, :cli_flag_stack, [updated_flag | rest])
  end

  # Set the description for the current command, subcommand, or flag
  def __set_description__(desc, module) do
    flag_stack = Module.get_attribute(module, :cli_flag_stack) || []

    if Enum.empty?(flag_stack) do
      # if we're not operating on a flag, so it's a command/subcommand
      stack = Module.get_attribute(module, :cli_command_stack) || []
      [current | rest] = stack
      updated = Map.put(current, :description, desc)
      Module.put_attribute(module, :cli_command_stack, [updated | rest])
    else
      [flag | rest] = flag_stack
      updated_flag = Map.put(flag, :description, desc)
      Module.put_attribute(module, :cli_flag_stack, [updated_flag | rest])
    end
  end

  def __finalize_flag__(module) do
    [flag | rest_flag] = Module.get_attribute(module, :cli_flag_stack)
    Module.put_attribute(module, :cli_flag_stack, rest_flag)

    [current | rest] = Module.get_attribute(module, :cli_command_stack)

    if Enum.any?(current.flags, &(&1.name == flag.name)) do
      raise "Duplicate flag name: #{flag.name} within command #{current.name}"
    end

    flag = if flag.type == :bool, do: Map.put_new(flag, :default, false), else: flag

    updated = Map.update!(current, :flags, fn flags -> [flag | flags] end)
    Module.put_attribute(module, :cli_command_stack, [updated | rest])
  end

  def __add_argument__(arg, module) do
    [current | rest] = Module.get_attribute(module, :cli_command_stack)

    updated = Map.update!(current, :args, fn args -> args ++ [arg] end)
    Module.put_attribute(module, :cli_command_stack, [updated | rest])
  end

  defmacro __before_compile__(env) do
    commands = Module.get_attribute(env.module, :cli_commands)

    quote do
      @doc false
      def __nexus_cli_commands__ do
        unquote(Macro.escape(commands))
      end

      @doc """
      Generates CLI documentation based into the CLI spec defined

      For more information, check `Nexus.CLI.Help`

      It receives the AST or an optional command path, for displaying
      subcommands help, for example
      """
      defdelegate display_help(ast, path \\ []), to: Nexus.CLI.Help, as: :display
    end
  end
end
