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
        The value "${site_config[database_explicit]}" should equal 'name type host port user password'
    End

    It 'parses database URL option'
        Data:raw
            #|database_url: mysql://user:pass@localhost:3306/dbname
        End

        When call app::site::load_config 'site.conf' 'main'

        The status should be success
        The value "${site_config[database_url]}" should equal 'mysql://user:pass@localhost:3306/dbname'
        The value "${site_config[database_explicit]:-}" should equal ''
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
