# shellcheck shell=bash

backup_file_name() {
    TMPDIR="${SHELLSPEC_TMPBASE}" mktemp --dry-run --suffix '.zip'
}

backup_content() {
    zipinfo -1 "${backup_file}" | sort
}

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
        The output should include 'exclude: /storage/framework/cache/* /bootstrap/cache/*'
        The output should include 'database_host: 127.0.0.1'
        The output should include 'database_port: 3306'
        The output should include 'database_name: laravel-database'
        The output should include 'database_user: laravel-user'
        The output should include 'database_password: laravel-password'
    End

    It 'detects database URL from DB_URL'
        cd ./fixture/laravel-url-site

        When call "${SHELLSPEC_PROJECT_ROOT}/plugin/laravel"

        The status should be success
        The output should include 'database_url: mysql://url-user:url-password@db.example.com:3307/url-database?charset=utf8mb4&collation=utf8mb4_unicode_ci'
    End

    It 'is detected by the detect command via DB_URL'
        When call rambo detect ./fixture/laravel-url-site

        The status should be success
        The output should include 'Name: laravel'
        The output should include 'Name:     url-database'
        The output should include 'Type:     mysql'
        The output should include 'Host:     db.example.com'
        The output should include 'Port:     3307'
        The output should include 'User:     url-user'
        The output should include 'Password: ********'
    End

    It 'lets DB_URL override the individual DB_* values'
        When call rambo detect ./fixture/laravel-url-override-site

        The status should be success
        The output should include 'Name:     url-database'
        The output should include 'Type:     postgresql'
        The output should include 'Host:     url.example.com'
        The output should include 'Port:     5433'
        The output should include 'User:     url-user'
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

    It 'excludes "cache" folders'
        backup_file="$(backup_file_name)"

        Mock mysqldump
            echo 'dump'
        End

        When call rambo backup ./fixture/laravel-site "${backup_file}"

        The status should be success
        The file "${backup_file}" should be file
        The result of "backup_content()" should not include 'ignore-this-file'
    End
End
