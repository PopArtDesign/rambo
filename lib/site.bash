app::use 'database'
app::use 'error'
app::use 'plugin'
app::use 'util'

app::site::load_site_config() {
    app::site::load_main_config "${1}"

    app::site::load_local_config

    app::site::load_plugin_config

    # Plugin config may set backup_root, so its local config is found only now.
    app::site::load_backup_root_local_config

    app::site::finalize_config
}

app::site::load_main_config() {
    local site_path="${1:-/dev/stdin}"

    if [[ "${site_path}" == '-' ]]; then
        site_path='/dev/stdin'
    fi

    if ! [[ -e "${site_path}" ]]; then
        app::error::error "Site root or config file not exists: ${site_path}"
    fi

    site_path="$(app::util::realpath "${site_path}")"

    site_config[local_config_file_suffix]='.rambo.conf'
    site_config[database_dump_suffix]='.dump.sql'

    if [[ -d "${site_path}" ]]; then
        site_config[root]="${site_path}"

        return
    fi

    if ! [[ -r "${site_path}" ]]; then
        app::error::error "${site_path}: is not readable"
    fi

    site_config[main_config_file]="${site_path}"
    app::site::load_config "${site_path}" 'main' <"${site_path}"

    if [[ -z "${site_config[root]:-}" ]]; then
        app::error::error "${site_path}: site root is not set"
    fi

    local base_config_dir="${PWD}"

    if [[ -f "${site_path}" ]]; then
        base_config_dir="$(dirname "${site_path}")"
    fi

    site_config[root]="$(app::util::realpath --working-dir "${base_config_dir}" -qm "${site_config[root]}")"
}

app::site::load_plugin_config() {
    if [[ -v 'site_config[plugin_config]' ]]; then
        app::error::error "Plugin already loaded: ${site_config[plugin]:-}"
    fi

    app::site::check_site_root_exists_and_readable

    local plugin="${site_config[plugin]:-}"
    local plugin_path=''
    local plugin_config=''

    if [[ -z "${plugin}" ]]; then
        plugin='default'

        local plg=''
        local plg_config=''

        for plg in $(app::plugin::plugins_list); do
            if plg_config="$(cd "${site_config[root]}" && "${plg}")"; then
                plugin="${plg##*/}"
                plugin_path="$(app::util::realpath "${plg}")"
                plugin_config="${plg_config}"

                break
            fi
        done

    elif [[ ! "${plugin}" == default ]]; then
        if ! plugin_path="$(app::plugin::find_executable "${plugin}")"; then
            app::error::error "Plugin executable not found: ${plugin}"
        fi

        plugin_path="$(realpath "${plugin_path}")"

        if ! plugin_config="$(cd "${site_config[root]}" && "${plugin_path}")"; then
            app::error::error "Error occured while loading plugin: ${plugin_path}"
        fi
    fi

    site_config[plugin]="${plugin}"
    site_config[plugin_path]="${plugin_path}"
    site_config[plugin_config]="${plugin_config}"

    if [[ -n "${plugin_config}" ]]; then
        app::site::load_config "${plugin_path}" 'plugin' <<<"${plugin_config}"
    fi
}

app::site::load_local_config() {
    [[ -z "${site_config[local_config_file_suffix]}" ]] && return

    app::site::check_site_root_exists_and_readable

    local -a config_dirs=("${site_config[root]}")
    local backup_root="${site_config[backup_root]:-}"

    if [[ -n "${backup_root}" ]]; then
        backup_root="$(app::util::realpath \
            --working-dir "${site_config[root]}" -qm "${backup_root}")"

        if [[ "${backup_root}" != "${site_config[root]}" ]]; then
            config_dirs+=("${backup_root}")
        fi
    fi

    app::site::load_local_config_from "${config_dirs[@]}"
}

# Plugins may set backup_root, which is unknown when the local config is first
# loaded. Look there again once the plugin config is available.
app::site::load_backup_root_local_config() {
    [[ -z "${site_config[local_config_file_suffix]:-}" ]] && return

    local backup_root="${site_config[backup_root]:-}"

    [[ -z "${backup_root}" ]] && return

    backup_root="$(app::util::realpath \
        --working-dir "${site_config[root]}" -qm "${backup_root}")"

    [[ "${backup_root}" == "${site_config[root]}" ]] && return

    if [[ -n "${site_config[local_config_file]:-}" ]]; then
        [[ "$(dirname "${site_config[local_config_file]}")" == "${backup_root}" ]] && return
    fi

    local plugin_before="${site_config[plugin]:-}"

    app::site::load_local_config_from "${backup_root}"

    if [[ "${site_config[plugin]:-}" != "${plugin_before}" ]]; then
        app::error::error "${site_config[local_config_file]}: key \"plugin\" not allowed in backup_root local config file"
    fi
}

app::site::load_local_config_from() {
    local -a config_files=()
    local dir=''

    for dir in "$@"; do
        config_files+=("${dir}"/*"${site_config[local_config_file_suffix]}")
    done

    [[ "${#config_files[@]}" -eq 0 ]] && return

    if [[ -n "${site_config[local_config_file]:-}" ]]; then
        app::error::error "Multiple site config files found: ${site_config[local_config_file]} ${config_files[*]}"
    fi

    if [[ "${#config_files[@]}" -gt 1 ]]; then
        app::error::error "Multiple site config files found: ${config_files[*]}"
    fi

    local config_file=''
    config_file="$(app::util::realpath "${config_files[0]}")"

    site_config[local_config_file]="${config_file}"

    app::site::load_config "${config_file}" 'local' <"${config_file}"
}

app::site::load_config() {
    local src="${1}"
    local context="${2}"

    while IFS=': ' read -r key value; do
        case "${key}" in
        root)
            [[ "${context}" != 'main' ]] && app::error::error \
                "${src}: key \"${key}\" allowed only in main config file"

            site_config[root]="${value}"
            ;;
        local_config_file_suffix)
            [[ "${context}" != 'main' ]] && app::error::error \
                "${src}: key \"${key}\" allowed only in main config file"

            site_config[local_config_file_suffix]="${value}"
            ;;
        backup_root)
            site_config[backup_root]="${value}"
            ;;
        plugin)
            [[ "${context}" == 'plugin' ]] && app::error::error \
                "${src}: key \"${key}\" not allowed for plugins"

            site_config[plugin]="${value}"
            ;;
        exclude)
            site_config[exclude]+="${site_config[exclude]:+ }${value}"
            ;;
        include)
            site_config[include]+="${site_config[include]:+ }${value}"
            ;;
        database_name)
            site_config[database_name]="${value}"
            ;;
        database_url)
            app::database::apply_url "${value}" || app::error::error \
                "${src}: invalid database_url: ${value}"
            ;;
        database_type)
            case "${value,,}" in
            mysql | mariadb | postgresql)
                site_config[database_type]="${value,,}"
                ;;
            *)
                app::error::error "${src}: invalid database_type: ${value}"
                ;;
            esac
            ;;
        database_host)
            site_config[database_host]="${value}"
            ;;
        database_port)
            site_config[database_port]="${value}"
            ;;
        database_user)
            site_config[database_user]="${value}"
            ;;
        database_password)
            site_config[database_password]="${value}"
            ;;
        database_dump_suffix)
            site_config[database_dump_suffix]="${value}"
            ;;
        '' | '#')
            continue
            ;;
        *)
            app::error::error "${src}: invalid key: ${key}"
            ;;
        esac
    done
}

# Resolves values that depend on all configuration sources being loaded.
app::site::finalize_config() {
    app::site::finalize_backup_root

    if [[ -z "${site_config[database_type]:-}" && -n "${site_config[database_name]:-}" ]]; then
        local detected=''

        if detected="$(app::database::detect_type)"; then
            site_config[database_type]="${detected}"
        else
            app::error::error 'Database type not detected. Set "database_type" config key or install mysqldump, mariadb-dump or pg_dump'

            return 1
        fi
    fi
}

app::site::finalize_backup_root() {
    local site_root="${site_config[root]:-}"

    if [[ -z "${site_config[backup_root]:-}" ]]; then
        site_config[backup_root]="${site_root}"

        return
    fi

    site_config[backup_root]="$(app::util::realpath \
        --working-dir "${site_root:-${PWD}}" -qm "${site_config[backup_root]}")"

    if [[ ! -d "${site_config[backup_root]}" ]]; then
        app::error::error "Backup root not exists or not a directory: ${site_config[backup_root]}"
    fi

    if [[ ! -r "${site_config[backup_root]}" ]]; then
        app::error::error "Backup root not readable: ${site_config[backup_root]}"
    fi
}

app::site::check_site_root_exists_and_readable() {
    if [[ -z "${site_config[root]:-}" ]]; then
        app::error::error 'Site root is not set'
    fi

    if [[ ! -d "${site_config[root]}" ]]; then
        app::error::error "Site root not exists or not a directory: ${site_config[root]}"
    fi

    if [[ ! -r "${site_config[root]}" ]]; then
        app::error::error "Site root not exists or not readable: ${site_config[root]}"
    fi
}
