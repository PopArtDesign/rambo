# Rambo: first backup

[![CI](https://github.com/PopArtDesign/rambo/actions/workflows/ci.yaml/badge.svg)](https://github.com/PopArtDesign/rambo/actions/workflows/ci.yaml)
[![GitHub license](https://img.shields.io/github/license/PopArtDesign/rambo)](https://github.com/PopArtDesign/rambo/blob/main/LICENSE)

Rambo is a simple backup tool for web sites ([Joomla](https://www.joomla.org/), [WordPress](https://wordpress.org/) and others) written in [Bash](https://www.gnu.org/software/bash/) (requires bash 4+).

## Install

Local (`~/.local`):

```sh
git clone --depth=1 https://github.com/PopArtDesign/rambo ~/.local/lib/rambo && ln -s ~/.local/lib/rambo/bin/rambo ~/.local/bin/rambo
```

Global (`/opt`):

```sh
sudo git clone --depth=1 https://github.com/PopArtDesign/rambo /opt/rambo && sudo ln -s /opt/rambo/bin/rambo /usr/local/bin/rambo
```

See [Uninstall](#uninstall) to remove Rambo.

## Usage

Rambo backs up all site data into a single `.zip` archive. Its [plugins](./plugin) detect site configuration — database, cache folders and more — and include or exclude files from the final backup.

Other commands include `restore`, `db:dump`, `db:cli`, `detect`, and `plugins` — see below. Run `rambo --help` for the full list.

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

Prints the resolved configuration — plugin, config files, root path, exclude/include patterns, and database settings. Useful for debugging why a site isn't backing up correctly.

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
| `plugin` | Plugin name (auto-detected if omitted); must match an executable script name in plugin search paths | auto-detect | Local, main |
| `exclude` | Space-separated glob patterns to exclude from backup | — | Local, main (repeatable) |
| `include` | Space-separated glob patterns to include in backup | — | Local, main (repeatable) |
| `database_url` | Database connection URL, e.g. `mysql://user:pass@localhost:3306/mydb` | — | Local, main |
| `database_name` | Database name for dump/restore operations | — | Local, main |
| `database_type` | Database type: `mysql`, `mariadb` or `postgresql` | auto-detected | Local, main |
| `database_host` | Database host | — | Local, main |
| `database_port` | Database port | — | Local, main |
| `database_user` | Database user for dump/cli auth | — | Local, main |
| `database_password` | Database password for dump/cli auth | — | Local, main |
| `database_dump_suffix` | Suffix appended to dump filenames (e.g. `.backup.sql`) | `.dump.sql` | Local, main |
| `local_config_file_suffix` | Filename suffix searched for in site root (e.g. `.rambo.conf`) | `.rambo.conf` | Main config only |

Repeatable keys (`exclude`, `include`) may appear multiple times — values accumulate.

`root` key is valid **only** in main config files (passed as argument or via `/etc/rambo/…`). It is rejected in local `.rambo.conf` files.

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

Individual database options take precedence over values from `database_url` and can be used to override any extracted value:

```sh
database_url: mysql://user:pass@localhost:3306/mydb
database_name: otherdb
database_port: 3307
```

### Local config file (`.rambo.conf`)

Place a config file matching the local suffix pattern inside your site's root folder:

```sh
cat > xA4di35ie.rambo.conf <<CONFIG
# Also available: 'wordpress' and 'joomla'
# Try "rambo plugins" to see all available plugins
plugin: default

exclude: .git/* .zip

# Rambo can back up only one database
database_name: dbname
database_user: dbuser
database_password: dbpass
CONFIG
```

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

Plugins auto-detect site type (WordPress, Joomla, etc.) from executable scripts in predefined search dirs:

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
CONFIG

sed -nE \
    -e "s/^.*DB_NAME.*'(.*)'.*$/database_name: \1/p" \
    -e "s/^.*DB_USER.*'(.*)'.*$/database_user: \1/p" \
    -e "s/^.*DB_PASSWORD.*'(.*)'.*$/database_password: \1/p" \
    'wp-config.php'
```

Plugin output is parsed by the same config loader — same keys, same rules. Keys marked "main config only" (like `root`) are rejected here.

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

## Uninstall

Local (`~/.local`):

```sh
unlink ~/.local/bin/rambo; rm -rf ~/.local/lib/rambo
```

Global (`/opt`):

```sh
sudo unlink /usr/local/bin/rambo; sudo rm -rf /opt/rambo
```

## License

Copyright (c) Voronkovich Oleg. Distributed under the [MIT License](LICENSE).
