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

    It 'detects postgresql by pg_dump binary'
        dir="$(fake_bin_dir)"
        fake_binary "${dir}" 'pg_dump' 'echo "pg_dump (PostgreSQL) 16.2 (Debian 16.2-1)"'

        PATH="${dir}"

        When call app::database::detect_type

        The status should be success
        The output should equal 'postgresql'
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
        site_config[database_type]='postgresql'

        When call app::database::type

        The status should be success
        The value "${db_type}" should equal 'postgresql'
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
        The value "${db_type}" should equal 'postgresql'
        The value "${site_config[database_type]}" should equal 'postgresql'
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



Describe 'app::database::apply_url'
    beforeEach() {
        declare -gA site_config=()
    }

    BeforeEach 'beforeEach'

    It 'parses mysql database URL'
        site_config[database_url]='mysql://user:pass@localhost:3306/mydb'

        When call app::database::apply_url

        The status should be success
        The value "${site_config[database_type]}" should equal 'mysql'
        The value "${site_config[database_name]}" should equal 'mydb'
        The value "${site_config[database_user]}" should equal 'user'
        The value "${site_config[database_password]}" should equal 'pass'
        The value "${site_config[database_host]}" should equal 'localhost'
        The value "${site_config[database_port]}" should equal '3306'
    End

    It 'parses mariadb database URL'
        site_config[database_url]='mariadb://user:pass@db.example.com:3307/mydb'

        When call app::database::apply_url

        The status should be success
        The value "${site_config[database_type]}" should equal 'mariadb'
        The value "${site_config[database_name]}" should equal 'mydb'
        The value "${site_config[database_host]}" should equal 'db.example.com'
        The value "${site_config[database_port]}" should equal '3307'
    End

    It 'parses postgresql database URL'
        site_config[database_url]='postgresql://user:pass@db.example.com:5432/mydb'

        When call app::database::apply_url

        The status should be success
        The value "${site_config[database_type]}" should equal 'postgresql'
        The value "${site_config[database_name]}" should equal 'mydb'
        The value "${site_config[database_user]}" should equal 'user'
        The value "${site_config[database_password]}" should equal 'pass'
        The value "${site_config[database_host]}" should equal 'db.example.com'
        The value "${site_config[database_port]}" should equal '5432'
    End

    It 'parses URL without credentials'
        site_config[database_url]='postgresql://db.example.com/mydb'

        When call app::database::apply_url

        The status should be success
        The value "${site_config[database_type]}" should equal 'postgresql'
        The value "${site_config[database_name]}" should equal 'mydb'
        The value "${site_config[database_user]:-}" should equal ''
        The value "${site_config[database_password]:-}" should equal ''
        The value "${site_config[database_host]}" should equal 'db.example.com'
        The value "${site_config[database_port]:-}" should equal ''
    End

    It 'parses URL with password containing a colon'
        site_config[database_url]='mysql://user:pa:ss@localhost/mydb'

        When call app::database::apply_url

        The status should be success
        The value "${site_config[database_user]}" should equal 'user'
        The value "${site_config[database_password]}" should equal 'pa:ss'
    End

    It 'lowercases database type from URL'
        site_config[database_url]='MySQL://user:pass@localhost/mydb'

        When call app::database::apply_url

        The status should be success
        The value "${site_config[database_type]}" should equal 'mysql'
    End

    It 'prefers explicitly configured options over URL values'
        site_config[database_url]='mysql://user:pass@localhost:3306/urldb'
        site_config[database_explicit]='type name user password host port'
        site_config[database_type]='postgresql'
        site_config[database_name]='configdb'
        site_config[database_user]='configuser'
        site_config[database_password]='configpass'
        site_config[database_host]='confighost'
        site_config[database_port]='5432'

        When call app::database::apply_url

        The status should be success
        The value "${site_config[database_type]}" should equal 'postgresql'
        The value "${site_config[database_name]}" should equal 'configdb'
        The value "${site_config[database_user]}" should equal 'configuser'
        The value "${site_config[database_password]}" should equal 'configpass'
        The value "${site_config[database_host]}" should equal 'confighost'
        The value "${site_config[database_port]}" should equal '5432'
    End

    It 'fills only options that are not configured explicitly'
        site_config[database_url]='postgresql://user:pass@db.example.com:5432/mydb'
        site_config[database_explicit]='user'
        site_config[database_user]='configuser'

        When call app::database::apply_url

        The status should be success
        The value "${site_config[database_user]}" should equal 'configuser'
        The value "${site_config[database_name]}" should equal 'mydb'
        The value "${site_config[database_host]}" should equal 'db.example.com'
        The value "${site_config[database_port]}" should equal '5432'
    End

    It 'reapplies changed URL values that were not configured explicitly'
        site_config[database_url]='mysql://user:pass@localhost:3306/firstdb'

        app::database::apply_url

        site_config[database_url]='postgresql://other:secret@db.example.com:5432/seconddb'

        When call app::database::apply_url

        The status should be success
        The value "${site_config[database_type]}" should equal 'postgresql'
        The value "${site_config[database_name]}" should equal 'seconddb'
        The value "${site_config[database_user]}" should equal 'other'
        The value "${site_config[database_password]}" should equal 'secret'
        The value "${site_config[database_host]}" should equal 'db.example.com'
        The value "${site_config[database_port]}" should equal '5432'
    End

    It 'does nothing when database URL is not set'
        When call app::database::apply_url

        The status should be success
        The value "${#site_config[@]}" should equal 0
    End

    It 'fails when URL has no protocol'
        site_config[database_url]='user:pass@localhost/mydb'

        When run app::database::apply_url

        The status should be failure
        The error should include 'Invalid database_url: user:pass@localhost/mydb'
    End

    It 'fails when URL protocol is not supported'
        site_config[database_url]='sqlite://user:pass@localhost/mydb'

        When run app::database::apply_url

        The status should be failure
        The error should include 'Invalid database_url protocol: sqlite'
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

    It 'falls back to mariadb-dump when mysqldump is not installed'
        site_config[database_type]='mysql'

        Mock mariadb-dump
            echo "$@"
        End

        # Restrict PATH to ShellSpec's mock and support directories so the real
        # mysqldump installed on the runner image can not leak into the test.
        PATH="${SHELLSPEC_MOCK_BINDIR}:${SHELLSPEC_SUPPORT_BINDIR}"

        When call app::database::dump

        The status should be success
        The output should include '--single-transaction'
        The output should include '--no-tablespaces'
    End

    It 'dumps postgresql database'
        site_config[database_type]='postgresql'
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

    It 'falls back to mariadb client when mysql is not installed'
        site_config[database_type]='mysql'

        Mock mariadb
            echo "$@"
        End

        # See the note in app::database::dump fallback test above.
        PATH="${SHELLSPEC_MOCK_BINDIR}:${SHELLSPEC_SUPPORT_BINDIR}"

        When call app::database::cli

        The status should be success
        The output should include 'test-db'
    End

    It 'launches psql client'
        site_config[database_type]='postgresql'

        Mock psql
            echo "$@"
        End

        When call app::database::cli

        The status should be success
        The output should include 'test-db'
        The output should include '--username=test-user'
    End
End
