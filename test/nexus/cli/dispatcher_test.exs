defmodule Nexus.CLI.DispatcherTest do
  use ExUnit.Case, async: true

  alias Nexus.CLI
  alias Nexus.CLI.Dispatcher
  alias Nexus.CLI.Input

  defmodule TestHandler do
    @moduledoc false
    @behaviour CLI

    def description, do: "Test CLI handler"
    def version, do: "1.0.0"

    def handle_input(:success, %Input{flags: %{help: true}}) do
      :ok
    end

    def handle_input(:success, %Input{value: value, args: args}) when is_nil(args) or map_size(args) == 0 do
      {:ok, "Processed: #{value}"}
    end

    def handle_input(:success, %Input{args: args}) when map_size(args) > 0 do
      {:ok, "Args: #{inspect(args)}"}
    end

    def handle_input(:error, _input) do
      raise "Test error"
    end

    def handle_input(:function_clause_error, %Input{value: "specific"}) do
      :ok
    end

    def handle_input(:argument_error, _input) do
      raise ArgumentError, "Invalid argument"
    end
  end

  defmodule UndefinedHandler do
    # Missing handle_input implementation
    @moduledoc false
  end

  @cli %CLI{
    name: :test_cli,
    handler: TestHandler,
    description: "Test CLI description",
    spec: []
  }

  @undefined_cli %CLI{
    name: :test_cli,
    handler: UndefinedHandler,
    description: "Test CLI description",
    spec: []
  }

  describe "dispatch/2 with help flag" do
    test "displays help and returns :ok when help flag is true" do
      import ExUnit.CaptureIO

      result = %{
        command: [:test],
        flags: %{help: true},
        args: %{}
      }

      # Capture help output
      output =
        capture_io(fn ->
          assert :ok = Dispatcher.dispatch(@cli, result)
        end)

      # The help command will display "Command not found" since :test is not in spec
      # This is expected behavior for an undefined command
      assert output =~ "Command not found"
    end
  end

  describe "dispatch/2 with empty command" do
    test "redirects to help when command is empty" do
      import ExUnit.CaptureIO

      result = %{
        command: [],
        flags: %{verbose: true},
        args: %{}
      }

      output =
        capture_io(fn ->
          assert :ok = Dispatcher.dispatch(@cli, result)
        end)

      assert output =~ "test_cli"
    end
  end

  describe "dispatch/2 with single argument" do
    test "handles successful single value dispatch" do
      result = %{
        command: [:success],
        flags: %{verbose: true},
        args: %{file: "test.txt"}
      }

      assert {:ok, "Processed: test.txt"} = Dispatcher.dispatch(@cli, result)
    end

    test "handles successful single value dispatch with nil value" do
      result = %{
        command: [:success],
        flags: %{verbose: true},
        args: %{}
      }

      assert {:ok, "Processed: "} = Dispatcher.dispatch(@cli, result)
    end

    test "handles UndefinedFunctionError" do
      import ExUnit.CaptureLog

      result = %{
        command: [:missing],
        flags: %{},
        args: %{file: "test.txt"}
      }

      log =
        capture_log(fn ->
          assert {:error, {1, "Command 'missing' is not implemented"}} =
                   Dispatcher.dispatch(@undefined_cli, result)
        end)

      assert log =~ "CLI Handler Error"
      assert log =~ "Handler function not defined"
    end

    test "handles FunctionClauseError" do
      import ExUnit.CaptureLog

      result = %{
        command: [:function_clause_error],
        flags: %{},
        args: %{file: "wrong_value"}
      }

      log =
        capture_log(fn ->
          assert {:error, {1, "Invalid arguments for command 'function_clause_error'"}} =
                   Dispatcher.dispatch(@cli, result)
        end)

      assert log =~ "CLI Handler Error"
      assert log =~ "Invalid arguments for handler"
    end

    test "handles ArgumentError" do
      import ExUnit.CaptureLog

      result = %{
        command: [:argument_error],
        flags: %{},
        args: %{file: "test.txt"}
      }

      log =
        capture_log(fn ->
          assert {:error, {1, "Invalid argument: Invalid argument"}} =
                   Dispatcher.dispatch(@cli, result)
        end)

      assert log =~ "CLI Handler Error"
      assert log =~ "Invalid argument"
    end

    test "handles generic exceptions" do
      import ExUnit.CaptureLog

      result = %{
        command: [:error],
        flags: %{},
        args: %{file: "test.txt"}
      }

      log =
        capture_log(fn ->
          assert {:error, {1, "An error occurred while executing 'error'"}} =
                   Dispatcher.dispatch(@cli, result)
        end)

      assert log =~ "CLI Handler Error"
      assert log =~ "Unexpected error in handler"
    end
  end

  describe "dispatch/2 with multiple arguments" do
    test "handles successful multiple arguments dispatch" do
      result = %{
        command: [:success],
        flags: %{verbose: true},
        args: %{source: "file1.txt", dest: "file2.txt"}
      }

      assert {:ok, response} = Dispatcher.dispatch(@cli, result)
      assert String.contains?(response, "Args:")
      assert String.contains?(response, "source: \"file1.txt\"")
      assert String.contains?(response, "dest: \"file2.txt\"")
    end

    test "handles command path with multiple levels" do
      import ExUnit.CaptureLog

      result = %{
        command: [:file, :copy],
        flags: %{},
        args: %{source: "file1.txt", dest: "file2.txt"}
      }

      log =
        capture_log(fn ->
          # This will fail because TestHandler doesn't have handle_input for [:file, :copy]
          assert {:error, {1, "Command 'file copy' is not implemented"}} =
                   Dispatcher.dispatch(@undefined_cli, result)
        end)

      assert log =~ "CLI Handler Error"
    end

    test "handles exceptions in multiple args dispatch" do
      import ExUnit.CaptureLog

      result = %{
        command: [:error],
        flags: %{},
        args: %{source: "file1.txt", dest: "file2.txt"}
      }

      log =
        capture_log(fn ->
          assert {:error, {1, "An error occurred while executing 'error'"}} =
                   Dispatcher.dispatch(@cli, result)
        end)

      assert log =~ "CLI Handler Error"
      assert log =~ "Unexpected error in handler"
    end
  end

  describe "format_command/1" do
    test "formats single command" do
      import ExUnit.CaptureLog
      # This tests the private function indirectly through error messages
      result = %{
        command: [:test],
        flags: %{},
        args: %{file: "test.txt"}
      }

      capture_log(fn ->
        {:error, {1, message}} = Dispatcher.dispatch(@undefined_cli, result)
        assert message =~ "Command 'test' is not implemented"
      end)
    end

    test "formats multiple command path" do
      import ExUnit.CaptureLog

      result = %{
        command: [:file, :copy, :recursive],
        flags: %{},
        args: %{file: "test.txt"}
      }

      capture_log(fn ->
        {:error, {1, message}} = Dispatcher.dispatch(@undefined_cli, result)
        assert message =~ "Command 'file copy recursive' is not implemented"
      end)
    end
  end
end
