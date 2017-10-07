defmodule TemperatureLoggerServer do
  @moduledoc """
  Documentation for TemperatureLoggerServer.
  """

  require Logger

  def accept(port) do
    # The options below mean:
    #
    # 1. `:binary` - receives data as binaries
    # 2. `packet: :line` - receives data line by line
    # 3. `active: false` - blocks on `:gen_tcp.recv/2 unitl data is available
    # 4. `reuseaddr: true` - allows us to resuse teh address if listener crashes
    options = [
      :binary,
      packet: :line,
      active: false,
      reuseaddr: true
    ]
    {:ok, socket} = :gen_tcp.listen(port, options)

    Logger.info "Accepting connections on port #{port}"
    loop_acceptor(socket)
  end

  defp loop_acceptor(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    {:ok, pid} = Task.Supervisor.start_child(TemperatureLoggerServer.TaskSupervisor, fn ->
      serve(client)
    end)
    :ok = :gen_tcp.controlling_process(client, pid)

    loop_acceptor(socket)
  end

  defp serve(socket) do
    msg =
      with {:ok, data} <- read_line(socket),
           {:ok, command} <- TemperatureLoggerServer.Command.parse(data),
           do: TemperatureLoggerServer.Command.run(command)

    write_line(socket, msg)
    serve(socket)
  end

  defp read_line(socket) do
    :gen_tcp.recv(socket, 0)
  end

  defp write_line(socket, {:ok, text}) do
    :gen_tcp.send(socket, text)
  end

  defp write_line(_socket, {:noop}) do
    # When no command is entered.
  end

  defp write_line(socket, {:error, :unknown_command}) do
    # Known error. Write to the client.
    :gen_tcp.send(socket, "UNKNOWN COMMAND\r\n")
  end

  defp write_line(socket, {:error, :port_closed}) do
    # Known error. Write to the client.
    :gen_tcp.send(socket, "PORT CURRENTLY CLOSED\r\n")
  end

  defp write_line(socket, {:error, :enoent}) do
    # Known error. Write to the client.
    :gen_tcp.send(socket, "PORT NOT FOUND\r\n")
  end

  defp write_line(_socket, {:error, :closed}) do
    # The connection was closed, exit politely.
    exit(:shutdown)
  end

  defp write_line(socket, {:error, error}) do
    # Unknown error. Write to the client and exit.
    :gen_tcp.send(socket, "ERROR\r\n")
    exit(error)
  end
end
