app::use 'error'
app::use 'util'

app::database::dump() {
    local db_type=''

    db_type="$(app::database::type)" || return 1

    case "${db_type}" in
    mysql)
        app::database::mysqldump --single-transaction --no-tablespaces "${site_config[database_name]}"
        ;;
    mariadb)
        app::database::mariadb_dump --single-transaction "${site_config[database_name]}"
        ;;
    postgresql)
        app::database::pg_dump "${site_config[database_name]}"
        ;;
    esac
}

app::database::cli() {
    local db_type=''

    db_type="$(app::database::type)" || return 1

    case "${db_type}" in
    mysql)
        app::database::mysql "${site_config[database_name]}"
        ;;
    mariadb)
        app::database::mariadb "${site_config[database_name]}"
        ;;
    postgresql)
        app::database::psql "${site_config[database_name]}"
        ;;
    esac
}

# Prints resolved database type: configured value wins, otherwise detected.
# Use --quiet to fail without printing an error when nothing is detected.
app::database::type() {
    local quiet=false

    case "${1:-}" in
    -q | --quiet ) quiet=true ;;
    esac

    local type="${site_config[database_type]:-}"

    if [[ -z "${type}" ]]; then
        type="$(app::database::detect_type)" || type=''

        if [[ -z "${type}" ]]; then
            [[ "${quiet}" == 'false' ]] && app::error::error \
                'Database type not detected. Set "database_type" config key or install mysqldump, mariadb-dump or pg_dump'

            return 1
        fi
    fi

    printf '%s\n' "${type}"
}

# Prints detected database type (empty string and failure if nothing detected).
app::database::detect_type() {
    local candidate=''

    for candidate in mysqldump mariadb-dump pg_dump; do
        command -v "${candidate}" >/dev/null 2>&1 || continue

        case "${candidate}" in
        mysqldump)
            if app::database::is_mariadb "${candidate}"; then
                echo 'mariadb'
            else
                echo 'mysql'
            fi
            ;;
        mariadb-dump)
            echo 'mariadb'
            ;;
        pg_dump)
            echo 'postgresql'
            ;;
        esac

        return 0
    done

    return 1
}

# Detects if given dump tool is provided by MariaDB (mysqldump may be a symlink to mariadb-dump).
app::database::is_mariadb() {
    local version=''

    version="$("${1}" --version 2>/dev/null)" || version=''

    [[ "${version,,}" == *mariadb* ]]
}

app::database::mysqldump() {
    local binary='mysqldump'

    command -v mysqldump >/dev/null 2>&1 || binary='mariadb-dump'

    command "${binary}" --defaults-file=<(app::database::mysql_credentials 'client') "$@"
}

app::database::mysql() {
    local binary='mysql'

    command -v mysql >/dev/null 2>&1 || binary='mariadb'

    command "${binary}" --defaults-file=<(app::database::mysql_credentials 'client') "$@"
}

app::database::mariadb_dump() {
    local binary='mariadb-dump'

    command -v mariadb-dump >/dev/null 2>&1 || binary='mysqldump'

    command "${binary}" --defaults-file=<(app::database::mysql_credentials 'client') "$@"
}

app::database::mariadb() {
    local binary='mariadb'

    command -v mariadb >/dev/null 2>&1 || binary='mysql'

    command "${binary}" --defaults-file=<(app::database::mysql_credentials 'client') "$@"
}

app::database::pg_dump() {
    local -a args=()

    [[ -n "${site_config[database_user]:-}" ]] && args+=(--username="${site_config[database_user]}")
    [[ -n "${site_config[database_host]:-}" ]] && args+=(--host="${site_config[database_host]}")
    [[ -n "${site_config[database_port]:-}" ]] && args+=(--port="${site_config[database_port]}")

    (
        [[ -n "${site_config[database_password]:-}" ]] && export PGPASSWORD="${site_config[database_password]}"

        command pg_dump ${args[@]+"${args[@]}"} "$@"
    )
}

app::database::psql() {
    local -a args=()

    [[ -n "${site_config[database_user]:-}" ]] && args+=(--username="${site_config[database_user]}")
    [[ -n "${site_config[database_host]:-}" ]] && args+=(--host="${site_config[database_host]}")
    [[ -n "${site_config[database_port]:-}" ]] && args+=(--port="${site_config[database_port]}")

    (
        [[ -n "${site_config[database_password]:-}" ]] && export PGPASSWORD="${site_config[database_password]}"

        command psql ${args[@]+"${args[@]}"} "$@"
    )
}

app::database::mysql_credentials() {
    cat <<EOF
[${1:-client}]
user="${site_config[database_user]:-}"
password="${site_config[database_password]:-}"
${site_config[database_host]:+host="${site_config[database_host]}"}
${site_config[database_port]:+port="${site_config[database_port]}"}
EOF
}

# Applies values parsed from "database_url" to "site_config".
# Later config directives can override parsed values.
app::database::apply_url() {
    local -A parsed=()
    local url="${1:-${site_config[database_url]:-}}"

    app::util::parse_url parsed "${url}" || {
        app::error::error "Invalid database_url: ${url}"

        return 1
    }

    case "${parsed[type]}" in
    mysql | mariadb | postgresql) ;;
    *)
        app::error::error "Invalid database_url protocol: ${parsed[type]}"

        return 1
        ;;
    esac

    site_config[database_type]="${parsed[type]}"
    site_config[database_name]="${parsed[name]}"
    site_config[database_user]="${parsed[user]}"
    site_config[database_password]="${parsed[password]}"
    site_config[database_host]="${parsed[host]}"
    site_config[database_port]="${parsed[port]}"
}
