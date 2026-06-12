defmodule PgSpawner do
  @moduledoc """
  Starts Postgres as an OS-level child of the BEAM via `Port.open/2`.

  When BEAM exits (including SIGKILL), a shell watchdog kills Postgres too.
  No PID files, no stale processes.

  If Postgres is already running on the configured port, joins as a *guest*
  and does not own the lifecycle. See README for details.

  ## Usage

      children = [
        {PgSpawner, port: 15432, pgdata: "priv/db/data"}
      ]
  """

  use GenServer
  require Logger

  @ready_attempts 50
  @ready_interval_ms 100

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name] || __MODULE__)
  end

  @impl true
  def init(opts) do
    port_number = Keyword.fetch!(opts, :port)
    # Expand to an absolute path: pgdata doubles as the unix socket directory
    # (-k), which Postgres resolves relative to its own working directory —
    # a relative path like "priv/db/data" would make it fail at startup.
    pgdata = opts |> Keyword.fetch!(:pgdata) |> Path.expand()
    log_file = Keyword.get(opts, :log_file, Path.join(pgdata, "postgres.log"))
    state = %{port: nil, owner: false, port_number: port_number, pgdata: pgdata}

    if running?(port_number) do
      Logger.info("[PgSpawner] Postgres already running on port #{port_number}, joining as guest")
      {:ok, state}
    else
      :ok = ensure_initialized(pgdata)

      Logger.info(
        "[PgSpawner] Starting Postgres on port #{port_number} (logs: #{describe_log_file(log_file)})"
      )

      port = spawn_postgres(port_number, pgdata, log_file)

      case wait_ready(port_number, @ready_attempts) do
        :ok ->
          {:ok, %{state | port: port, owner: true}}

        {:error, :timeout} ->
          Port.close(port)
          {:stop, :postgres_start_timeout}
      end
    end
  end

  @impl true
  def terminate(_reason, %{owner: true, port: port, pgdata: pgdata}) do
    Logger.info("[PgSpawner] Stopping Postgres")
    pg_ctl_stop(pgdata)
    Port.close(port)
  end

  def terminate(_reason, _state), do: :ok

  # Spawned via a shell wrapper that watches stdin. When BEAM dies (including
  # SIGKILL), the Port closes stdin → `cat` exits → wrapper sends SIGTERM to
  # Postgres. This guarantees cleanup even on crashes.
  defp spawn_postgres(port_number, pgdata, log_file) do
    sh_bin = System.find_executable("sh") || raise "sh not found on PATH"
    postgres_bin = System.find_executable("postgres") || raise "postgres binary not found on PATH"

    redirect = log_redirect(log_file)

    # -k pins the unix socket to pgdata: the nixpkgs Linux build defaults to
    # /run/postgresql, which doesn't exist (or isn't writable) on CI runners,
    # making Postgres exit before it ever binds the TCP port.
    script = """
    "$1" -D "$2" -p "$3" -k "$2" #{redirect} &
    PID=$!
    cat > /dev/null
    kill -TERM $PID 2>/dev/null
    wait $PID
    """

    Port.open(
      {:spawn_executable, sh_bin},
      [
        :binary,
        :exit_status,
        args: ["-c", script, "pg-watchdog", postgres_bin, pgdata, Integer.to_string(port_number)]
      ]
    )
  end

  defp log_redirect(:stdio), do: ""
  defp log_redirect(nil), do: "> /dev/null 2>&1"
  defp log_redirect(path) when is_binary(path), do: ~s(>> "#{path}" 2>&1)

  defp describe_log_file(:stdio), do: "stdio"
  defp describe_log_file(nil), do: "discarded"
  defp describe_log_file(path) when is_binary(path), do: path

  defp ensure_initialized(pgdata) do
    File.mkdir_p!(pgdata)

    if File.exists?(Path.join(pgdata, "PG_VERSION")) do
      :ok
    else
      Logger.info("[PgSpawner] Initializing pgdata at #{pgdata}")
      initdb_bin = System.find_executable("initdb") || raise "initdb not found on PATH"

      {_out, 0} =
        System.cmd(
          initdb_bin,
          ["--auth=trust", "--no-locale", "--encoding=UTF8", "-U", "postgres", "-D", pgdata],
          stderr_to_stdout: true
        )

      :ok
    end
  end

  defp pg_ctl_stop(pgdata) do
    pg_ctl = System.find_executable("pg_ctl")

    if pg_ctl do
      System.cmd(pg_ctl, ["stop", "-D", pgdata, "-m", "fast", "-w", "-t", "10"],
        stderr_to_stdout: true
      )
    end
  end

  defp running?(port_number) do
    case :gen_tcp.connect(~c"localhost", port_number, [], 200) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        true

      {:error, _} ->
        false
    end
  end

  defp wait_ready(_port_number, 0), do: {:error, :timeout}

  defp wait_ready(port_number, n) do
    if running?(port_number) do
      :ok
    else
      Process.sleep(@ready_interval_ms)
      wait_ready(port_number, n - 1)
    end
  end
end
