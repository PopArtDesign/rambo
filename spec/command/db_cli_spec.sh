#shellcheck shell=bash

Describe 'rambo db:cli'
    It 'fails when invoked without arguments'
        When call rambo db:cli

        The status should be failure
        The error should include 'Missing argument: path to site or config file'
    End

    It 'fails when invalid option specified'
        When call rambo db:cli --hello

        The status should be failure
        The error should include 'Unknown option: --hello'
    End

    It 'fails when too many arguments specified'
        When call rambo db:cli foo bar baz

        The status should be failure
        The error should include 'Too many arguments. Expected: 1'
    End

    It 'shows help message if -h option specified'
        When call rambo db:cli -h

        The status should be success
        The output should start with 'Launch database client'
    End

    It 'shows help message if --help option specified'
        When call rambo db:cli --help

        The status should be success
        The output should start with 'Launch database client'
    End
End
