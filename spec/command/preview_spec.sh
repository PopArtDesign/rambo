#shellcheck shell=bash

Describe 'rambo preview'
    It 'fails when invoked without arguments'
        When call rambo preview

        The status should be failure
        The error should include 'Missing argument: path to site or config file'
    End

    It 'fails when invalid option specified'
        When call rambo preview --hello

        The status should be failure
        The error should include 'Unknown option: --hello'
    End

    It 'fails when too many arguments specified'
        When call rambo preview foo bar

        The status should be failure
        The error should include 'Too many arguments. Expected: 1'
    End

    It 'shows help message if -h option specified'
        When call rambo preview -h

        The status should be success
        The output should start with 'Preview files included in backup'
    End

    It 'shows help message if --help option specified'
        When call rambo preview --help

        The status should be success
        The output should start with 'Preview files included in backup'
    End

    It "lists all site's files if no configuration provided"
        When call rambo preview ./fixture/simple-site

        The status should be success
        The output should equal $'css/style.css\nindex.html'
    End

    It 'omits directories from the list'
        When call rambo preview ./fixture/simple-site

        The status should be success
        The line 1 should equal 'css/style.css'
        The line 2 should equal 'index.html'
    End

    It "allows to exclude specified site's files"
        Data:expand
            #|root: ${SHELLSPEC_PROJECT_ROOT}/fixture/simple-site
            #|exclude: *.css
        End

        When call rambo preview /dev/stdin

        The status should be success
        The output should equal 'index.html'
    End

    It "allows to include only specified site's files"
        Data:expand
            #|root: ${SHELLSPEC_PROJECT_ROOT}/fixture/simple-site
            #|include: *.html
        End

        When call rambo preview /dev/stdin

        The status should be success
        The output should equal 'index.html'
    End

    It 'allows to include some of excluded files'
        config_file="$(TMPDIR="${SHELLSPEC_TMPBASE}" mktemp)"

        cat >"${config_file}" <<CONFIG
root: ${SHELLSPEC_PROJECT_ROOT}/fixture/joomla-site
plugin: default
exclude: /cache/* /tmp/* /administrator/cache/*
include: */index.html
CONFIG

        When call rambo preview "${config_file}"

        The status should be success
        The output should not include 'ignore-this-file'
        The output should include 'tmp/index.html'
        The output should include 'cache/index.html'
        The output should include 'administrator/cache/index.html'
    End

    It 'lists files relative to backup root'
        When call rambo preview ./fixture/laravel-deployer-site

        The status should be success
        The output should include 'artisan'
        The output should not include 'current'
        The output should not include 'releases/'
        The error should include 'Database dump is also included'
    End

    It "outputs nothing if site's root is empty"
        empty_dir="$(TMPDIR="${SHELLSPEC_TMPBASE}" mktemp -d)"

        When call rambo preview "${empty_dir}"

        The status should be success
        The output should equal ''
    End

    It 'mentions database dump on stderr when database configured'
        Data:expand
            #|root: ${SHELLSPEC_PROJECT_ROOT}/fixture/simple-site
            #|database_name: simple
            #|database_type: mysql
            #|database_user: simple
            #|database_password: simple
        End

        When call rambo preview /dev/stdin

        The status should be success
        The output should not include 'Database dump'
        The error should include 'Database dump is also included: *.dump.sql'
    End
End
