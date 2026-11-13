#shellcheck shell=bash

app_version() {
    sed -n "s/^declare -rx app_version='\(.*\)'$/\1/p" "${SHELLSPEC_PROJECT_ROOT}/bin/rambo"
}

Describe 'rambo'
    It 'fails when invoked without arguments'
        When call rambo

        The status should be failure
        The error should include 'Missing argument: command. Try --help for more information'
    End

    It 'fails when command not found'
        When call rambo hello

        The status should be failure
        The error should include 'Unknown command: hello'
    End

    It 'fails when invalid option specified'
        When call rambo --hello

        The status should be failure
        The error should include 'Unknown option: --hello'
    End

    It 'shows help when -h option specified'
        When call rambo -h

        The status should be success
        The output should start with 'rambo: simple backup tool for web sites'
    End

    It 'shows help when --help option specified'
        When call rambo --help

        The status should be success
        The output should start with 'rambo: simple backup tool for web sites'
    End

    It 'shows version when -V option specified'
        When call rambo -V

        The status should be success
        The output should equal "rambo $(app_version)"
    End

    It 'shows version when --version option specified'
        When call rambo --version

        The status should be success
        The output should equal "rambo $(app_version)"
    End

    It 'executes specified command'
        When call rambo help

        The status should be success
        The output should start with 'rambo: simple backup tool for web sites'
    End
End
