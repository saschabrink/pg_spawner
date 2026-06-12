# PgSpawner

[![Hex.pm](https://img.shields.io/hexpm/v/pg_spawner.svg)](https://hex.pm/packages/pg_spawner)
[![Hexdocs](https://img.shields.io/badge/hex-docs-purple.svg)](https://hexdocs.pm/pg_spawner)
[![CI](https://github.com/saschabrink/pg_spawner/actions/workflows/ci.yml/badge.svg)](https://github.com/saschabrink/pg_spawner/actions/workflows/ci.yml)
[![License](https://img.shields.io/hexpm/l/pg_spawner.svg)](https://github.com/saschabrink/pg_spawner/blob/main/LICENSE)

Zero-config local Postgres for Elixir. Add the dep, Postgres boots with your app and shuts down with it. Auto-initdb on first run, no PID files, no stale processes.

## Installation

```elixir
def deps do
  [{:pg_spawner, "~> 0.1", only: [:dev, :test]}]
end
```

That's it. `pg_spawner` ships its own OTP Application, which auto-starts Postgres on boot with sensible defaults (`port: 15432`, `pgdata: "priv/db/data"`). Your `application.ex` stays untouched.

Postgres starts when your app boots and stops when it shuts down — even on SIGKILL.

## Requirements

`postgres` and `initdb` must be on `PATH`. A Nix flake covers it:

```nix
buildInputs = [
  pkgs.elixir_1_19
  pkgs.postgresql_18
];
```

PgSpawner bootstraps `pgdata` on first run — it creates the directory and runs `initdb` if no `PG_VERSION` is present, then starts Postgres.

## Configuration

All options have defaults; configure to override:

```elixir
# config/dev.exs
config :pg_spawner, port: 16432, pgdata: "/tmp/my_db"
```

| Option | Default | Description |
|---|---|---|
| `:port` | `15432` | TCP port Postgres listens on |
| `:pgdata` | `"priv/db/data"` | Path to the data directory (must already be initialized via `initdb`) |
| `:log_file` | `<pgdata>/postgres.log` | Postgres stdout/stderr destination. Pass `:stdio` to let it flow to the BEAM console, `nil` to discard. |

To disable auto-start entirely (e.g. in `config/test.exs` if you want manual control):

```elixir
config :pg_spawner, pgdata: false
```

## How it works

PgSpawner opens Postgres via `Port.open/2` with a small shell wrapper:

```sh
postgres -D <pgdata> -p <port> &
PID=$!
cat > /dev/null     # blocks until BEAM closes the Port
kill -TERM $PID     # cleanup
```

When BEAM exits (cleanly or via crash/SIGKILL), the Port closes, `cat` reads EOF and exits, and the wrapper sends `SIGTERM` to Postgres. The Postgres lifetime is bound to BEAM's lifetime — guaranteed cleanup, no PID files to manage.

If Postgres is already listening on the configured port when PgSpawner starts, it joins as a **guest** instead: it does not start a new server and does not own the shutdown. This makes it safe to run alongside an externally-managed Postgres (e.g. system service, Docker container).

## License

MIT
