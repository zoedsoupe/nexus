defmodule Nexus.CLI do
  @moduledoc """
  Nexus.CLI provides a macro-based DSL for defining command-line interfaces with commands,
  flags, and positional arguments using structured ASTs with structs.
  """

  defmodule Command do
    @moduledoc "Represents a command or subcommand."
    defstruct name: nil,
              description: nil,
              subcommands: [],
              flags: [],
              args: []
  end

  defmodule Flag do
    @moduledoc "Represents a flag (option) for a command."
    defstruct name: nil,
              short: nil,
              type: :boolean,
              required: false,
              default: false,
              description: nil
  end

  defmodule Argument do
    @moduledoc "Represents a positional argument for a command."
    defstruct name: nil,
              type: :string,
              required: false
  end

  alias Nexus.CLI.{Command, Flag, Argument}

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

      # Initialize module attributes to accumulate commands and manage stacks
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

  # Finalize a top-level command and accumulate it
  def __finalize_command__(module) do
    [command | rest] = Module.get_attribute(module, :cli_command_stack)

    # Ensure no duplicate command names
    if Enum.any?(rest, fn cmd -> cmd.name == command.name end) do
      raise "Duplicate command name: #{command.name}"
    end

    Module.put_attribute(module, :cli_commands, command)
    Module.put_attribute(module, :cli_command_stack, rest)
  end

  # Finalize a subcommand and attach it to its parent
  def __finalize_subcommand__(module) do
    [subcommand, parent | rest] = Module.get_attribute(module, :cli_command_stack)

    # Ensure no duplicate subcommand names within the parent
    if Enum.any?(parent.subcommands, fn sc -> sc.name == subcommand.name end) do
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

  # Set the short alias for the current flag
  def __set_flag_short__(short_name, module) do
    [flag | rest] = Module.get_attribute(module, :cli_flag_stack)
    updated_flag = Map.put(flag, :short, short_name)
    Module.put_attribute(module, :cli_flag_stack, [updated_flag | rest])
  end

  # Set the description for the current command, subcommand, or flag
  def __set_description__(desc, module) do
    # Check if a flag is currently being defined
    flag_stack = Module.get_attribute(module, :cli_flag_stack) || []

    cond do
      flag_stack != [] ->
        [flag | rest] = flag_stack
        updated_flag = Map.put(flag, :description, desc)
        Module.put_attribute(module, :cli_flag_stack, [updated_flag | rest])

      true ->
        # Otherwise, set the description for the current command or subcommand
        stack = Module.get_attribute(module, :cli_command_stack) || []
        [current | rest] = stack
        updated = Map.put(current, :description, desc)
        Module.put_attribute(module, :cli_command_stack, [updated | rest])
    end
  end

  # Finalize a flag and add it to its parent with validation
  def __finalize_flag__(module) do
    [flag | rest_flag] = Module.get_attribute(module, :cli_flag_stack)
    Module.put_attribute(module, :cli_flag_stack, rest_flag)

    # Attach the flag to the current command or subcommand
    [current | rest] = Module.get_attribute(module, :cli_command_stack)

    # Check for duplicate flag names within the current command or subcommand
    if Enum.any?(current.flags, fn existing_flag -> existing_flag.name == flag.name end) do
      raise "Duplicate flag name: #{flag.name} within command #{current.name}"
    end

    # Validate flag defaults based on type
    flag =
      case flag.type do
        :boolean ->
          Map.put_new(flag, :default, false)

        _ ->
          flag
      end

    updated = Map.update!(current, :flags, fn flags -> [flag | flags] end)
    Module.put_attribute(module, :cli_command_stack, [updated | rest])
  end

  # Add an argument to the current command or subcommand
  def __add_argument__(arg, module) do
    [current | rest] = Module.get_attribute(module, :cli_command_stack)

    # Append the argument to maintain order
    updated = Map.update!(current, :args, fn args -> args ++ [arg] end)
    Module.put_attribute(module, :cli_command_stack, [updated | rest])
  end

  # Before compile hook to define the CLI commands
  defmacro __before_compile__(env) do
    commands = Module.get_attribute(env.module, :cli_commands)

    quote do
      @doc false
      def __nexus_cli_commands__ do
        unquote(Macro.escape(commands))
      end

      # Expose display_help function
      def display_help(module, commands) do
        Nexus.CLI.__display_help__(commands)
      end
    end
  end
end
