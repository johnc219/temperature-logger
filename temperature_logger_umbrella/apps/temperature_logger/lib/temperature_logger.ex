defmodule TemperatureLogger do
  use GenServer

  alias Nerves.UART
  alias TemperatureLogger.Writer

  @uart_pid UART
  @product_id 62514
  @baud 9600
  @on "O"
  @off "F"

  ## Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def enumerate(server) do
    GenServer.call(server, {:enumerate})
  end

  def start_logging(server) do
    GenServer.call(server, {:start_logging})
  end

  def stop_logging(server) do
    GenServer.call(server, {:stop_logging})
  end

  ## Server Callbacks

  def init(:ok) do
    {:ok, _pid} = UART.start_link(name: @uart_pid)
    state = %{}
    {:ok, state}
  end

  def handle_call({:enumerate}, _from, state) do
    ports = UART.enumerate()
    {:reply, {:ok, ports}, state}
  end

  def handle_call({:start_logging}, _from, state) do
    options = [
      speed: @baud,
      active: true,
      framing: {UART.Framing.Line, separator: "\n"}
    ]

    msg =
      with :ok <- UART.open(uart_pid(), find_port(), options),
           :ok <- UART.flush(uart_pid()),
           :ok <- UART.write(uart_pid(), @on),
           :ok <- UART.drain(uart_pid()),
           do: Writer.open(writer_server())

    {:reply, msg, state}
  end

  def handle_call({:stop_logging}, _from, state) do
    msg =
      with :ok <- Writer.close(writer_server()),
           :ok <- UART.write(uart_pid(), @off),
           :ok <- UART.drain(uart_pid()),
           do: UART.close(uart_pid())

    {:reply, msg, state}
  end

  def handle_info({:nerves_uart, _port, {:error, error}}, state) do
    IO.warn "Received error message from :nerves_uart: '#{error}'"
    {:noreply, state}
  end

  def handle_info({:nerves_uart, _port, message}, state) do
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

  defp find_port do
    results = UART.enumerate
      |> Enum.find(fn({_k, v}) -> Map.get(v, :product_id) == @product_id end)

    case results do
      {path, _details} -> path
      nil -> nil
    end
  end
end
