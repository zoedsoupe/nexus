defmodule Nexus.Parser.DSLTest do
  use ExUnit.Case

  import Nexus.Parser.DSL

  describe "integer/0" do
    test "parses positive integers" do
      parser = integer()
      assert parser.("42 remaining") == {:ok, {42, "remaining"}}
    end

    test "parses negative integers" do
      parser = integer()
      assert parser.("-42 remaining") == {:ok, {-42, "remaining"}}
    end

    test "fails on invalid integers" do
      parser = integer()
      assert parser.("abc") == {:error, {:doesnt_match_pattern, ~r/^-?\d+/}}
    end

    test "fails on floats" do
      parser = integer()
      assert parser.("42.5") == {:ok, {42, ".5"}}
    end
  end

  describe "float/0" do
    test "parses positive floats" do
      parser = float()
      assert parser.("42.5 remaining") == {:ok, {42.5, "remaining"}}
    end

    test "parses negative floats" do
      parser = float()
      assert parser.("-42.5 remaining") == {:ok, {-42.5, "remaining"}}
    end

    test "fails on integers" do
      parser = float()
      assert parser.("42") == {:error, {:doesnt_match_pattern, ~r/^-?\d+\.\d+/}}
    end
  end

  describe "boolean/0" do
    test "parses true" do
      parser = boolean()
      assert parser.("true") == {:ok, {true, ""}}
    end

    test "parses false" do
      parser = boolean()
      assert parser.("false") == {:ok, {false, ""}}
    end

    test "fails on invalid boolean" do
      parser = boolean()
      assert parser.("yes") == {:error, {:expected, "true"}}
    end
  end

  describe "string/0" do
    test "parses until whitespace" do
      parser = string()
      assert parser.("hello world") == {:ok, {"hello", "world"}}
    end

    test "parses entire string when no whitespace" do
      parser = string()
      assert parser.("hello") == {:ok, {"hello", ""}}
    end

    test "handles special characters" do
      parser = string()
      assert parser.("hello-world!") == {:ok, {"hello-world!", ""}}
    end

    test "handle quoted strings" do
      parser = string()
      assert parser.(~s|"hello missy"|) == {:ok, {"hello missy", ""}}

      # single quotes too
      assert parser.(~s|'hello missy'|) == {:ok, {"hello missy", ""}}

      # nested quotations too
      assert parser.(~s|"hello missy 'missy'"|) == {:ok, {"hello missy 'missy'", ""}}
    end
  end

  describe "enum/1" do
    test "matches one of given values" do
      parser = enum(["one", "two", "three"])
      assert parser.("one") == {:ok, {"one", ""}}
      assert parser.("two") == {:ok, {"two", ""}}
      assert parser.("three") == {:ok, {"three", ""}}
    end

    test "fails on non-matching value" do
      parser = enum(["one", "two", "three"])
      assert parser.("four") == {:error, {:expected, "one"}}
    end
  end
end
