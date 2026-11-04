# Rambo

Bash backup tool for Joomla, WordPress & static sites.

## Architecture

- **Entry**: `bin/rambo` — parses args/options, resolves `<command>` to `command/<name>`, exec's it.
- **Commands**: files in `command/` (`backup`, `restore`, `detect`, `db:dump`, `db:cli`, `help`, `plugins`). Each is a self-contained bash script sourcing `common.bash`.
- **Libs**: `lib/*.bash` loaded via `app::use '<name>'` from `common.bash`. Uses associative array cache (`app_libs_loaded`) — double-sourcing a lib silently no-ops.
  - `site.bash` — config loading chain, `site_config` associative array (shared across commands).
  - `plugin.bash` — plugin discovery/search paths.
  - `database.bash` — mysqldump/mariadb-dump/pg_dump and client wrappers using temp credential files. Resolves `database_type` (config key `mysql|mariadb|postgres`, otherwise auto-detected from installed dump tools: `mysqldump` → `mariadb-dump` → `pg_dump`).
  - `error.bash` — typed error functions (`app::error::error`, `::missing_argument`, etc.).
  - `util.bash` — `realpath` wrapper, `confirm` prompt.
  - `command.bash` — command resolver, lister.
- **Plugins**: `plugin/wordpress`, `plugin/joomla`, plus `$HOME/.local/share/rambo/plugin`, `~/.rambo/plugin`, `/usr/local/share/rambo/plugin`, `/usr/share/rambo`, and repo-local `plugin/`. Any executable in those dirs acts as an auto-detector; first one that succeeds wins. Plugins also load extra config via stdout (`key: value` format parsed by `app::site::load_config`).
- **Config format**: flat `key: value` lines (colon+space delimiter), `#` comments, empty lines skipped. Keys parsed case-by-case in `lib/site.bash` line ~126. Errors on unknown keys. `root` key only valid in main config (not local or plugin).

## Key constraints & gotchas

- `set -euo pipefail` + `shopt -s lastpipe nullglob dotglob` in `common.bash` — every sourced script inherits these. Never unset them mid-flow.
- Command scripts source `common.bash` themselves (not inherited) — each runs independently under `exec`.
- `site_config` is a shared global associative array. Commands initialize partial state before calling `app::site::load_site_config`.
- Restore requires the target directory to exist but be completely empty (`ls -A` check). Database dump extraction confirmed interactively via `app::util::confirm`.
- Backup validates `.zip` extension and refuses overwrites.
- DB ops use process substitution for credentials (`--defaults-file=<(…)`); need bash 4+.
- `app_zip` tolerates exit code 12 ("nothing to add") — don't treat zip failures silently.
- Plugin auto-detection runs in site root CWD — plugins should `cd` back if needed.

## Testing

Requires Shellspec (see `mise.toml`). CI installs via `curl -fsSL https://git.io/shellspec | sh -s -- --yes`. No deps beyond `bash`, `zip`, `unzip`, and optional DB tools (`mysqldump`, `mariadb-dump`, `pg_dump`, `mysql`, `mariadb`, `psql`).

```sh
shellspec                              # run all tests
shellspec spec/command/backup_spec.sh  # single file
shellspec -ex                          # run failing test(s) then all passings
```

- Shellspec BDD syntax: `Describe … It … End`.
- Mocks: `Mock <cmd> … End` around the `When call`.
- Data tables: `Data:expand` with `#|` prefixed key-value pairs, injected via `/dev/stdin`.
- Helper functions defined at top of spec files (e.g., `backup_file_name`, `backup_content`).
- Fixtures in `fixture/`: `simple-site`, `wordpress-site`, `joomla-site`, `custom-site`, `empty.zip`.
