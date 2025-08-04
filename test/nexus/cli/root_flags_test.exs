defmodule Nexus.CLI.RootFlagsTest do
  use ExUnit.Case, async: true

  alias Nexus.CLI.Input
  alias Nexus.Parser

  defmodule TestCLIWithRootFlags do
    @moduledoc false
    use Nexus.CLI, otp_app: :nexus_cli, name: "my_cli"

    flag :version do
      short :v
      description "Shows the version of the program"
    end

    flag :debug do
      short :d
      description "Enable debug mode"
    end

    defcommand :test_cmd do
      description "Test command"
    end

    @impl Nexus.CLI
    def handle_input(:version, %Input{flags: %{version: true}}) do
      {:ok, "Version: #{version()}"}
    end

    @impl Nexus.CLI
    def handle_input(:debug, %Input{flags: %{debug: true}}) do
      {:ok, "Debug mode enabled"}
    end

    @impl Nexus.CLI
    def handle_input(:test_cmd, %Input{}) do
      {:ok, "Test command executed"}
    end
  end

  describe "root-level flags" do
    test "root flags are included in CLI spec" do
      spec = TestCLIWithRootFlags.__nexus_spec__()

      # Root flags should be stored in the CLI struct
      assert is_list(spec.root_flags)
      assert length(spec.root_flags) == 2

      version_flag = Enum.find(spec.root_flags, &(&1.name == :version))
      assert version_flag.short == :v
      assert version_flag.description == "Shows the version of the program"

      debug_flag = Enum.find(spec.root_flags, &(&1.name == :debug))
      assert debug_flag.short == :d
      assert debug_flag.description == "Enable debug mode"
    end

    test "parsing root flags without commands" do
      cli = TestCLIWithRootFlags.__nexus_spec__()

      {:ok, result} = Parser.parse_ast(cli, ["my_cli", "--version"])

      assert result.flags.version == true
      assert result.command == []
    end

    test "parsing short root flags" do
      cli = TestCLIWithRootFlags.__nexus_spec__()

      {:ok, result} = Parser.parse_ast(cli, ["my_cli", "-v"])

      assert result.flags.version == true
      assert result.command == []
    end

    test "root flags work alongside commands" do
      cli = TestCLIWithRootFlags.__nexus_spec__()

      {:ok, result} = Parser.parse_ast(cli, ["test_cmd", "--debug"])

      assert result.flags.debug == true
      assert result.command == [:test_cmd]
    end

    test "dispatching root flags calls correct handler" do
      alias Nexus.CLI.Dispatcher

      cli = TestCLIWithRootFlags.__nexus_spec__()

      result = %{
        command: [],
        flags: %{version: true},
        args: %{}
      }

      assert {:ok, "Version: " <> _} = Dispatcher.dispatch(cli, result)
    end
  end
end
