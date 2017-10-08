defmodule TemperatureLoggerServer.Command do
  @doc ~S"""
  Parses the given `line` into a command

  ##Examples

      iex> TemperatureLoggerServer.Command.parse "ENUMERATE"
      {:ok, {:enumerate}}

      iex> TemperatureLoggerServer.Command.parse "START\r\n"
      {:ok, {:start}}

      iex> TemperatureLoggerServer.Command.parse "start\r\n"
      {:ok, {:start}}

      iex> TemperatureLoggerServer.Command.parse "STOP\r\n"
      {:ok, {:stop}}

      iex> TemperatureLoggerServer.Command.parse "UNKNOWN blah\r\n"
      {:error, :unknown_command}

  """
  def parse(line) do
    case String.split(line) |> List.update_at(0, &(String.downcase(&1))) do
      ["enumerate"] ->
        {:ok, {:enumerate}}
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
    {:ok, ports} = TemperatureLogger.Listener.enumerate(listener_pid())
    {:ok, inspect(ports) <> "\r\n"}
  end

  def run({:start}) do
    case TemperatureLogger.Listener.start_logging(listener_pid()) do
      :ok -> {:ok, "OK\r\n"}
      {:error, err} -> {:error, err}
    end
  end

  def run({:stop}) do
    case TemperatureLogger.Listener.stop_logging(listener_pid()) do
      :ok -> {:ok, "OK\r\n"}
      {:error, err} -> {:error, err}
    end
  end

  defp listener_pid do
    TemperatureLogger.Listener
  end
end
