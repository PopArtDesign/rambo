# shellcheck shell=bash

backup_file_name() {
    TMPDIR="${SHELLSPEC_TMPBASE}" mktemp --dry-run --suffix '.zip'
}

backup_content() {
    zipinfo -1 "${backup_file}" | sort
}

Describe 'Joomla plugin'

    It 'fails if site is not powered by Joomla'
        cd ./fixture/simple-site

        When call "${SHELLSPEC_PROJECT_ROOT}/plugin/joomla"

        The status should be failure
    End

    It 'detects Joomla backup configuration'
        cd ./fixture/joomla-site

        When call "${SHELLSPEC_PROJECT_ROOT}/plugin/joomla"

        The status should be success
        The output should include 'exclude: /cache/* /tmp/* /administrator/cache/*'
        The output should include 'include: */index.html'
        The output should include 'database_type: mysql'
        The output should include 'database_name: joomla-database'
        The output should include 'database_user: joomla-user'
        The output should include 'database_password: joomla-password'
    End

    It 'detects PostgreSQL database type'
        cd ./fixture/joomla-postgresql-site

        When call "${SHELLSPEC_PROJECT_ROOT}/plugin/joomla"

        The status should be success
        The output should include 'database_type: postgresql'
        The output should include 'database_name: joomla-database'
    End

    It 'excludes "cache" and "tmp" folders'
        backup_file="$(backup_file_name)"

        Mock mysqldump
            echo 'dump'
        End

        When call rambo backup ./fixture/joomla-site "${backup_file}"

        The status should be success
        The file "${backup_file}" should be file
        The result of "backup_content()" should not include 'ignore-this-file'
    End

    It 'preserves all index.html files'
        backup_file="$(backup_file_name)"

        Mock mysqldump
            echo 'dump'
        End

        When call rambo backup ./fixture/joomla-site "${backup_file}"

        files="$(backup_content)"

        The status should be success
        The output should end with "Done: ${backup_file}"
        The file "${backup_file}" should be file
        The value "${files}" should include 'tmp/index.html'
        The value "${files}" should include 'cache/index.html'
        The value "${files}" should include 'administrator/cache/index.html'
    End
End
