defmodule NexusTest do
  use ExUnit.Case, async: true

  import Nexus

  setup do
    start_supervised!({Nexus.RuntimeStorage, :nexus_test_storage})
    :ok
  end

  describe "defcommand/2" do
    test "defining a command should insert it into ETS" do
      defcommand(:hello, required: false, type: :atom)
      assert Nexus.RuntimeStorage.read(:hello)
    end

    test "defining multiple command should insert all into ETS" do
      defcommand(:foo, required: false, type: :string)
      defcommand(:bar, [])
      assert length(Nexus.fetch_cli_commands(__MODULE__)) == 2
    end
  end

  describe "fetch_cli_commands/1" do
    test "when there's no command for supplied module" do
      assert Enum.empty?(Nexus.fetch_cli_commands(DoNotExist))
    end

    test "when module exists but do not define any command" do
      assert Enum.empty?(Nexus.fetch_cli_commands(Nexus))
    end

    test "when module exists and define some command" do
      defcommand(:teste, type: :string, required: false)
      assert length(Nexus.fetch_cli_commands(__MODULE__)) == 1
    end
  end
end
