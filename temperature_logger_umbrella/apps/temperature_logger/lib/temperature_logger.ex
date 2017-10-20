defmodule TemperatureLogger do
  use GenServer

  require Logger

  alias Nerves.UART

  @uart_pid UART
  @default_log_path Path.join([".", "log", "temperature_logger.log"])
  # 10 seconds
  @default_sample_rate 10
  # Texas Instruments
  @vendor_id 1105
  # MSP430G2 Rev.1.4
  @product_id 62514
  @baud 9600
  # 5 seconds
  @period 5
  @on "O"
  @off "F"
  @debug false
  @open_options [
    speed: @baud,
    active: true,
    framing: {UART.Framing.Line, separator: "\n"}
  ]

  ## Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def enumerate(server) do
    GenServer.call(server, {:enumerate})
  end

  def start_logging(server, opts \\ []) do
    GenServer.call(server, {:start_logging, opts})
  end

  def stop_logging(server, opts \\ []) do
    GenServer.call(server, {:stop_logging, opts})
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

  def handle_call({:start_logging, opts}, _from, state) do
    port = Keyword.get(opts, :port, default_port())
    log_path = Keyword.get(opts, :log_path, @default_log_path) |> Path.expand()
    sample_rate = Keyword.get(opts, :sample_rate, @default_sample_rate)

    if Map.has_key?(state, port) do
      {:reply, {:error, :eagain}, state}
    else
      msg =
        with :ok <- UART.open(uart_pid(), port, @open_options),
             :ok <- UART.flush(uart_pid()),
             :ok <- UART.write(uart_pid(), @on),
             :ok <- UART.drain(uart_pid()),
             do: add_backend(log_path)

      case msg do
        :ok ->
          {:ok, upper_limit} = calculate_upper_limit(sample_rate)
          settings = %{
            log_path: log_path,
            sample_rate: sample_rate,
            lower_limit: 0,
            upper_limit: upper_limit,
            counter: 0,
            direction: -1
          }

          new_state = Map.put(state, port, settings)
          {:reply, msg, new_state}

        _ ->
          {:reply, msg, state}
      end
    end
  end

  def handle_call({:stop_logging, opts}, _from, state) do
    port = Keyword.get(opts, :port, default_port())

    if Map.has_key?(state, port) do
      msg =
        with :ok <- UART.write(uart_pid(), @off),
             :ok <- UART.drain(uart_pid()),
             :ok <- UART.close(uart_pid()),
             do: remove_backend(Map.get(state, port).log_path)

      case msg do
        :ok ->
          new_state = Map.delete(state, port)
          {:reply, msg, new_state}

        _ ->
          {:reply, msg, state}
      end
    else
      {:reply, {:error, :ebadf}, state}
    end
  end

  def handle_info({:nerves_uart, _port, {:error, error}}, state) do
    if @debug do
      IO.warn("Received error message from :nerves_uart: '#{error}'")
    end

    {:noreply, state}
  end

  def handle_info({:nerves_uart, port, message}, state) when !Map.has_key?(state, port) do
    {:noreply, state}
  end

  def handle_info({:nerves_uart, port, message}, state) when Map.has_key?(state, port) do
    settings = Map.get(state, port)
    %{counter: counter, upper_limit: upper_limit} = settings

    if counter == upper_limit do
      Logger.info(message)

      new_direction = -1 * direction
      new_counter = counter + new_direction
      new_settings = %{settings | direction: new_direction, counter: new_counter}
      new_state = Map.put(state, port, new_settings)
      {:noreply, new_state}
    else
      new_counter = counter + direction
      new_settings = %{settings | counter: new_counter}
      new_state = Map.put(state, port, new_settings)
      {:noreply, new_state}
    end
  end

  def handle_info(msg, state) do
    IO.puts("Received message: #{inspect(msg)}")
    {:noreply, state}
  end

  defp uart_pid do
    @uart_pid
  end

  defp default_port do
    results =
      UART.enumerate()
      |> Enum.find(fn {_k, v} ->
           Map.get(v, :vendor_id) == @vendor_id && Map.get(v, :product_id) == @product_id
         end)

    case results do
      {path, _details} -> path
      nil -> nil
    end
  end

  defp add_backend(path) do
    Logger.add_backend({LoggerFileBackend, path})

    Logger.configure_backend(
      {LoggerFileBackend, path},
      path: path,
      level: :info,
      metadata_filter: [application: :temperature_logger]
    )
  end

  defp remove_backend(path) do
    Logger.remove_backend({LoggerFileBackend, path})
  end

  defp calculate_upper_limit(sample_rate) when sample_rate < @period do
    {:error, :sample_rate_less_than_period}
  end

  defp calculate_upper_limit(sample_rate) when rem(sample_rate, @period) != 0 do
    {:error, :sample_rate_not_multiple_of_period}
  end

  defp calculate_upper_limit(sample_rate) do
    upper_limit = div(sample_rate, @period)
    {:ok, upper_limit}
  end
end
