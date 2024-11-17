defmodule MyCLI do
  @moduledoc """
  MyCLI provides file operations such as copy, move, and delete using the Nexus.CLI DSL.
  """

  use Nexus.CLI, otp_app: :nexus_cli

  defcommand :version do
    description "Shows the version of the CLI"
  end

  defcommand :folder do
    description "Performs folder operations like merging"

    subcommand :merge do
      description "Merges two or more directories"

      value {:list, :string}, required: true, as: :targets

      flag :level do
        description "The level of the folder that will be merged"
        value :integer, required: false
        short :l
      end

      flag :recursive do
        description "IF the merge should operate recursively"
        value :boolean, required: false, default: false
        short :rc
      end
    end
  end

  defcommand :file do
    description "Performs file operations such as copy, move, and delete."

    subcommand :copy do
      description "Copies files from source to destination."

      value :string, required: true, as: :source
      value :string, required: true, as: :dest

      flag :level do
        value :integer, required: false
      end

      flag :verbose do
        short :v
        description "Enables verbose output."
      end

      flag :recursive do
        short :rc
        description "Copies directories recursively."
      end
    end

    subcommand :move do
      description "Moves files from source to destination."

      value :string, required: true, as: :source
      value :string, required: true, as: :dest

      flag :force do
        short :f
        description "Forces the move without confirmation."
      end

      flag :verbose do
        short :v
        description "Enables verbose output."
      end
    end

    subcommand :delete do
      description "Deletes specified files or directories."

      value {:list, :string}, required: true, as: :targets

      flag :force do
        short :f
        description "Forces deletion without confirmation."
      end

      flag :recursive do
        short :rc
        description "Deletes directories recursively."
      end

      flag :verbose do
        short :v
        description "Enables verbose output."
      end
    end
  end

  @impl Nexus.CLI
  def handle_input(:version, _) do
    # `version/0` comes from Nexus.CLI or the callback this module defined
    vsn = version()
    IO.puts(vsn)
  end

  def handle_input([:folder, :merge], %{args: args, flags: flags}) do
    if flags.recursive do
      IO.puts("Recursive merging enabled")
    end

    if level = flags.level do
      IO.puts("Set level of merging to #{level}")
    end

    Enum.each(args.targets, fn target ->
      IO.puts("Merged #{target}")
    end)

    :ok
  end

  def handle_input([:file, :copy], %{args: args, flags: flags}) do
    if flags.verbose do
      IO.puts("Copying from #{args.source} to #{args.dest}")
    end

    if flags.recursive do
      IO.puts("Recursive copy enabled")
    end

    # Implement actual copy logic here
    IO.puts("Copied #{args.source} to #{args.dest}")
    :ok
  end

  def handle_input([:file, :move], %{args: args, flags: flags}) do
    if flags.verbose do
      IO.puts("Moving from #{args.source} to #{args.dest}")
    end

    if flags.force do
      IO.puts("Force move enabled")
    end

    # Implement actual move logic here
    IO.puts("Moved #{args.source} to #{args.dest}")
    :ok
  end

  def handle_input([:file, :delete], %{args: args, flags: flags}) do
    if flags.verbose do
      IO.puts("Deleting targets: #{Enum.join(args.targets, ", ")}")
    end

    if flags.recursive do
      IO.puts("Recursive delete enabled")
    end

    if flags.force do
      IO.puts("Force delete enabled")
    end

    # Implement actual delete logic here
    Enum.each(args.targets, fn target ->
      IO.puts("Deleted #{target}")
    end)

    :ok
  end
end
