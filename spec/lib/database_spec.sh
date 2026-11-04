#shellcheck shell=bash

app_name=rambo
app_libs_path=./lib

Include ./common.bash
Include ./lib/database.bash

Describe 'app::database::detect_type'
    fake_bin_dir() {
        local dir="${SHELLSPEC_TMPBASE}/fake-bin"

        rm -rf "${dir}"
        mkdir -p "${dir}"

        printf '%s' "${dir}"
    }

    fake_binary() {
        local dir="${1}"
        local name="${2}"
        local body="${3:-}"

        {
            echo '#!/bin/bash'
            echo "echo '${name}'"
            [[ -n "${body}" ]] && echo "${body}"
        } > "${dir}/${name}"

        chmod +x "${dir}/${name}"
    }

    It 'detects mysql by mysqldump binary'
        dir="$(fake_bin_dir)"
        fake_binary "${dir}" 'mysqldump' 'echo "mysqldump  Ver 8.0.36 for Linux on x86_64 (MySQL Community Server - GPL)"'

        PATH="${dir}"

        When call app::database::detect_type

        The status should be success
        The output should equal 'mysql'
    End

    It 'detects mariadb by mariadb-dump binary'
        dir="$(fake_bin_dir)"
        fake_binary "${dir}" 'mariadb-dump' 'echo "mariadb-dump  Ver 10.11.5-MariaDB for Linux on x86_64"'

        PATH="${dir}"

        When call app::database::detect_type

        The status should be success
        The output should equal 'mariadb'
    End

    It 'detects mariadb when mysqldump is provided by MariaDB'
        dir="$(fake_bin_dir)"
        fake_binary "${dir}" 'mysqldump' 'echo "mysqldump  Ver 10.11.5-MariaDB for Linux on x86_64"'

        PATH="${dir}"

        When call app::database::detect_type

        The status should be success
        The output should equal 'mariadb'
    End

    It 'detects postgres by pg_dump binary'
        dir="$(fake_bin_dir)"
        fake_binary "${dir}" 'pg_dump' 'echo "pg_dump (PostgreSQL) 16.2 (Debian 16.2-1)"'

        PATH="${dir}"

        When call app::database::detect_type

        The status should be success
        The output should equal 'postgres'
    End

    It 'prefers mysqldump over other dump tools'
        dir="$(fake_bin_dir)"
        fake_binary "${dir}" 'mysqldump' 'echo "mysqldump  Ver 8.0.36 for Linux on x86_64"'
        fake_binary "${dir}" 'mariadb-dump'
        fake_binary "${dir}" 'pg_dump'

        PATH="${dir}"

        When call app::database::detect_type

        The status should be success
        The output should equal 'mysql'
    End

    It 'fails when no dump tools installed'
        dir="$(fake_bin_dir)"

        PATH="${dir}"

        When call app::database::detect_type

        The status should be failure
        The output should equal ''
    End
End

Describe 'app::database::type'
    beforeEach() {
        declare -gA site_config=()
        declare -g db_type=''
    }

    BeforeEach 'beforeEach'

    It 'uses configured database type'
        site_config[database_type]='postgres'

        When call app::database::type

        The status should be success
        The value "${db_type}" should equal 'postgres'
    End

    It 'detects database type when it is not configured'
        dir="${SHELLSPEC_TMPBASE}/fake-bin-type"

        rm -rf "${dir}"
        mkdir -p "${dir}"

        {
            echo '#!/bin/bash'
            echo 'echo "pg_dump (PostgreSQL) 16.2"'
        } > "${dir}/pg_dump"

        chmod +x "${dir}/pg_dump"

        PATH="${dir}"

        When call app::database::type

        The status should be success
        The value "${db_type}" should equal 'postgres'
        The value "${site_config[database_type]}" should equal 'postgres'
    End

    It 'fails when database type cannot be detected'
        dir="${SHELLSPEC_TMPBASE}/empty-bin"

        rm -rf "${dir}"
        mkdir -p "${dir}"

        PATH="${dir}"

        When run app::database::type

        The status should be failure
        The error should include 'Database type not detected'
    End
End

Describe 'app::database::dump'
    beforeEach() {
        declare -gA site_config=(
            [database_name]='test-db'
            [database_user]='test-user'
            [database_password]='test-password'
        )
        declare -g db_type=''
    }

    BeforeEach 'beforeEach'

    It 'dumps mysql database'
        site_config[database_type]='mysql'

        Mock mysqldump
            echo "$@"
        End

        When call app::database::dump

        The status should be success
        The output should include 'test-db'
        The output should include '--single-transaction'
        The output should include '--no-tablespaces'
    End

    It 'dumps mariadb database'
        site_config[database_type]='mariadb'

        Mock mariadb-dump
            echo "$@"
        End

        When call app::database::dump

        The status should be success
        The output should include 'test-db'
        The output should include '--single-transaction'
    End

    It 'dumps postgres database'
        site_config[database_type]='postgres'
        site_config[database_host]='db.example.com'
        site_config[database_port]='5433'

        Mock pg_dump
            echo "$@"
        End

        When call app::database::dump

        The status should be success
        The output should include 'test-db'
        The output should include '--username=test-user'
        The output should include '--host=db.example.com'
        The output should include '--port=5433'
    End
End

Describe 'app::database::cli'
    beforeEach() {
        declare -gA site_config=(
            [database_name]='test-db'
            [database_user]='test-user'
            [database_password]='test-password'
        )
        declare -g db_type=''
    }

    BeforeEach 'beforeEach'

    It 'launches mysql client'
        site_config[database_type]='mysql'

        Mock mysql
            echo "$@"
        End

        When call app::database::cli

        The status should be success
        The output should include 'test-db'
    End

    It 'launches mariadb client'
        site_config[database_type]='mariadb'

        Mock mariadb
            echo "$@"
        End

        When call app::database::cli

        The status should be success
        The output should include 'test-db'
    End

    It 'launches psql client'
        site_config[database_type]='postgres'

        Mock psql
            echo "$@"
        End

        When call app::database::cli

        The status should be success
        The output should include 'test-db'
        The output should include '--username=test-user'
    End
End
