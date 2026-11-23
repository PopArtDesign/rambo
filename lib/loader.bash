set -euo pipefail
shopt -s lastpipe nullglob dotglob

declare -gA app_libs_loaded=(["loader"]="${app_libs_path}"/${BASH_SOURCE[0]##*/})

app::use() {
    local lib="${1}"
    local path="${app_libs_path}/${lib}.bash"

    [[ -n "${app_libs_loaded[${lib}]:-}" ]] && return

    source "${path}"

    app_libs_loaded["${lib}"]="${path}"
}
