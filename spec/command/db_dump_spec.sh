#shellcheck shell=bash

Describe 'rambo db:dump'
    It 'fails when invoked without arguments'
        When call rambo db:dump

        The status should be failure
        The error should include 'Missing argument: path to site or config file'
    End

    It 'fails when invalid option specified'
        When call rambo db:dump --hello

        The status should be failure
        The error should include 'Unknown option: --hello'
    End

    It 'fails when too many arguments specified'
        When call rambo db:dump foo bar baz

        The status should be failure
        The error should include 'Too many arguments. Expected: 1'
    End

    It 'dumps configured database'
        Mock pg_dump
            echo "$@"
        End

        Data:expand
            #|root: ${SHELLSPEC_PROJECT_ROOT}/fixture/simple-site
            #|database_name: mydb
            #|database_type: postgresql
            #|database_user: myuser
        End

        When call rambo db:dump /dev/stdin

        The status should be success
        The output should include 'mydb'
        The output should include '--username'
    End

    It 'fails when database type cannot be detected'
        Data:expand
            #|root: ${SHELLSPEC_PROJECT_ROOT}/fixture/simple-site
            #|database_name: mydb
            #|database_type: sqlite
        End

        When run rambo db:dump /dev/stdin

        The status should be failure
        The error should include 'invalid database_type: sqlite'
    End

    It 'shows help message if -h option specified'
        When call rambo db:dump -h

        The status should be success
        The output should start with "Dump site's database"
    End

    It 'shows help message if --help option specified'
        When call rambo db:dump --help

        The status should be success
        The output should start with "Dump site's database"
    End
End
