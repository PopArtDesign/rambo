#shellcheck shell=bash

app_name=rambo
app_libs_path=./lib

Include ./common.bash
Include ./lib/util.bash

Describe 'app::util::realpath'
    It 'accepts multiple options'
        dir="${SHELLSPEC_TMPBASE}/realpath-test"

        mkdir -p "${dir}"

        When call app::util::realpath -q -m "${dir}"

        The status should be success
        The output should equal "${dir}"
    End

    It 'works without options'
        dir="${SHELLSPEC_TMPBASE}/realpath-test"

        mkdir -p "${dir}"

        When call app::util::realpath "${dir}"

        The status should be success
        The output should equal "${dir}"
    End
End


Describe 'app::util::parse_url'
    It 'parses URL into provided array'
        declare -A parsed=()

        When call app::util::parse_url parsed 'postgresql://user:pass@db.example.com:5432/mydb'

        The status should be success
        The value "${parsed[type]}" should equal 'postgresql'
        The value "${parsed[name]}" should equal 'mydb'
        The value "${parsed[user]}" should equal 'user'
        The value "${parsed[password]}" should equal 'pass'
        The value "${parsed[host]}" should equal 'db.example.com'
        The value "${parsed[port]}" should equal '5432'
    End

    It 'parses URL without credentials'
        declare -A parsed=()

        When call app::util::parse_url parsed 'mysql://localhost/mydb'

        The status should be success
        The value "${parsed[type]}" should equal 'mysql'
        The value "${parsed[name]}" should equal 'mydb'
        The value "${parsed[user]:-}" should equal ''
        The value "${parsed[password]:-}" should equal ''
        The value "${parsed[host]}" should equal 'localhost'
        The value "${parsed[port]:-}" should equal ''
    End

    It 'parses bracketed IPv6 host and port'
        declare -A parsed=()

        When call app::util::parse_url parsed 'postgresql://user:pass@[::1]:5433/mydb'

        The status should be success
        The value "${parsed[host]}" should equal '::1'
        The value "${parsed[port]}" should equal '5433'
    End

    It 'fails when URL has no protocol'
        declare -A parsed=()

        When run app::util::parse_url parsed 'user:pass@localhost/mydb'

        The status should be failure
        The stderr should equal ''
    End

    It 'parses URL with unsupported protocol'
        declare -A parsed=()

        When call app::util::parse_url parsed 'sqlite://user:pass@localhost/mydb'

        The status should be success
        The value "${parsed[type]:-}" should equal 'sqlite'
    End
End
