#shellcheck shell=bash

Describe 'rambo detect'
    It 'fails when invoked without arguments'
        When call rambo detect

        The status should be failure
        The error should include 'Missing argument: path to site or config file'
    End

    It 'fails when invalid option specified'
        When call rambo detect --hello

        The status should be failure
        The error should include 'Unknown option: --hello'
    End

    It 'fails when too many arguments specified'
        When call rambo detect foo bar baz

        The status should be failure
        The error should include 'Too many arguments. Expected: 1'
    End

    It 'shows main config path'
        main_config_file="$(realpath ./fixture/joomla-site.conf)"

        When call rambo detect ./fixture/joomla-site.conf

        The status should be success
        The output should include "Main config:  ${main_config_file}"
    End

    It 'shows backup root when it differs from site root'
        backup_root="$(realpath ./fixture/laravel-deployer-site/releases/v1)"

        When call rambo detect ./fixture/laravel-deployer-site

        The status should be success
        The output should include "Backup root: ${backup_root}"
    End

    It 'omits backup root when it equals site root'
        When call rambo detect ./fixture/laravel-site

        The status should be success
        The output should not include 'Backup root:'
    End

    It 'masks database password'
        When call rambo detect ./fixture/custom-site

        The status should be success
        The output should include 'Password: ********'
        The output should not include 'custom-password'
    End

    It 'shows help message if -h option specified'
        When call rambo detect -h

        The status should be success
        The output should start with "Detect site's configuration"
    End

    It 'shows help message if --help option specified'
        When call rambo detect --help

        The status should be success
        The output should start with "Detect site's configuration"
    End
End
