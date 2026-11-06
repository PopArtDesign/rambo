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
