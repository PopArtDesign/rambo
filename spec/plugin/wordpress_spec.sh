# shellcheck shell=bash

backup_file_name() {
    TMPDIR="${SHELLSPEC_TMPBASE}" mktemp --dry-run --suffix '.zip'
}

backup_content() {
    zipinfo -1 "${backup_file}" | sort
}

Describe 'WordPress plugin'

    It 'fails if site is not powered by WordPress'
        cd ./fixture/simple-site

        When call "${SHELLSPEC_PROJECT_ROOT}/plugin/wordpress"

        The status should be failure
    End

    It 'detects WordPress backup configuration'
        cd ./fixture/wordpress-site

        When call "${SHELLSPEC_PROJECT_ROOT}/plugin/wordpress"

        The status should be success
        The output should include 'exclude: /wp-content/cache/*'
        The output should include 'database_type: mysql'
        The output should include 'database_name: wordpress-database'
        The output should include 'database_user: wordpress-user'
        The output should include 'database_password: wordpress-password'
    End

    It 'detects WordPress through a public_html symlink and sets backup_root'
        site_dir="${SHELLSPEC_TMPBASE}/wordpress-public-html-site"
        mkdir -p "${site_dir}"
        ln -sfn "${SHELLSPEC_PROJECT_ROOT}/fixture/wordpress-site" "${site_dir}/public_html"

        cd "${site_dir}"

        When call "${SHELLSPEC_PROJECT_ROOT}/plugin/wordpress"

        The status should be success
        The output should include "backup_root: ${SHELLSPEC_PROJECT_ROOT}/fixture/wordpress-site"
        The output should include 'database_name: wordpress-database'
    End

    It 'detects WordPress through a public_html directory and sets backup_root'
        site_dir="${SHELLSPEC_TMPBASE}/wordpress-public-html-dir-site"
        mkdir -p "${site_dir}/public_html"
        cp "${SHELLSPEC_PROJECT_ROOT}/fixture/wordpress-site/wp-config.php" "${site_dir}/public_html/"

        cd "${site_dir}"

        When call "${SHELLSPEC_PROJECT_ROOT}/plugin/wordpress"

        The status should be success
        The output should include "backup_root: ${site_dir}/public_html"
        The output should include 'database_name: wordpress-database'
    End

    It 'excludes "cache" folders'
        backup_file="$(backup_file_name)"

        Mock mysqldump
            echo 'dump'
        End

        When call rambo backup ./fixture/wordpress-site "${backup_file}"

        The status should be success
        The result of "backup_content()" should not include 'ignore-this-file'
    End
End
