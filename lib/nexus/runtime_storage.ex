defmodule Nexus.RuntimeStorage do
  @moduledoc false

  use GenServer

  require Logger

  def start_link(table) when is_atom(table) do
    GenServer.start_link(__MODULE__, table, name: __MODULE__)
  end

  @spec insert(atom, term) :: :ok
  def insert(key, value) do
    GenServer.cast(__MODULE__, {:insert, key, value})
  end

  @spec read(atom) :: term | nil
  def read(key) do
    GenServer.call(__MODULE__, {:read, key})
  end

  @spec delete(atom) :: :ok
  def delete(key) do
    GenServer.cast(__MODULE__, {:delete, key})
  end

  @spec map(function) :: term
  def map(fun) do
    GenServer.call(__MODULE__, {:map, fun})
  end

  @spec filter(function) :: list(term)
  def filter(fun) do
    GenServer.call(__MODULE__, {:filter, fun})
  end

  @impl true
  def init(table) do
    :ets.new(table, [:set, :protected, :named_table])
    {:ok, table}
  end

  @impl true
  def handle_cast({:insert, key, value}, ref) do
    true = :ets.insert(ref, {key, value})
    {:noreply, ref}
  rescue
    _ ->
      Logger.error("Could not insert value #{inspect(value)} for key #{key}")
      {:noreply, ref}
  end

  @impl true
  def handle_cast({:delete, key}, ref) do
    true = :ets.delete(ref, key)
    {:noreply, ref}
  rescue
    _ ->
      Logger.error("Could not delete entry #{key}")
      {:noreply, ref}
  end

  @impl true
  def handle_call({:read, key}, _from, ref) do
    result = %{} = Map.new(:ets.lookup(ref, key))
    {:reply, Map.get(result, key), ref}
  rescue
    _ ->
      Logger.error("Could not read key #{key}")
      {:reply, nil, ref}
  end

  @impl true
  def handle_call({:map, fun}, _from, ref) do
    reduced = :ets.foldr(fn obj, acc -> [fun.(obj) | acc] end, [], ref)
    {:reply, reduced, ref}
  end

  @impl true
  def handle_call({:filter, fun}, _from, ref) do
    filter = fn obj, acc -> (fun.(obj) && [obj | acc]) || acc end
    reduced = :ets.foldr(filter, [], ref)

    {:reply, reduced, ref}
  end
end
