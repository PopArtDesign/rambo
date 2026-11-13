#shellcheck shell=bash

app_name=rambo
app_libs_path=./lib

Include ./common.bash
Include ./lib/site.bash

Describe 'app::site::load_main_config'
    Set 'errexit:on'

    beforeEach() {
        declare -gA site_config=()
    }

    BeforeEach 'beforeEach'

    It 'fails if site path or config file not exists'
        When call app::site::load_main_config '/i/hope/this/path/not/exists'

        The status should be failure
        The error should include 'Site root or config file not exists: /i/hope/this/path/not/exists'
    End

    It 'sets default values for some config entries'
        When call app::site::load_main_config './fixture'

        The status should be success
        The value "${site_config[local_config_file_suffix]}" should equal '.rambo.conf'
        The value "${site_config[database_dump_suffix]}" should equal '.dump.sql'
    End

    Context 'when site root provided'
        It 'sets canonicalized site root path'
            site_root="$(realpath ./fixture)"

            When call app::site::load_main_config './fixture'

            The status should be success
            The value "${site_config[root]}" should equal "${site_root}"
        End
    End

    Context 'when main config file provided'
        It 'fails if main config file is not readable'
            not_readable="$(umask 777 && TMPDIR="${SHELLSPEC_TMPBASE}" mktemp --suffix '.conf')"

            When run app::site::load_main_config "${not_readable}"

            The status should be failure
            The error should include "${not_readable}: is not readable"

            rm -rf "${not_readable}"
        End

        It 'fails if site root is not set'
            Data:raw
                #|exclude: /cache/*
                #|include: */index.html
            End

            When run app::site::load_main_config /dev/stdin

            The status should be failure
            The error should include ': site root is not set'
        End

        It 'sets canonicalized path to main file'
            main_config_file="$(realpath ./fixture/site.conf)"

            When call app::site::load_main_config './fixture/site.conf'

            The status should be success
            The value "${site_config[main_config_file]}" should equal "${main_config_file}"
        End

        It 'sets canonicalized site root path'
            site_root="$(realpath ./fixture)"

            When call app::site::load_main_config './fixture/site.conf'

            The status should be success
            The value "${site_config[root]}" should equal "${site_root}"
        End
    End
End

Describe 'app::site::load_local_config'
    Set 'errexit:on'

    beforeEach() {
        declare -gA site_config=()

        workdir="$(mktemp -d "${SHELLSPEC_TMPBASE}/local-config.XXXXXX")"
        site_config[root]="${workdir}/site"
        site_config[local_config_file_suffix]='.rambo.conf'

        mkdir -p "${site_config[root]}" "${workdir}/backup"
    }

    BeforeEach 'beforeEach'

    It 'loads local config from site root'
        printf 'exclude: .git\n' > "${site_config[root]}/site.rambo.conf"

        When call app::site::load_local_config

        The status should be success
        The value "${site_config[exclude]:-}" should equal '.git'
        The value "${site_config[local_config_file]:-}" should equal "$(realpath "${site_config[root]}/site.rambo.conf")"
    End

    It 'loads local config from backup root'
        site_config[backup_root]="${workdir}/backup"

        printf 'exclude: .git\n' > "${workdir}/backup/site.rambo.conf"

        When call app::site::load_local_config

        The status should be success
        The value "${site_config[exclude]:-}" should equal '.git'
        The value "${site_config[local_config_file]:-}" should equal "$(realpath "${workdir}/backup/site.rambo.conf")"
    End

    It 'resolves relative backup root against site root'
        mkdir -p "${site_config[root]}/current"
        site_config[backup_root]='current'

        printf 'exclude: .git\n' > "${site_config[root]}/current/site.rambo.conf"

        When call app::site::load_local_config

        The status should be success
        The value "${site_config[exclude]:-}" should equal '.git'
    End

    It 'does not treat identical site and backup roots as duplicate locations'
        site_config[backup_root]="${site_config[root]}"

        printf 'exclude: .git\n' > "${site_config[root]}/site.rambo.conf"

        When call app::site::load_local_config

        The status should be success
        The value "${site_config[exclude]:-}" should equal '.git'
    End

    It 'fails when config files found in both site and backup roots'
        site_config[backup_root]="${workdir}/backup"

        touch "${site_config[root]}/site.rambo.conf" \
            "${workdir}/backup/backup.rambo.conf"

        When run app::site::load_local_config

        The status should be failure
        The error should include 'Multiple site config files found:'
    End
End

Describe 'app::site::load_config'
    Set 'errexit:on'

    beforeEach() {
        declare -gA site_config=()
    }

    BeforeEach 'beforeEach'

    It 'saves config values to special variable "site_config"'
        Data:raw
            #|root: /tmp
            #|exclude: /cache
            #|include: index.html
        End

        When call app::site::load_config 'site.conf' 'main'

        The status should be success
        The value "${#site_config[@]}" should equal 3
        The value "${site_config[root]:-}" should equal '/tmp'
        The value "${site_config[exclude]:-}" should equal '/cache'
        The value "${site_config[include]:-}" should equal 'index.html'
    End

    It 'appends "include" and "exclude"'
        load_config() {
            app::site::load_config 'site.conf' 'main' <<CONFIG
exclude: /cache .cache
include: index.html
CONFIG

            app::site::load_config 'joomla' 'plugin' <<CONFIG
exclude: *.zip .git
include: *.php
CONFIG
        }

        When call load_config

        The status should be success
        The value "${site_config[exclude]:-}" should equal '/cache .cache *.zip .git'
        The value "${site_config[include]:-}" should equal 'index.html *.php'
    End

    It 'ignores empty lines'
        Data:raw
            #|
            #|root: /tmp
            #|   
            #|
            #|exclude: .git
            #|
        End

        When call app::site::load_config 'site.conf' 'main'

        The status should be success
        The value "${site_config[*]}" should equal '.git /tmp'
    End

    It 'ignores comments'
        Data:raw
            #|#
            #|# Site's root
            #|#
            #|root: /tmp
            #|# Exclude GIT repos
            #|exclude: .git
        End

        When call app::site::load_config 'site.conf' 'main'

        The status should be success
        The value "${site_config[*]}" should equal '.git /tmp'
    End

    It 'parses database options'
        Data:raw
            #|database_name: dbname
            #|database_type: postgresql
            #|database_host: db.example.com
            #|database_port: 5432
            #|database_user: dbuser
            #|database_password: dbpass
        End

        When call app::site::load_config 'site.conf' 'main'

        The status should be success
        The value "${site_config[database_name]}" should equal 'dbname'
        The value "${site_config[database_type]}" should equal 'postgresql'
        The value "${site_config[database_host]}" should equal 'db.example.com'
        The value "${site_config[database_port]}" should equal '5432'
        The value "${site_config[database_user]}" should equal 'dbuser'
        The value "${site_config[database_password]}" should equal 'dbpass'
    End

    It 'parses database URL option'
        Data:raw
            #|database_url: mysql://user:pass@localhost:3306/dbname
        End

        When call app::site::load_config 'site.conf' 'main'

        The status should be success
        The value "${site_config[database_type]}" should equal 'mysql'
        The value "${site_config[database_name]}" should equal 'dbname'
        The value "${site_config[database_host]}" should equal 'localhost'
    End

    It 'lets later directives override database_url values'
        Data:raw
            #|database_url: mysql://user:pass@localhost:3306/dbname
            #|database_port: 3301
            #|database_name: otherdb
        End

        When call app::site::load_config 'site.conf' 'main'

        The status should be success
        The value "${site_config[database_port]}" should equal '3301'
        The value "${site_config[database_name]}" should equal 'otherdb'
        The value "${site_config[database_host]}" should equal 'localhost'
    End

    It 'fails when database_url is invalid'
        Data:raw
            #|database_url: localhost/mydb
        End

        When run app::site::load_config 'site.conf' 'main'

        The status should be failure
        The error should include 'invalid database_url: localhost/mydb'
    End

    It 'lowercases database type'
        Data:raw
            #|database_type: MySQL
        End

        When call app::site::load_config 'site.conf' 'main'

        The status should be success
        The value "${site_config[database_type]}" should equal 'mysql'
    End

    It 'accepts "PostgreSQL" database type'
        Data:raw
            #|database_type: PostgreSQL
        End

        When call app::site::load_config 'site.conf' 'main'

        The status should be success
        The value "${site_config[database_type]}" should equal 'postgresql'
    End

    It 'fails when invalid database type is specified'
        Data:raw
            #|database_type: sqlite
        End

        When run app::site::load_config 'site.conf' 'main'

        The status should be failure
        The error should include 'site.conf: invalid database_type: sqlite'
    End

    It "doesn't accept 'postgres' database type alias"
        Data:raw
            #|database_type: postgres
        End

        When run app::site::load_config 'site.conf' 'main'

        The status should be failure
        The error should include 'site.conf: invalid database_type: postgres'
    End

    It 'fails when invalid key is encountered'
        Data:raw
            #|root: /tmp
            #|foo: bar
        End

        When run app::site::load_config '/usr/local/etc/rambo/cool-site.conf' 'main'

        The status should be failure
        The error should include '/usr/local/etc/rambo/cool-site.conf: invalid key: foo'
    End

    It 'parses backup root option'
        Data:raw
            #|backup_root: current
        End

        When call app::site::load_config 'site.conf' 'main'

        The status should be success
        The value "${site_config[backup_root]:-}" should equal 'current'
    End

    It "doesn't allow \"root\" key in plugin config"
        Data:raw
            #|root: /tmp
            #|exclude: .git
        End

        When run app::site::load_config 'joomla' 'plugin'

        The status should be failure
        The error should include 'joomla: key "root" allowed only in main config file'
    End

    It "doesn't allow \"plugin\" key in plugin config"
        Data:raw
            #|plugin: /bin/true
            #|exclude: *
        End

        When run app::site::load_config 'true-plugin' 'plugin'

        The status should be failure
        The error should include 'true-plugin: key "plugin" not allowed for plugins'
    End

    It "doesn't allow \"local_config_file_suffix\" key in plugin config"
        Data:raw
            #|local_config_file_suffix: xxx.rambo.conf
            #|exclude: *
        End

        When run app::site::load_config 'true-plugin' 'plugin'

        The status should be failure
        The error should include 'true-plugin: key "local_config_file_suffix" allowed only in main config file'
    End

    It "doesn't allow \"root\" key in local config file"
        Data:raw
            #|root: /tmp
            #|exclude: .git
        End

        When run app::site::load_config '/var/www/mysite/xxx.rambo.conf' 'local'

        The status should be failure
        The error should include '/var/www/mysite/xxx.rambo.conf: key "root" allowed only in main config file'
    End

    It "doesn't allow \"local_config_file_suffix\" key in local config file"
        Data:raw
            #|exclude: .git
            #|local_config_file_suffix: *.jumbo.conf
        End

        When run app::site::load_config '/var/www/mysite/xxx.rambo.conf' 'local'

        The status should be failure
        The error should include '/var/www/mysite/xxx.rambo.conf: key "local_config_file_suffix" allowed only in main config file'
    End
End

Describe 'app::site::finalize_config'
    Set 'errexit:on'

    beforeEach() {
        declare -gA site_config=()
    }

    BeforeEach 'beforeEach'

    It 'keeps configured database type'
        dir="${SHELLSPEC_TMPBASE}/empty-bin-finalize"
        rm -rf "${dir}"
        mkdir -p "${dir}"

        PATH="${dir}"

        site_config[database_name]='dbname'
        site_config[database_type]='postgresql'

        When call app::site::finalize_config

        The status should be success
        The value "${site_config[database_type]}" should equal 'postgresql'
    End

    It 'detects database type when database name is set'
        dir="${SHELLSPEC_TMPBASE}/fake-bin-finalize"
        rm -rf "${dir}"
        mkdir -p "${dir}"

        {
            echo '#!/bin/bash'
            echo 'echo "pg_dump (PostgreSQL) 16.2"'
        } > "${dir}/pg_dump"

        chmod +x "${dir}/pg_dump"

        PATH="${dir}"

        site_config[database_name]='dbname'

        When call app::site::finalize_config

        The status should be success
        The value "${site_config[database_type]}" should equal 'postgresql'
    End

    It 'skips detection when database name is not set'
        dir="${SHELLSPEC_TMPBASE}/fake-bin-finalize-no-db"
        rm -rf "${dir}"
        mkdir -p "${dir}"

        {
            echo '#!/bin/bash'
            echo 'echo "mysqldump  Ver 8.0.36 for Linux on x86_64"'
        } > "${dir}/mysqldump"

        chmod +x "${dir}/mysqldump"

        PATH="${dir}"

        When call app::site::finalize_config

        The status should be success
        The value "${site_config[database_type]:-}" should equal ''
    End

    It 'defaults backup root to site root'
        site_config[root]='/tmp'

        When call app::site::finalize_config

        The status should be success
        The value "${site_config[backup_root]}" should equal '/tmp'
    End

    It 'resolves backup root relative to site root'
        site_config[root]="${SHELLSPEC_PROJECT_ROOT}/fixture/laravel-deployer-site"
        site_config[backup_root]='current'

        When call app::site::finalize_config

        The status should be success
        The value "${site_config[backup_root]}" should equal "$(realpath ./fixture/laravel-deployer-site/releases/v1)"
    End

    It 'keeps absolute backup root'
        site_config[root]='/tmp'
        site_config[backup_root]="${SHELLSPEC_PROJECT_ROOT}/fixture/laravel-site"

        When call app::site::finalize_config

        The status should be success
        The value "${site_config[backup_root]}" should equal "$(realpath ./fixture/laravel-site)"
    End

    It 'fails when backup root does not exist'
        site_config[root]='/tmp'
        site_config[backup_root]='/i/hope/this/path/not/exists'

        When run app::site::finalize_config

        The status should be failure
        The error should include 'Backup root not exists or not a directory: /i/hope/this/path/not/exists'
    End

    It 'fails when backup root is not a directory'
        site_config[root]='/tmp'
        site_config[backup_root]="${SHELLSPEC_PROJECT_ROOT}/fixture/site.conf"

        When run app::site::finalize_config

        The status should be failure
        The error should include 'Backup root not exists or not a directory:'
    End

    It 'fails when database type cannot be detected'
        dir="${SHELLSPEC_TMPBASE}/empty-bin-finalize-no-tools"
        rm -rf "${dir}"
        mkdir -p "${dir}"

        PATH="${dir}"

        site_config[database_name]='dbname'

        When run app::site::finalize_config

        The status should be failure
        The error should include 'Database type not detected'
        The value "${site_config[database_type]:-}" should equal ''
    End
End
