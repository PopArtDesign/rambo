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

### Local config file (`.rambo.conf`)

To customize site backup process you can create a special config file in your site's root folder:

```sh
#
# The prefix 'xA4di35ie' added for security reasons,
# because site's root can be publicly available from the web.
# You can use any prefix you want or just omit it.
#

cat > xA4di35ie.rambo.conf <<CONFIG
# Also available: 'wordpress' and 'joomla'
# Try "rambo plugins" to see all available plugins
plugin: default

exclude: .git/* .zip

# Rambo can backup only one database
database_name: dbname
database_user: dbuser
database_password: dbpass
CONFIG
```

### Main config file

If you don't want to store Rambo's config in your site's root, you can create the config file outside:

```sh
cat > /etc/rambo/mysite.conf <<CONFIG
root: /var/www/mysite
plugin: default
include: index.html uploads/*
CONFIG
```

Then you should specify path to config file instead of site's root:

```sh
rambo backup /etc/rambo/mysite.conf mysite.zip
```

Config notes: unknown keys cause errors (only documented keys accepted); `root` key is valid only in main config files, not in local `.rambo.conf`.

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
