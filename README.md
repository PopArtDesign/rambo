# Rambo: first backup

[![CI](https://github.com/PopArtDesign/rambo/actions/workflows/ci.yaml/badge.svg)](https://github.com/PopArtDesign/rambo/actions/workflows/ci.yaml)
[![GitHub license](https://img.shields.io/github/license/PopArtDesign/rambo)](https://github.com/PopArtDesign/rambo/blob/main/LICENSE)

Rambo is a simple backup tool for web sites ([Joomla](https://www.joomla.org/), [WordPress](https://wordpress.org/) and others) written in [Bash](https://www.gnu.org/software/bash/).

## System Requirements

**Required:** `bash` 4+, `coreutils` (GNU), `zip`, `unzip`.

**Optional:** `mysql`/`mysqldump`, `mariadb`/`mariadb-dump`, `psql`/`pg_dump` — only needed for database dump/restore operations. When no DB credentials are configured, Rambo auto-detects the database type from installed dump tools. If none found, database commands fail gracefully.

## Install

### Local (`~/.local`):

```sh
git clone --depth=1 https://github.com/PopArtDesign/rambo ~/.local/lib/rambo && ln -s ~/.local/lib/rambo/bin/rambo ~/.local/bin/rambo
```

### Global (`/opt`):

```sh
sudo git clone --depth=1 https://github.com/PopArtDesign/rambo /opt/rambo && sudo ln -s /opt/rambo/bin/rambo /usr/local/bin/rambo
```

See [Uninstall](#uninstall) to remove Rambo. Also see [Bash completion](#bash-completion) below for tab completion setup.

## Usage

Rambo backs up all site data into a single `.zip` archive. Its [plugins](./plugin) detect site configuration — database, cache folders and more — and include or exclude files from the final backup.

Other commands include `restore`, `db:dump`, `db:cli`, `detect`, `preview`, and `plugins` — see below. Run `rambo --help` for the full list.

### backup

```sh
rambo backup /path/to/site /path/to/backup.zip
```

Creates a `.zip` archive of the site files plus an optional database dump (embedded inside). Refuses to overwrite existing files; backup path must end in `.zip`.

### restore

```sh
rambo restore /path/to/site /path/to/backup.zip
```

Extracts a backup archive into the target directory. **The target must exist and be completely empty** (`ls -A` check). If the backup contains a database dump, it prompts before importing.

### db:dump

```sh
rambo db:dump /path/to/site
```

Exports the site's configured database to stdout as SQL. Fails if no database is detected.

### db:cli

```sh
rambo db:cli /path/to/site
```

Opens an interactive database shell using the site's configured credentials. Requires the matching client tool (`mysql`, `mariadb` or `psql`).

### detect

```sh
rambo detect /path/to/site
```

Prints the resolved configuration — plugin, config files, root path, backup root (when it differs from root), exclude/include patterns, and database settings. Useful for debugging why a site isn't backing up correctly. Database passwords are masked by default; pass `--show-password` (or `-p`) to print them unmasked.

### preview

```sh
rambo preview /path/to/site
```

Prints the files that `rambo backup` would put into the archive, one path per line, relative to the backup root. Directory entries are omitted and the output is sorted and de-duplicated. This is a zip dry run, so nothing is written to disk and it is much faster than a full backup.

Pass `--excluded` (or `-e`) to print the opposite: files present under the backup root that would **not** end up in the archive. This includes files skipped by `include` patterns, not just those matched by `exclude`.

When listing included files, if the site has a configured database, a note about the database dump (which is generated at backup time and cannot be previewed) is printed to stderr. Redirect stderr away for a clean file list:

```sh
rambo preview /path/to/site 2>/dev/null
```

### plugins

```sh
rambo plugins          # show active plugin name
rambo plugins --all    # show all discovered plugins
rambo plugins --paths  # show plugin search paths
```

## Configuration

Rambo uses a flat `key: value` format (colon + space delimiter). Lines starting with `#` are comments; blank lines are skipped. Unknown keys cause errors.

### Available options

| Key | Description | Default | Allowed in |
|---|---|---|---|
| `root` | Absolute or relative path to site root directory | — | Main config only |
| `backup_root` | Directory whose contents are archived; relative paths resolve against `root` | `root` | Local, main, plugin |
| `plugin` | Plugin name (auto-detected if omitted); must match an executable script name in plugin search paths | auto-detect | Local, main |
| `exclude` | Space-separated [zip patterns](#excluding-and-including-files) to exclude from backup | — | Local, main (repeatable) |
| `include` | Space-separated [zip patterns](#excluding-and-including-files) to force into backup | — | Local, main (repeatable) |
| `database_url` | Database connection URL, e.g. `mysql://user:pass@localhost:3306/mydb`; parsed into other `database_*` options at the directive site | — | Local, main |
| `database_name` | Database name for dump/restore operations | — | Local, main |
| `database_type` | Database type: `mysql`, `mariadb` or `postgresql` | auto-detected | Local, main |
| `database_host` | Database host | — | Local, main |
| `database_port` | Database port | — | Local, main |
| `database_user` | Database user for dump/cli auth | — | Local, main |
| `database_password` | Database password for dump/cli auth | — | Local, main |
| `database_dump_suffix` | Suffix appended to dump filenames (e.g. `.backup.sql`) | `.dump.sql` | Local, main |
| `local_config_file_suffix` | Filename suffix searched for in site root and `backup_root` (e.g. `.rambo.conf`) | `.rambo.conf` | Main config only |

Repeatable keys (`exclude`, `include`) may appear multiple times — values accumulate.

`root` key is valid **only** in main config files (passed as argument or via `/etc/rambo/…`). It is rejected in local `.rambo.conf` files.

### Excluding and including files

`exclude` and `include` are whitespace-separated patterns passed to `zip`'s `-x` and `-i` options. They match paths **relative to the backup root** (`root`, unless `backup_root` overrides it), and Rambo disables shell globbing, so write them as-is — no quotes or escaping needed.

Pattern syntax:

- `*` matches any characters, **including `/`**; `?` matches one character; `[abc]` / `[!abc]` match character sets.
- A leading `/` is optional: `/cache/*` and `cache/*` mean the same thing.
- `*` already crosses directories, so `*.log` matches `error.log`, `logs/error.log` and `var/logs/error.log`. No `**` needed.
- To exclude a directory's contents, add `/*`: use `.git/*` or `cache/*`. A bare `.git` or a trailing slash (`.git/`) does not skip the files inside.
- To match a directory at any depth, list both root and nested forms: `cache/* */cache/*`. (`*/cache/*` alone misses a top-level `cache/`.)

How `exclude` and `include` combine:

- Values from main config, local config and plugins **accumulate**; they do not replace each other.
- With `include` but no `exclude`, only matching files are archived.
- With both, Rambo first adds files matching `include`, then adds everything except `exclude`. So an included file survives even if a broader exclude pattern would drop it — but the rest of the site is still backed up.
- To back up **only** selected paths even when plugins add exclusions, combine a catch-all exclude with includes: `exclude: *` and `include: index.php assets/* uploads/*`.
- To keep placeholder files inside excluded caches (common for Joomla), exclude the contents and include the placeholders: `exclude: cache/*` and `include: */index.html`.

To test patterns without creating an archive, use `rambo preview /path/to/site`: it lists the files that would be included, while `rambo preview --excluded /path/to/site` lists the files that would be left out. Both apply all `include`, `exclude`, and plugin-generated patterns.

Examples:

```sh
# Root .git and node_modules, plus all logs and archives at any depth
exclude: .git/* node_modules/* *.log *.zip

# Cache directories at any depth, but keep .gitkeep files
exclude: cache/* */cache/* .git/*
include: cache/.gitkeep */.gitkeep

# Back up only the application, uploads and hidden server config
exclude: *
include: index.php assets/* uploads/* .htaccess

# WordPress plugin excludes wp-content/cache/*; force-keep one file from it
include: wp-content/cache/keep.txt
```

Patterns cannot contain spaces (space is the separator), so paths with spaces cannot currently be targeted individually.

### Database types

Supported database types: `mysql`, `mariadb`, `postgresql`.

When `database_type` is not set, Rambo detects it by looking for installed dump tools, in this order:

1. `mysqldump` — type `mysql`, or `mariadb` if the tool reports itself as MariaDB (on MariaDB systems `mysqldump` is usually a symlink to `mariadb-dump`)
2. `mariadb-dump` — type `mariadb`
3. `pg_dump` — type `postgresql`

Within the MySQL family the tools are interchangeable: `mariadb-dump`/`mariadb` are used when `mysqldump`/`mysql` are not installed, and vice versa.

Set `database_type` explicitly to skip detection:

```sh
database_type: postgresql
database_name: dbname
database_user: dbuser
database_password: dbpass
database_host: localhost
database_port: 5432
```

### Database URL

Database connection settings can be provided as a single URL:

```sh
database_url: mysql://user:pass@localhost:3306/mydb
```

Supported protocols are `mysql`, `mariadb` and `postgresql`. The protocol determines `database_type`, and the URL components set `database_name`, `database_user`, `database_password`, `database_host` and `database_port`.

Database options listed after `database_url` override its parsed values (later directives win):

```sh
database_url: mysql://user:pass@localhost:3306/mydb
database_name: otherdb
database_port: 3307
```

### Local config file (`.rambo.conf`)

Place a config file matching the local suffix pattern inside your site's root folder (or inside `backup_root`, if set):

```sh
cat > xA4di35ie.rambo.conf <<CONFIG
# Also available: 'wordpress' and 'joomla'
# Try "rambo plugins" to see all available plugins
plugin: default

exclude: .git/* *.zip

# Rambo can back up only one database
database_name: dbname
database_user: dbuser
database_password: dbpass
CONFIG
```

Rambo searches the site root first, then `backup_root` — including when a plugin (such as Laravel's Deployer layout detection) sets it. If config files exist in both locations, Rambo fails with an error. The `plugin` key cannot be set in a config file found in `backup_root`, because the plugin has already been loaded by then.

### Main config file

For sites without local config access (or for global overrides), create a standalone config and pass it as the site argument:

```sh
cat > /etc/rambo/mysite.conf <<CONFIG
root: /var/www/mysite
plugin: default
include: index.html uploads/*
CONFIG

rambo backup /etc/rambo/mysite.conf mysite.zip
```

## Plugins

Plugins auto-detect site type (WordPress, Joomla, Laravel, etc.) from executable scripts in predefined search dirs:

- `~/.rambo/plugin`
- `~/.local/share/rambo/plugin`
- `/usr/share/rambo`
- `/usr/local/share/rambo/plugin`

The first one that recognizes the site becomes active. You can also pick one explicitly via `plugin:` key in config.

### How plugins work

A plugin is any **executable bash script** placed in a plugin search directory. When Rambo starts, it runs each candidate plugin with the site root as CWD. A plugin signals recognition by **exiting 0**; any other exit status means "not my site".

Configured plugins produce `key: value` lines on **stdout**, just like local/main config files. Those values override or supplement what you may have in your config files.

Example — the built-in WordPress plugin reads `wp-config.php`:

```bash
#!/usr/bin/env bash

[ -f 'wp-config.php' ] || exit 1          # fail = not WP

cat <<CONFIG                              # pass config via stdout
exclude: /wp-content/cache/*
database_type: mysql
CONFIG

sed -nE \
    -e "s/^.*DB_NAME.*'(.*)'.*$/database_name: \1/p" \
    -e "s/^.*DB_USER.*'(.*)'.*$/database_user: \1/p" \
    -e "s/^.*DB_PASSWORD.*'(.*)'.*$/database_password: \1/p" \
    'wp-config.php'
```

Plugin output is parsed by the same config loader — same keys, same rules. Keys marked "main config only" (like `root`) are rejected here.

Plugins may emit `backup_root` to archive a directory other than the site root. The built-in Laravel plugin does this for Deployer-style layouts, where `current` is a symlink to the active `releases/<name>` directory:

```bash
if [[ -L 'current' && -f 'current/artisan' ]]; then
    backup_root="$(readlink -f current)"
    cd "${backup_root}"
fi

# ...
printf 'backup_root: %s\n' "${backup_root}"
```

The archive then contains the release contents at its top level, and `exclude` patterns are applied relative to that directory.

### The `default` plugin

When no installed plugin recognizes the site, Rambo falls back to `default`. This acts as a no-op: it produces no extra config. You can create a real `default` plugin for static sites or anything unrecognized — place an executable script named `default` in any plugin search dir.

### Creating a custom plugin

1. Create an executable script in a plugin search path, e.g. `~/.local/share/rambo/plugin/mycms`:

   ```sh
   mkdir -p ~/.local/share/rambo/plugin
   nano ~/.local/share/rambo/plugin/mycms
   chmod +x ~/.local/share/rambo/plugin/mycms

   ```
2. Add detection logic (exit 1 to reject, exit 0 to claim):

   ```bash
   #!/usr/bin/env bash

   [ -f 'my-cms.ini' ] || exit 1
   [[ $(head -c 4 'my-cms.ini') == '[CMS]' ]] || exit 1

   cat <<CONFIG
   exclude: .git/* node_modules/* *.log cache/*
   include: index.php assets/* uploads/*
   database_name: mycms_db
   database_user: mycms_user
   database_password: $$(grep '^db_pass' 'my-cms.ini' | cut -d= -f2)
   CONFIG
   ```

3. Test with `rambo detect /path/to/site` — it should show `plugin: mycms` and all expected config values.

## Bash completion

The completion script lives in [`completion/rambo.bash`](./completion/rambo.bash). Link or copy it into a bash-completion directory.

Local (`~/.local`):

```sh
mkdir -p ~/.local/share/bash-completion/completions
ln -sf ~/.local/lib/rambo/completion/rambo.bash ~/.local/share/bash-completion/completions/rambo
```

Global (`/opt`):

```sh
sudo ln -sf /opt/rambo/completion/rambo.bash /usr/share/bash-completion/completions/rambo
```

Without bash-completion, source the script from `~/.bashrc`:

```sh
source ~/.local/lib/rambo/completion/rambo.bash
```

## Uninstall

Local (`~/.local`):

```sh
unlink ~/.local/bin/rambo
rm -rf ~/.local/lib/rambo
rm -f ~/.local/share/bash-completion/completions/rambo
```

Global (`/opt`):

```sh
sudo unlink /usr/local/bin/rambo
sudo rm -rf /opt/rambo
sudo rm -f /usr/share/bash-completion/completions/rambo
```

If you sourced the completion script from `~/.bashrc` instead, remove that `source` line.

## License

Copyright (c) Voronkovich Oleg. Distributed under the [MIT License](LICENSE).
