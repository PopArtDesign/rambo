# Wrapper around `realpath` that resolves paths relative to a chosen working
# directory and leaves pipes untouched.
#
# Needed because config paths may be relative to the config file rather than
# the caller's CWD. Passing `--working-dir <dir>` (or `-w`) changes the base
# directory before resolving, without mutating the caller's CWD.
#
# Also handles process substitution paths such as /dev/fd/63: `realpath` would
# rewrite them to unstable /proc paths, so they are returned unchanged.
# Remaining options (`-q`, `-m`, ...) are forwarded to the system `realpath`,
# which keeps rambo working with paths whose components do not exist yet.
app::util::realpath() {
    local -a opts=()
    local working_dir="${PWD}"

    while [[ $# -gt 0 ]]; do
        case "${1}" in
        -w | --working-dir) working_dir="${2}" && shift ;;
        --) shift && break ;;
        -*) opts+=("${1}") ;;
        *) break ;;
        esac

        shift
    done

    if [[ -p "${1}" ]]; then
        echo "${1}"

        return
    fi

    (cd "${working_dir}" && command realpath ${opts[@]+"${opts[@]}"} "$@")
}

# Prints label/value pairs aligned by the longest label.
# Arguments alternate: label value label value ...
app::util::print_fields() {
    local -a fields=("$@")
    local width=0
    local index

    for ((index = 0; index < ${#fields[@]}; index += 2)); do
        if [[ "${#fields[index]}" -gt "${width}" ]]; then
            width="${#fields[index]}"
        fi
    done

    for ((index = 0; index < ${#fields[@]}; index += 2)); do
        printf "%-${width}s %s\n" "${fields[index]}" "${fields[index + 1]}"
    done
}

app::util::confirm() {
    local reply='n'
    local message="${1:-Sure?}"

    read -r -p "${message} [y/n] " reply

    [[ "${reply}" == 'y' ]]
}

# Parses URL into the associative array named by first argument.
# Keys: type, userinfo, name, user, password, host, port.
app::util::parse_url() {
    local -n out="${1:?parse_url: output variable name required}"
    local url="${2:-}"

    out=()

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

    out[type]="${type,,}"
    out[userinfo]="${userinfo}"
    out[name]="${name}"
    out[user]="${user}"
    out[password]="${password}"
    out[host]="${host}"
    out[port]="${port}"
}
