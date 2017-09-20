defmodule TemperatureLoggerServer.Command do
  @doc ~S"""
  Parses the given `line` into a command

  ##Examples

      iex> TemperatureLoggerServer.Command.parse "ENUMERATE"
      {:ok, {:enumerate}}

      iex> TemperatureLoggerServer.Command.parse "OPEN path/to/device 9600\r\n"
      {:ok, {:open, "path/to/device", 9600}}

      iex> TemperatureLoggerServer.Command.parse "OPEN path/to/device\r\n"
      {:ok, {:open, "path/to/device", 9600}}

      iex> TemperatureLoggerServer.Command.parse "CLOSE\r\n"
      {:ok, {:close}}

      iex> TemperatureLoggerServer.Command.parse "START\r\n"
      {:ok, {:start}}

      iex> TemperatureLoggerServer.Command.parse "STOP\r\n"
      {:ok, {:stop}}

      iex> TemperatureLoggerServer.Command.parse "UNKNOWN blah\r\n"
      {:error, :unknown_command}

  """
  def parse(line) do
    case String.split(line) |> List.update_at(0, &(String.upcase(&1))) do
      ["ENUMERATE"] -> {:ok, {:enumerate}}
      ["OPEN", path, baud] -> {:ok, {:open, path, String.to_integer(baud)}}
      ["OPEN", path] -> {:ok, {:open, path, 9600}}
      ["CLOSE"] -> {:ok, {:close}}
      ["START"] -> {:ok, {:start}}
      ["STOP"] -> {:ok, {:stop}}
      [] -> {:noop}
      _ -> {:error, :unknown_command}
    end
  end

  @doc """
  Runs the given command
  """
  def run(command)

  def run({:enumerate}) do
    {:ok, ports} = TemperatureLogger.Listener.enumerate(listener_pid())
    {:ok, inspect(ports) <> "\r\n"}
  end

  def run({:open, path, baud}) do
    case TemperatureLogger.Listener.open(listener_pid(), path, baud) do
      :ok -> {:ok, "OK\r\n"}
      {:error, err} -> {:error, err}
    end
  end

  def run({:close}) do
    case TemperatureLogger.Listener.close(listener_pid()) do
      :ok -> {:ok, "OK\r\n"}
      {:error, err} -> {:error, err}
    end
  end

  def run({:start}) do
    case TemperatureLogger.Listener.start(listener_pid()) do
      :ok -> {:ok, "OK\r\n"}
      :closed -> {:error, :port_closed}
    end
  end

  def run({:stop}) do
    case TemperatureLogger.Listener.stop(listener_pid()) do
      :ok -> {:ok, "OK\r\n"}
      :closed -> {:error, :port_closed}
    end
  end

  defp listener_pid do
    TemperatureLogger.Listener
  end
end
