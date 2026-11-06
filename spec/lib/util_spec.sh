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
End


Describe 'app::util::parse_url'
    It 'parses URL into parsed_url'
        When call app::util::parse_url 'postgresql://user:pass@db.example.com:5432/mydb'

        The status should be success
        The value "${parsed_url[type]}" should equal 'postgresql'
        The value "${parsed_url[name]}" should equal 'mydb'
        The value "${parsed_url[user]}" should equal 'user'
        The value "${parsed_url[password]}" should equal 'pass'
        The value "${parsed_url[host]}" should equal 'db.example.com'
        The value "${parsed_url[port]}" should equal '5432'
    End

    It 'parses URL without credentials'
        When call app::util::parse_url 'mysql://localhost/mydb'

        The status should be success
        The value "${parsed_url[type]}" should equal 'mysql'
        The value "${parsed_url[name]}" should equal 'mydb'
        The value "${parsed_url[user]:-}" should equal ''
        The value "${parsed_url[password]:-}" should equal ''
        The value "${parsed_url[host]}" should equal 'localhost'
        The value "${parsed_url[port]:-}" should equal ''
    End

    It 'parses bracketed IPv6 host and port'
        When call app::util::parse_url 'postgresql://user:pass@[::1]:5433/mydb'

        The status should be success
        The value "${parsed_url[host]}" should equal '::1'
        The value "${parsed_url[port]}" should equal '5433'
    End

    It 'fails when URL has no protocol'
        When run app::util::parse_url 'user:pass@localhost/mydb'

        The status should be failure
        The stderr should equal ''
    End

    It 'parses URL with unsupported protocol'
        When call app::util::parse_url 'sqlite://user:pass@localhost/mydb'

        The status should be success
        The value "${parsed_url[type]:-}" should equal 'sqlite'
    End
End
