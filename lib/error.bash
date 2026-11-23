# Reports an unknown option error.
app::error::unknown_option() {
    app::error::error "Unknown option: ${1}"
}

# Reports a missing argument error, optionally naming the argument.
app::error::missing_argument() {
    app::error::error "Missing argument${1:+: }${1:-}"
}

# Reports a too many arguments error, optionally with expected syntax.
app::error::too_many_arguments() {
    app::error::error "Too many arguments.${1:+ Expected: }${1:-}"
}

# Prints an error prefixed with the app name.
# Pass --exit <code> first to set the return code.
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
