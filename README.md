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

Opens an interactive MySQL shell using the site's configured credentials. Requires `mysql` CLI tool.

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

Plugins auto-detect site type (wordpress, joomla, default) from executable scripts in predefined search dirs (`plugin/`, `$HOME/.local/share/rambo/plugin`, `~/.rambo/plugin`, `/usr/local/share/rambo/plugin`, `/usr/share/rambo`, and repo-local `plugin/`). The first one that succeeds becomes active. Plugins also load extra config via their stdout output.

## Configuration

Rambo uses a flat `key: value` format (colon + space delimiter). Lines starting with `#` are comments; blank lines are skipped. Unknown keys cause errors.

### Available options

| Key | Description | Default | Allowed in |
|---|---|---|---|
| `root` | Absolute or relative path to site root directory | — | Main config only |
| `plugin` | Plugin name (auto-detected if omitted); must match an executable script name in plugin search paths | auto-detect | Local, main |
| `exclude` | Space-separated glob patterns to exclude from backup | — | Local, main (repeatable) |
| `include` | Space-separated glob patterns to include in backup | — | Local, main (repeatable) |
| `database_name` | Database name for dump/restore operations | — | Local, main |
| `database_user` | Database user for mysqldump/mysql auth | — | Local, main |
| `database_password` | Database password for mysqldump/mysql auth | — | Local, main |
| `database_dump_suffix` | Suffix appended to dump filenames (e.g. `.backup.sql`) | `.dump.sql` | Local, main |
| `local_config_file_suffix` | Filename suffix searched for in site root (e.g. `.rambo.conf`) | `.rambo.conf` | Main config only |

Repeatable keys (`exclude`, `include`) may appear multiple times — values accumulate.

`root` key is valid **only** in main config files (passed as argument or via `/etc/rambo/…`). It is rejected in local `.rambo.conf` files.

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
