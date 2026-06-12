# Changelog

## [0.1.1] - 2026-06-12

### Changed
- Repository moved to https://github.com/saschabrink/pg_spawner.
- CI tests against Elixir 1.19 and 1.20 via the Nix flake dev shells.
- README badges for Hex version, docs, CI status, and license.

### Fixed
- Postgres now starts with `unix_socket_directories` pinned to the pgdata
  directory. Linux builds that default the socket to `/run/postgresql`
  (e.g. nixpkgs) previously died on startup when that directory wasn't
  writable — surfacing as `:postgres_start_timeout`.

## [0.1.0] - 2026-05-12

### Added

- `PgSpawner` GenServer — starts Postgres as a BEAM-owned child via `Port.open/2`, with a shell watchdog that guarantees cleanup on SIGKILL.
- Guest mode: joins an already-running Postgres without owning the lifecycle.
- `:log_file` option — Postgres output goes to `<pgdata>/postgres.log` by default instead of the BEAM console. Pass `:stdio` to restore console output, `nil` to discard.
- OTP Application auto-start — adding `:pg_spawner` to deps is sufficient to start Postgres on app boot. Defaults: `port: 15432`, `pgdata: "priv/db/data"`. Override via `config :pg_spawner, ...`. Set `pgdata: false` to disable.
- Auto-`initdb`: PgSpawner bootstraps `pgdata` on first run if no `PG_VERSION` is present. No shellHook ceremony required.
