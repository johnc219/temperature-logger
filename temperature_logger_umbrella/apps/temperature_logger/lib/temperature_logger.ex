defmodule TemperatureLogger do
  use GenServer

  require Logger

  alias Nerves.UART

  @uart_pid UART

  @default_log_path Path.join([".", "log", "temperature_logger.log"])

  # 10 seconds
  @default_period 10

  # Texas Instruments
  @vendor_id 1105

  # MSP430G2 Rev.1.4
  @product_id 62514

  @baud 9600

  # 1 seconds
  @min_period 1

  @on "O"

  @off "F"

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
    {:ok, _pid} = UART.start_link(name: uart_pid())
    state = %{}
    {:ok, state}
  end

  def handle_call({:enumerate}, _from, state) do
    ports = UART.enumerate()
    {:reply, {:ok, ports}, state}
  end

  def handle_call({:start_logging, opts}, _from, state) do
    port = Keyword.get(opts, :port, default_port())

    if Map.has_key?(state, port) do
      {:reply, {:error, :eagain}, state}
    else
      log_path = Path.expand(Keyword.get(opts, :log_path, @default_log_path))
      period = Keyword.get(opts, :period, @default_period)

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
    port = Keyword.get(opts, :port, default_port())

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
      remove_backend(Map.get(state, port).log_path)
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
      {point_type, new_settings} = next_settings(Map.get(state, port))

      if point_type == :crest or point_type == :trough do
        Logger.info(message)
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

  defp default_port do
    ports = UART.enumerate()

    results =
      Enum.find(ports, fn {_k, v} ->
        vendor_id = Map.get(v, :vendor_id)
        product_id = Map.get(v, :product_id)

        vendor_id == @vendor_id and product_id == @product_id
      end)

    case results do
      {path, _details} -> path
      nil -> nil
    end
  end

  defp set_up(port, log_path, period) do
    with {:ok, settings} <- generate_settings(log_path, period),
         :ok <- UART.open(uart_pid(), port, @open_options),
         :ok <- UART.flush(uart_pid()),
         :ok <- UART.write(uart_pid(), @on),
         :ok <- UART.drain(uart_pid()),
         :ok <- add_backend(log_path),
         do: {:ok, settings}
  end

  defp teardown(settings) do
    with :ok <- UART.write(uart_pid(), @off),
         :ok <- UART.drain(uart_pid()),
         :ok <- UART.close(uart_pid()),
         do: remove_backend(settings.log_path)
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

  defp generate_settings(log_path, period) do
    case calculate_upper_limit(period) do
      {:ok, upper_limit} ->
        settings = %{
          log_path: log_path,
          period: period,
          lower_limit: 0,
          upper_limit: upper_limit,
          count: 0,
          direction: -1
        }

        {:ok, settings}

      {:error, error} ->
        {:error, error}
    end
  end

  defp calculate_upper_limit(period) when period < @min_period do
    {:error, :period_less_than_min_period}
  end

  defp calculate_upper_limit(period) when rem(period, @min_period) != 0 do
    {:error, :period_not_multiple_of_min_period}
  end

  defp calculate_upper_limit(period) do
    upper_limit = div(period, @min_period)
    {:ok, upper_limit}
  end

  defp next_settings(settings) do
    %{
      count: count,
      upper_limit: upper_limit,
      lower_limit: lower_limit
    } = settings

    case count do
      ^upper_limit ->
        {:crest, next_settings(settings, :inflection_point)}

      ^lower_limit ->
        {:trough, next_settings(settings, :inflection_point)}

      _ ->
        {:regular, next_settings(settings, :regular)}
    end
  end

  defp next_settings(settings, :inflection_point) do
    %{direction: direction, count: count} = settings
    new_direction = -1 * direction
    new_count = count + new_direction

    %{settings | direction: new_direction, count: new_count}
  end

  defp next_settings(settings, :regular) do
    %{direction: direction, count: count} = settings
    new_count = count + direction

    %{settings | count: new_count}
  end
end
