defmodule TemperatureLogger do
  @moduledoc """
  Client/Server implementation that allows the client to log temperature via
  temperature-sensing hardware. The client can customize...
  * the UART port.
  * the frequency of readings.
  * the destination log file.

  Additionally, the client can enumerate the UART ports available.

  **Note:** Temperature readings are in degrees Celsius.
  """

  use GenServer

  require Logger

  alias Nerves.UART
  alias Poison.Parser
  alias TemperatureLogger.Settings
  alias TemperatureLogger.LoggerManager

  @uart_pid UART

  @on "O"

  @off "F"

  @uart_open_options [
    speed: 9600,
    active: true,
    framing: {UART.Framing.Line, separator: "\n"}
  ]

  ## Client API

  @spec start_link(keyword()) :: {:ok, pid()} | {:error, term()}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  @spec enumerate(pid()) :: map()
  def enumerate(server) do
    GenServer.call(server, {:enumerate})
  end

  @spec start_logging(pid(), keyword()) :: :ok | {:error, term()}
  def start_logging(server, opts \\ []) do
    GenServer.call(server, {:start_logging, opts})
  end

  @spec stop_logging(pid(), keyword()) :: :ok | {:error, term()}
  def stop_logging(server, opts \\ []) do
    GenServer.call(server, {:stop_logging, opts})
  end

  ## Server Callbacks

  def init(:ok) do
    {:ok, _pid} = UART.start_link(name: uart_pid())
    state = %{}
    {:ok, state}
  end

  def handle_call({:enumerate}, _from, state) do
    ports = UART.enumerate()
    {:reply, {:ok, ports}, state}
  end

  def handle_call({:start_logging, opts}, _from, state) do
    port = Keyword.get(opts, :port, Settings.default_port)

    if Map.has_key?(state, port) do
      {:reply, {:error, :eagain}, state}
    else
      log_path = Path.expand(Keyword.get(opts, :log_path, Settings.default_log_path))
      period = Keyword.get(opts, :period, Settings.default_period)

      case set_up(port, log_path, period) do
        {:ok, settings} ->
          new_state = Map.put(state, port, settings)
          {:reply, :ok, new_state}

        {:error, error} ->
          {:reply, {:error, error}, state}
      end
    end
  end

  def handle_call({:stop_logging, opts}, _from, state) do
    port = Keyword.get(opts, :port, Settings.default_port)

    if Map.has_key?(state, port) do
      case teardown(Map.get(state, port)) do
        :ok ->
          new_state = Map.delete(state, port)
          {:reply, :ok, new_state}

        {:error, error} ->
          {:reply, {:error, error}, state}
      end
    else
      {:reply, {:error, :ebadf}, state}
    end
  end

  def handle_info({:nerves_uart, port, {:error, :einval}}, state) do
    if Map.has_key?(state, port) do
      LoggerManager.remove_backend(Map.get(state, port).log_path)
      new_state = Map.delete(state, port)
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  def handle_info({:nerves_uart, _port, {:error, _err}}, state) do
    {:noreply, state}
  end

  def handle_info({:nerves_uart, port, message}, state) do
    if Map.has_key?(state, port) do
      {point_type, new_settings} = Settings.next(Map.get(state, port))

      if point_type == :crest or point_type == :trough do
        with {:ok, data} <- Parser.parse(String.trim(message)),
              do: Logger.info(Map.get(data, "celsius"))
      end

      new_state = Map.put(state, port, new_settings)
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  def handle_info(msg, state) do
    IO.puts("Received message: #{inspect(msg)}")
    {:noreply, state}
  end

  defp uart_pid do
    @uart_pid
  end

  defp set_up(port, log_path, period) do
    with {:ok, settings} <- Settings.generate(log_path, period),
         :ok <- UART.open(uart_pid(), port, @uart_open_options),
         :ok <- UART.flush(uart_pid()),
         :ok <- UART.write(uart_pid(), @on),
         :ok <- UART.drain(uart_pid()),
         :ok <- LoggerManager.add_backend(log_path),
         do: {:ok, settings}
  end

  defp teardown(settings) do
    with :ok <- UART.write(uart_pid(), @off),
         :ok <- UART.drain(uart_pid()),
         :ok <- UART.close(uart_pid()),
         do: LoggerManager.remove_backend(settings.log_path)
  end
end
