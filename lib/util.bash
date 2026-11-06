app::util::realpath() {
    local -a opts=()
    local working_dir="${PWD}"

    while [[ $# -gt 0 ]]; do
        case "${1}" in
            -w | --working-dir ) working_dir="${2}" && shift ;;
            -- ) shift && break ;;
            -* ) opts+=("${1}") ;;
            * ) break
        esac

        shift
    done

    if [[ -p "${1}" ]]; then
        echo "${1}"

        return
    fi

    (cd "${working_dir}" && command realpath "${opts[@]}" "$@")
}

app::util::confirm() {
    local reply='n'
    local message="${1:-Sure?}"

    read -r -p "${message} [y/n] " reply

    [[ "${reply}" == 'y' ]]
}

declare -gA parsed_url=()

# Parses URL into "parsed_url" associative array.
# Keys: type, userinfo, name, user, password, host, port.
app::util::parse_url() {
    local url="${1:-}"

    parsed_url=()

    if [[ "${url}" != *'://'* ]]; then
        return 1
    fi

    local type="${url%%://*}"
    local rest="${url#*://}"

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

    parsed_url[type]="${type,,}"
    parsed_url[userinfo]="${userinfo}"
    parsed_url[name]="${name}"
    parsed_url[user]="${user}"
    parsed_url[password]="${password}"
    parsed_url[host]="${host}"
    parsed_url[port]="${port}"
}
