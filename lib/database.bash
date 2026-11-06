app::use 'error'

app::database::dump() {
    app::database::type || return 1

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
    app::database::type || return 1

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

# Resolves database type: configured value wins, otherwise detect it.
# Sets global "db_type" variable.
app::database::type() {
    local type="${site_config[database_type]:-}"

    if [[ -z "${type}" ]]; then
        type="$(app::database::detect_type)" || type=''

        if [[ -z "${type}" ]]; then
            app::error::error 'Database type not detected. Set "database_type" config key or install mysqldump, mariadb-dump or pg_dump'

            return 1
        fi

        site_config[database_type]="${type}"
    fi

    db_type="${type}"
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

declare -gA database_url_config=()

# Parses database URL into "database_url_config" associative array.
# Keys: type, name, user, password, host, port.
app::database::parse_url() {
    local url="${1:-}"

    database_url_config=()

    if [[ "${url}" != *'://'* ]]; then
        app::error::error "Invalid database_url: ${url}"

        return 1
    fi

    local type="${url%%://*}"
    local rest="${url#*://}"

    case "${type,,}" in
    mysql | mariadb | postgresql)
        type="${type,,}"
        ;;
    *)
        app::error::error "Invalid database_url protocol: ${type}"

        return 1
        ;;
    esac

    local userinfo=''

    if [[ "${rest}" == *'@'* ]]; then
        userinfo="${rest%@*}"
        rest="${rest##*@}"
    fi

    local authority="${rest%%/*}"
    local name="${rest#"${authority}"}"

    name="${name#/}"
    name="${name%%\?*}"
    name="${name%%#*}"

    local user=''
    local password=''

    if [[ -n "${userinfo}" ]]; then
        if [[ "${userinfo}" == *':'* ]]; then
            user="${userinfo%%:*}"
            password="${userinfo#*:}"
        else
            user="${userinfo}"
        fi
    fi

    local host=''
    local port=''

    if [[ "${authority}" == \[*\]* ]]; then
        host="${authority#\[}"
        host="${host%%\]*}"

        local address_suffix="${authority#*\]}"

        [[ "${address_suffix}" == :* ]] && port="${address_suffix#:}"
    elif [[ "${authority}" == *':'* ]]; then
        host="${authority%%:*}"
        port="${authority#*:}"
    else
        host="${authority}"
    fi

    database_url_config[type]="${type}"
    database_url_config[name]="${name}"
    database_url_config[user]="${user}"
    database_url_config[password]="${password}"
    database_url_config[host]="${host}"
    database_url_config[port]="${port}"
}

# Applies values parsed from "database_url" to "site_config".
# Explicitly configured database options take precedence over URL values.
app::database::apply_url() {
    local url="${site_config[database_url]:-}"

    [[ -z "${url}" ]] && return 0

    app::database::parse_url "${url}" || return 1

    app::database::is_explicit 'type' || site_config[database_type]="${database_url_config[type]}"
    app::database::is_explicit 'name' || site_config[database_name]="${database_url_config[name]}"
    app::database::is_explicit 'user' || site_config[database_user]="${database_url_config[user]}"
    app::database::is_explicit 'password' || site_config[database_password]="${database_url_config[password]}"
    app::database::is_explicit 'host' || site_config[database_host]="${database_url_config[host]}"
    app::database::is_explicit 'port' || site_config[database_port]="${database_url_config[port]}"
}

app::database::is_explicit() {
    [[ " ${site_config[database_explicit]:-} " == *" ${1} "* ]]
}
