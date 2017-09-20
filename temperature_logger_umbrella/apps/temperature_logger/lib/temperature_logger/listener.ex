defmodule TemperatureLogger.Listener do
  use GenServer

  alias Nerves.UART
  alias TemperatureLogger.Writer

  @uart_pid UART
  @on "O"
  @off "F"

  ## Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def enumerate(server) do
    GenServer.call(server, {:enumerate})
  end

  def open(server, port, baud \\ 9600) do
    GenServer.call(server, {:open, port, baud})
  end

  def close(server) do
    GenServer.call(server, {:close})
  end

  def start(server) do
    GenServer.call(server, {:start})
  end

  def stop(server) do
    GenServer.call(server, {:stop})
  end

  ## Server Callbacks

  def init(:ok) do
    {:ok, _pid} = UART.start_link(name: @uart_pid)
    state = {:closed}
    {:ok, state}
  end

  def handle_call({:enumerate}, _from, state) do
    ports = UART.enumerate()
    {:reply, {:ok, ports}, state}
  end

  def handle_call({:open, port, baud}, _from, state) do
    :ok = Writer.open(writer_server())
    msg = UART.open(uart_pid(),
                    port,
                    speed: baud,
                    active: true,
                    framing: UART.Framing.Line, separator: "\n")

    case msg do
      :ok -> {:reply, :ok, {:opened, port}}
      {:error, err} -> {:reply, {:error, err}, state}
    end
  end

  def handle_call({:close}, _from, _state) do
    :ok = UART.close(uart_pid())
    :ok = Writer.close(writer_server())

    state = {:closed}
    {:reply, :ok, state}
  end

  def handle_call({:start}, _from, {:opened, _port} = state) do
    # Flush rx/tx buffers
    :ok = UART.flush(uart_pid())
    :ok = UART.write(uart_pid(), @on)

    {:reply, :ok, state}
  end

  def handle_call({:start}, _from, {:closed} = state) do
    {:reply, :closed, state}
  end

  def handle_call({:stop}, _from, {:opened, _port} = state) do
    :ok = UART.write(uart_pid(), @off)
    {:reply, :ok, state}
  end

  def handle_call({:stop}, _from, {:closed} = state) do
    {:reply, :closed, state}
  end

  def handle_info({:nerves_uart, _port, {:error, error}}, state) do
    IO.warn "Received error message from :nerves_uart: '#{error}'"
    {:noreply, state}
  end

  def handle_info({:nerves_uart, port, message}, {:opened, port} = state) do
    log(message)
    {:noreply, state}
  end

  def handle_info(msg, state) do
    IO.puts "Received message: #{inspect msg}"
    {:noreply, state}
  end

  defp log(message) do
    {timestamp, 0} = System.cmd("date", ["+%T"])
    message = Enum.join([String.trim_trailing(timestamp), message], ", ")

    Writer.puts(writer_server(), message)
  end

  defp uart_pid do
    @uart_pid
  end

  defp writer_server do
    Writer
  end
end
