#shellcheck shell=bash

backup_file_name() {
    TMPDIR="${SHELLSPEC_TMPBASE}" mktemp --dry-run --suffix '.zip'
}

backup_content() {
    zipinfo -1 "${backup_file}" | sort
}

Describe 'rambo backup'
    It 'fails when invoked without arguments'
        When call rambo backup

        The status should be failure
        The error should include 'Missing argument: path to site or config file'
    End

    It 'fails when invalid option specified'
        When call rambo backup --hello

        The status should be failure
        The error should include 'Unknown option: --hello'
    End

    It 'fails when too many arguments specified'
        When call rambo backup foo bar baz

        The status should be failure
        The error should include 'Too many arguments. Expected: 2'
    End

    It 'fails when backup file has no .zip extension'
        When call rambo backup my-site my-backup

        The status should be failure
        The error should match pattern '*Backup file must have .zip extension: */my-backup*'
    End

    It 'fails when backup file already exists'
        When call rambo backup ./lib ./fixture/empty.zip

        The status should be failure
        The error should match pattern '*Backup file already exists: */fixture/empty.zip*'
    End

    It 'generates backup file name when backup path is a directory'
        backup_dir="$(TMPDIR="${SHELLSPEC_TMPBASE}" mktemp -d)"

        When call rambo backup ./fixture/simple-site "${backup_dir}"

        backup_file="$(echo "${backup_dir}"/*.zip)"

        The status should be success
        The output should match pattern "*Done: ${backup_dir}/simple-site-*.zip"
        The file "${backup_file}" should be file
        The result of "backup_content()" should equal $'css/\ncss/style.css\nindex.html'
    End

    It 'generates backup file name from site root when site path is a config file'
        backup_dir="$(TMPDIR="${SHELLSPEC_TMPBASE}" mktemp -d)"

        Data:expand
            #|root: ${SHELLSPEC_PROJECT_ROOT}/fixture/simple-site
        End

        When call rambo backup /dev/stdin "${backup_dir}"

        The status should be success
        The output should match pattern "*Done: ${backup_dir}/simple-site-*.zip"
        The value "$(echo "${backup_dir}"/*.zip)" should match pattern "*/simple-site-*.zip"
    End

    It 'shows help message if -h option specified'
        When call rambo backup -h

        The status should be success
        The output should start with 'Backup site'
    End

    It 'shows help message if --help option specified'
        When call rambo backup --help

        The status should be success
        The output should start with 'Backup site'
    End

    It "creates empty backup file if site's root is empty"
        empty_dir="$(TMPDIR="${SHELLSPEC_TMPBASE}" mktemp -d)"

        backup_file="$(backup_file_name)"

        When call rambo backup "${empty_dir}" "${backup_file}"

        The status should be success
        The output should end with "Done: ${backup_file}"
        The file "${backup_file}" should be file
        The result of "backup_content()" should include 'Empty zipfile.'
    End

    It "backups all site's files if no configuration provided"
        backup_file="$(backup_file_name)"

        When call rambo backup ./fixture/simple-site "${backup_file}"

        The status should be success
        The output should end with "Done: ${backup_file}"
        The file "${backup_file}" should be file
        The result of "backup_content()" should equal $'css/\ncss/style.css\nindex.html'
    End

    It "allows to exclude specified site's files"
        backup_file="$(backup_file_name)"

        Data:expand
            #|root: ${SHELLSPEC_PROJECT_ROOT}/fixture/simple-site
            #|exclude: *.css
        End

        When call rambo backup /dev/stdin "${backup_file}"

        The status should be success
        The output should end with "Done: ${backup_file}"
        The file "${backup_file}" should be file
        The result of "backup_content()" should equal $'css/\nindex.html'
    End

    It "allows to include only specified site's files"
        backup_file="$(backup_file_name)"

        Data:expand
            #|root: ${SHELLSPEC_PROJECT_ROOT}/fixture/simple-site
            #|include: *.html
        End

        When call rambo backup /dev/stdin "${backup_file}"

        The status should be success
        The output should end with "Done: ${backup_file}"
        The file "${backup_file}" should be file
        The result of "backup_content()" should equal 'index.html'
    End

    It 'allows to include some of excluded files'
        backup_file="$(backup_file_name)"

        Data:expand
            #|root: ${SHELLSPEC_PROJECT_ROOT}/fixture/joomla-site
            #|plugin: default
            #|local_config_file_suffix:
            #|exclude: /cache/* /tmp/* /administrator/cache/*
            #|include: */index.html
        End

        When call rambo backup /dev/stdin "${backup_file}"

        files="$(backup_content)"

        The status should be success
        The output should end with "Done: ${backup_file}"
        The file "${backup_file}" should be file
        The value "${files}" should not include 'ignore-this-file'
        The value "${files}" should include 'tmp/index.html'
        The value "${files}" should include 'cache/index.html'
        The value "${files}" should include 'administrator/cache/index.html'
    End

    It "allows to backup site's database"
        backup_file="$(backup_file_name)"

        Mock mysqldump
            echo 'dump'
        End

        Data:expand
            #|root: ${SHELLSPEC_PROJECT_ROOT}/fixture/simple-site
            #|database_name: simple
            #|database_user: simple
            #|database_password: simple
            #|database_dump_suffix: .dump.sql
        End

        When call rambo backup /dev/stdin "${backup_file}"

        The status should be success
        The output should end with "Done: ${backup_file}"
        The file "${backup_file}" should be file
        The result of "backup_content()" should include '.dump.sql'
    End

    It "backups only database if site's root is empty"
        empty_dir="$(TMPDIR="${SHELLSPEC_TMPBASE}" mktemp -d)"

        backup_file="$(backup_file_name)"

        Mock mysqldump
            echo 'dump'
        End

        Data:expand
            #|root: ${empty_dir}
            #|database_name: simple
            #|database_user: simple
            #|database_password: simple
            #|database_dump_suffix: .dump.sql
        End

        When call rambo backup /dev/stdin "${backup_file}"

        The status should be success
        The output should end with "Done: ${backup_file}"
        The file "${backup_file}" should be file
        The result of "backup_content()" should match pattern '*.dump.sql'
    End
End
