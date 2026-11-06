app::error::unknown_option() {
    app::error::error "Unknown option: ${1}"
}

app::error::missing_argument() {
    app::error::error "Missing argument${1:+: }${1:-}"
}

app::error::too_many_arguments() {
    app::error::error "Too many arguments.${1:+ Expected: }${1:-}"
}

app::error::error() {
    local exit_code=1

    if [ "${1}" = '--exit' ]; then
        exit_code="${2}"

        if [[ "${exit_code}" -lt 1 || "${exit_code}" -gt 255 ]]; then
            app::error::error "app::error::error(): invalid exit code: ${exit_code}"

            return 1
        fi

        shift 2
    fi

    printf "${app_name}${app_name:+ }ERROR: %s\n" "$@" >&2

    return "${exit_code}"
}
