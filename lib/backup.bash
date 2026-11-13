app::backup::each_files_pass() {
    local callback="${1}"
    local archive="${2}"

    local include="${site_config[include]:-}"
    local exclude="${site_config[exclude]:-}"

    if [[ -z "${exclude}${include}" ]]; then
        "${callback}" "${archive}" .
    else
        if [[ -n "${include}" ]]; then
            "${callback}" "${archive}" . -i ${include}
        fi

        if [[ -n "${exclude}" ]]; then
            "${callback}" "${archive}" . -x ${exclude}
        fi
    fi
}

app::backup::add_to_archive() {
    local archive="${1}"
    shift

    # Ignore exit code 12: zip has nothing to do
    command zip -qur "-${COMPRESSION_LEVEL:-9}" "${archive}" "$@" || [[ "$?" -eq 12 ]]
}

app::backup::add_site_files() {
    local archive="${1}"

    set -o noglob
    pushd "${site_config[backup_root]}" >/dev/null

    app::backup::each_files_pass app::backup::add_to_archive "${archive}"

    popd >/dev/null
    set +o noglob
}

app::backup::list_site_files() {
    local archive="${TMPDIR:-/tmp}/rambo-preview.zip"

    set -o noglob
    pushd "${site_config[backup_root]}" >/dev/null

    app::backup::each_files_pass app::backup::list_pass "${archive}" | LC_ALL=C sort -u

    popd >/dev/null
    set +o noglob
}

app::backup::list_excluded_site_files() {
    local archive="${TMPDIR:-/tmp}/rambo-preview.zip"
    local all=''
    local included=''

    set -o noglob
    pushd "${site_config[backup_root]}" >/dev/null

    all="$(app::backup::list_pass "${archive}" . | LC_ALL=C sort -u)"
    included="$(app::backup::each_files_pass app::backup::list_pass "${archive}" | LC_ALL=C sort -u)"

    LC_ALL=C comm -23 \
        <(if [[ -n "${all}" ]]; then printf '%s\n' "${all}"; fi) \
        <(if [[ -n "${included}" ]]; then printf '%s\n' "${included}"; fi)

    popd >/dev/null
    set +o noglob
}

app::backup::list_pass() {
    local archive="${1}"
    shift

    local output=''
    output="$(command zip -sf -r "${archive}" "$@" || [[ "$?" -eq 12 ]])"

    # Dry-run output: a header, two-space indented entries, then a total line.
    awk '/^  / { name = substr($0, 3); if (name !~ /\/$/) print name }' <<<"${output}"
}
