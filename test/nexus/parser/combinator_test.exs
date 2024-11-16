defmodule Nexus.Parser.CombinatorTest do
  use ExUnit.Case

  import Nexus.Parser.Combinator

  describe "literal/1" do
    test "matches exact string" do
      parser = literal("hello")
      assert parser.("hello world") == {:ok, {"hello", "world"}}
    end

    test "fails on non-matching string" do
      parser = literal("hello")
      assert parser.("goodbye") == {:error, {:expected, "hello"}}
    end

    test "handles empty input" do
      parser = literal("hello")
      assert parser.("") == {:error, {:expected, "hello"}}
    end
  end

  describe "regex/1" do
    test "matches pattern at start of input" do
      parser = regex(~r/\d+/)
      assert parser.("123 abc") == {:ok, {"123", "abc"}}
    end

    test "fails when pattern doesn't match" do
      parser = regex(~r/\d+/)
      assert parser.("abc") == {:error, {:doesnt_match_pattern, ~r/\A\d+/}}
    end

    test "matches only at beginning" do
      parser = regex(~r/\d+/)
      assert parser.("abc 123") == {:error, {:doesnt_match_pattern, ~r/\A\d+/}}
    end
  end

  describe "sequence/2" do
    test "combines two successful parsers" do
      parser = sequence([literal("hello"), literal("world")])
      assert parser.("helloworld") == {:ok, {["hello", "world"], ""}}
    end

    test "fails if first parser fails" do
      parser = sequence([literal("hello"), literal("world")])
      assert parser.("goodbyeworld") == {:error, {:expected, "hello"}}
    end

    test "fails if second parser fails" do
      parser = sequence([literal("hello"), literal("world")])
      assert parser.("hellogoodbye") == {:error, {:expected, "world"}}
    end

    test "handles whitespace between tokens" do
      parser = sequence([literal("hello"), literal("world")])
      assert parser.("hello world") == {:ok, {["hello", "world"], ""}}
    end
  end

  describe "choice/1" do
    test "tries parsers in order until success" do
      parser =
        choice([
          literal("hello"),
          literal("hi"),
          literal("hey")
        ])

      assert parser.("hello") == {:ok, {"hello", ""}}
      assert parser.("hi") == {:ok, {"hi", ""}}
      assert parser.("hey") == {:ok, {"hey", ""}}
    end

    test "fails if no parser succeeds" do
      parser =
        choice([
          literal("hello"),
          literal("hi"),
          literal("hey")
        ])

      assert parser.("goodbye") == {:error, {:expected, "hello"}}
    end

    test "stops at first success" do
      parser =
        choice([
          literal("hi"),
          literal("high")
        ])

      assert parser.("high") == {:ok, {"hi", "gh"}}
    end
  end

  describe "optional/1" do
    test "succeeds when parser succeeds" do
      parser = optional(literal("hello"))
      assert parser.("hello world") == {:ok, {"hello", "world"}}
    end

    test "succeeds with nil when parser fails" do
      parser = optional(literal("hello"))
      assert parser.("goodbye") == {:ok, {nil, "goodbye"}}
    end

    test "handles empty input" do
      parser = optional(literal("hello"))
      assert parser.("") == {:ok, {nil, ""}}
    end
  end

  describe "many/1" do
    test "matches one or more occurrences" do
      parser = many(literal("ha"))
      assert parser.("") == {:error, {:expected, "ha"}}
      assert parser.("ha") == {:ok, {["ha"], ""}}
      assert parser.("haha") == {:ok, {["ha", "ha"], ""}}
      assert parser.("hahaha") == {:ok, {["ha", "ha", "ha"], ""}}
    end

    test "consumes until failure" do
      parser = many(literal("ha"))
      assert parser.("hahaho") == {:ok, {["ha", "ha"], "ho"}}
    end

    test "works with regex parser" do
      parser = many(regex(~r/\d+/))
      assert parser.("123 456 789") == {:ok, {["123", "456", "789"], ""}}
    end
  end

  describe "map/2" do
    test "transforms successful result" do
      parser = literal("42") |> map(&String.to_integer/1)
      assert parser.("42") == {:ok, {42, ""}}
    end

    test "doesn't transform on failure" do
      parser = literal("42") |> map(&String.to_integer/1)
      assert parser.("24") == {:error, {:expected, "42"}}
    end

    test "can transform complex structures" do
      parser =
        sequence([literal("hello"), literal("42")])
        |> map(fn [greeting, num] -> {greeting, String.to_integer(num)} end)

      assert parser.("hello42") == {:ok, {{"hello", 42}, ""}}
    end
  end
end
