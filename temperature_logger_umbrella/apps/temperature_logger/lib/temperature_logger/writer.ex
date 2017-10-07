defmodule TemperatureLogger.Writer do
  use GenServer

  @dir_path Path.join([".", "logs"])

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def open(server) do
    GenServer.call(server, {:open})
  end

  def close(server) do
    GenServer.call(server, {:close})
  end

  def puts(server, message) do
    GenServer.call(server, {:puts, message})
  end

  ## Server callbacks

  def init(:ok) do
    File.mkdir_p!(@dir_path)

    state = {:closed}
    {:ok, state}
  end

  def handle_call({:open}, _from, {:closed}) do
    {date, 0} = System.cmd("date", ["+%F"])
    file_name = String.trim_trailing(date) <> ".txt"
    file_path = Path.join([@dir_path, file_name])
    file = File.open! file_path, [:append, :utf8]

    state = {:opened, file}
    {:reply, :ok, state}
  end

  def handle_call({:open}, _from, {:opened, _file} = state) do
    {:reply, :ok, state}
  end

  def handle_call({:close}, _from, {:opened, file}) do
    :ok = File.close file

    state = {:closed}
    {:reply, :ok, state}
  end

  def handle_call({:close}, _from, {:closed} = state) do
    {:reply, :ok, state}
  end

  def handle_call({:puts, message}, _from, {:opened, file} = state) do
    :ok = IO.puts(file, message)
    {:reply, :ok, state}
  end

  def handle_call({:puts, _message}, _from, {:closed} = state) do
    {:reply, :file_not_opened, state}
  end
end
