defmodule PgSpawnerTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  setup do
    base = Path.expand("../tmp", __DIR__)
    pgdata = Path.join(base, "pgdata-#{System.unique_integer([:positive])}")
    on_exit(fn -> File.rm_rf!(pgdata) end)

    %{pgdata: pgdata, port: free_port()}
  end

  describe "lifecycle" do
    test "starts and stops Postgres, claiming ownership", %{pgdata: pgdata, port: port} do
      {:ok, pid} = start_spawner(port: port, pgdata: pgdata)
      assert tcp_open?(port), "Postgres should be listening on #{port}"
      assert :sys.get_state(pid).owner == true

      stop_supervised!(PgSpawner)
      assert wait_tcp_closed(port), "Postgres should be down after stop"
    end

    test "joins as guest when Postgres is already running", %{pgdata: pgdata, port: port} do
      {:ok, _owner_pid} = start_spawner(port: port, pgdata: pgdata, name: :owner)
      assert tcp_open?(port)

      {:ok, guest_pid} = start_spawner(port: port, pgdata: pgdata, name: :guest)
      assert :sys.get_state(guest_pid).owner == false

      # Guest should NOT shut down Postgres when it stops
      GenServer.stop(guest_pid)
      assert tcp_open?(port), "Owner should still be running"
    end

    test "runs initdb automatically when pgdata is empty", %{pgdata: pgdata, port: port} do
      refute File.exists?(Path.join(pgdata, "PG_VERSION"))
      {:ok, _pid} = start_spawner(port: port, pgdata: pgdata)
      assert File.exists?(Path.join(pgdata, "PG_VERSION"))
      assert tcp_open?(port)
    end
  end

  defp start_spawner(opts) do
    spec = %{id: opts[:name] || PgSpawner, start: {PgSpawner, :start_link, [opts]}}
    start_supervised(spec)
  end

  defp free_port do
    {:ok, socket} = :gen_tcp.listen(0, [])
    {:ok, port} = :inet.port(socket)
    :gen_tcp.close(socket)
    port
  end

  defp tcp_open?(port) do
    case :gen_tcp.connect(~c"localhost", port, [], 200) do
      {:ok, sock} ->
        :gen_tcp.close(sock)
        true

      {:error, _} ->
        false
    end
  end

  defp wait_tcp_closed(port, attempts \\ 30)
  defp wait_tcp_closed(_port, 0), do: false

  defp wait_tcp_closed(port, attempts) do
    if tcp_open?(port) do
      Process.sleep(100)
      wait_tcp_closed(port, attempts - 1)
    else
      true
    end
  end

end
