defmodule TemperatureLoggerServer.Command do
  @temperature_logger_pid TemperatureLogger

  @doc ~S"""
  Parses the given `line` into a command

  ##Examples

      iex> TemperatureLoggerServer.Command.parse "ENUMERATE"
      {:ok, {:enumerate}}

      iex> TemperatureLoggerServer.Command.parse "START\r\n"
      {:ok, {:start}}

      iex> TemperatureLoggerServer.Command.parse "start\r\n"
      {:ok, {:start}}

      iex> TemperatureLoggerServer.Command.parse "start path/to/file\r\n"
      {:ok, {:start, "path/to/file"}}

      iex> TemperatureLoggerServer.Command.parse "STOP\r\n"
      {:ok, {:stop}}

      iex> TemperatureLoggerServer.Command.parse "UNKNOWN blah\r\n"
      {:error, :unknown_command}

  """
  def parse(line) do
    case String.split(line) |> List.update_at(0, &(String.downcase(&1))) do
      ["enumerate"] ->
        {:ok, {:enumerate}}
      ["start", log_path] ->
        {:ok, {:start, log_path}}
      ["start"] ->
        {:ok, {:start}}
      ["stop"] ->
        {:ok, {:stop}}
      [] ->
        {:noop}
      _ ->
        {:error, :unknown_command}
    end
  end

  @doc """
  Runs the given command
  """
  def run(command)

  def run({:enumerate}) do
    {:ok, ports} = TemperatureLogger.enumerate(@temperature_logger_pid)
    {:ok, inspect(ports) <> "\r\n"}
  end

  def run({:start, log_path}) do
    case TemperatureLogger.start_logging(@temperature_logger_pid, log_path: log_path) do
      :ok -> {:ok, "OK\r\n"}
      {:error, err} -> {:error, err}
    end
  end

  def run({:start}) do
    case TemperatureLogger.start_logging(@temperature_logger_pid) do
      :ok -> {:ok, "OK\r\n"}
      {:error, err} -> {:error, err}
    end
  end

  def run({:stop}) do
    case TemperatureLogger.stop_logging(@temperature_logger_pid) do
      :ok -> {:ok, "OK\r\n"}
      {:error, err} -> {:error, err}
    end
  end
end
