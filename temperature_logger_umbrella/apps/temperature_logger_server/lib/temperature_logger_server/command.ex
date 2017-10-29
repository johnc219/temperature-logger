defmodule TemperatureLoggerServer.Command do
  @temperature_logger_pid TemperatureLogger

  @doc ~S"""
  Parses the given `line` into a command

  ##Examples

      iex> TemperatureLoggerServer.Command.parse "ENUMERATE\r\n"
      {:ok, {:enumerate}}

      iex> TemperatureLoggerServer.Command.parse "START\r\n"
      {:ok, {:start, []}}

      iex> TemperatureLoggerServer.Command.parse "start\r\n"
      {:ok, {:start, []}}

      iex> TemperatureLoggerServer.Command.parse "start 20\r\n"
      {:ok, {:start, [period: 20]}}

      iex> TemperatureLoggerServer.Command.parse "start 10 path/to/file\r\n"
      {:ok, {:start, [period: 10, log_path: "path/to/file"]}}

      iex> TemperatureLoggerServer.Command.parse "start 10 'path/to/file'\r\n"
      {:ok, {:start, [period: 10, log_path: "path/to/file"]}}

      iex> TemperatureLoggerServer.Command.parse "start 10 \"path/to/file\"\r\n"
      {:ok, {:start, [period: 10, log_path: "path/to/file"]}}

      iex> TemperatureLoggerServer.Command.parse "STOP\r\n"
      {:ok, {:stop}}

      iex> TemperatureLoggerServer.Command.parse "UNKNOWN blah\r\n"
      {:error, :unknown_command}

  """
  def parse(line) do
    case String.split(line) |> List.update_at(0, &String.downcase(&1)) do
      ["enumerate"] ->
        {:ok, {:enumerate}}

      ["start", period, log_path] ->
        log_path =
          log_path
          |> String.trim("\"")
          |> String.trim("'")

        try do
          {:ok, {:start, [period: String.to_integer(period), log_path: log_path]}}
        rescue
          ArgumentError -> {:error, :period_must_be_integer}
        end

      ["start", period] ->
        try do
          {:ok, {:start, [period: String.to_integer(period)]}}
        rescue
          ArgumentError -> {:error, :period_must_be_integer}
        end

      ["start"] ->
        {:ok, {:start, []}}

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

    formatted =
      Enum.map_join(ports, "\r\n", fn {port, metadata} ->
        inspect(port) <> " => " <> inspect(metadata)
      end)

    {:ok, formatted <> "\r\n"}
  end

  def run({:start, opts}) do
    case TemperatureLogger.start_logging(@temperature_logger_pid, opts) do
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
