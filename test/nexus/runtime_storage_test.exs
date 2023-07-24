defmodule Nexus.RuntimeStorageTest do
  use ExUnit.Case, async: true

  setup do
    start_supervised!({Nexus.RuntimeStorage, :nexus_test_storage})
    :ok
  end

  describe "read/1" do
    test "reading a non existing value should return nil" do
      refute Nexus.RuntimeStorage.read(:do_not_exists)
    end

    test "reading an existing value should return it" do
      assert :ets.insert(:nexus_test_storage, {:teste, true})
      assert Nexus.RuntimeStorage.read(:teste)
    end
  end

  describe "insert/2" do
    test "inserting a value should persist it into ETS" do
      assert :ok = Nexus.RuntimeStorage.insert(:teste, true)
      assert Nexus.RuntimeStorage.read(:teste)
    end
  end
end
