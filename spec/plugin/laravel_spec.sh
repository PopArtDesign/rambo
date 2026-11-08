# shellcheck shell=bash

Describe 'Laravel plugin'

    It 'fails if site is not powered by Laravel'
        cd ./fixture/simple-site

        When call "${SHELLSPEC_PROJECT_ROOT}/plugin/laravel"

        The status should be failure
    End

    It 'detects Laravel database configuration from .env'
        cd ./fixture/laravel-site

        When call "${SHELLSPEC_PROJECT_ROOT}/plugin/laravel"

        The status should be success
        The output should include 'database_type: mysql'
        The output should include 'database_host: 127.0.0.1'
        The output should include 'database_port: 3306'
        The output should include 'database_name: laravel-database'
        The output should include 'database_user: laravel-user'
        The output should include 'database_password: laravel-password'
    End

    It 'is detected by the detect command'
        When call rambo detect ./fixture/laravel-site

        The status should be success
        The output should include 'Name: laravel'
        The output should include 'Name:     laravel-database'
        The output should include 'Type:     mysql'
        The output should include 'Host:     127.0.0.1'
        The output should include 'Port:     3306'
        The output should include 'User:     laravel-user'
        The output should include 'Password: ********'
    End
End
