app::use 'error'
app::use 'plugin'
app::use 'util'

app::site::load_site_config() {
    if [[ $# -eq 0 ]]; then
        app::error::error "${FUNCNAME}: site path required"
    fi

    app::site::load_main_config "${1}"

    app::site::load_plugin_config

    app::site::load_local_config
}

app::site::load_main_config() {
    local site_path="${1}"

    if ! [[ -e "${site_path}" ]]; then
        app::error::error "Site root or config file not exist: ${site_path}"
    fi

    site_path="$(app::util::realpath "${site_path}")"

    site_config[local_config_pattern]='*.jimbo.conf'
    site_config[database_dump_suffix]='-dump.sql'

    if [[ -d "${site_path}" ]]; then
        site_config[root]="${site_path}"

        return
    fi

    if ! [[ -r "${site_path}" ]]; then
        app::error::error "${site_path}: is not readable"
    fi

    site_config[base_config_file]="${site_path}"
    app::site::load_config "${site_path}" 'main' < "${site_path}"

    if [[ -z "${site_config[root]:-}" ]]; then
        app::error::error "${site_path}: site root is not set"
    fi

    local base_config_dir="${PWD}"

    if [[ -f "${site_path}" ]]; then
        base_config_dir="$(dirname "${site_path}")"
    fi

    site_config[root]="$(cd "${base_config_dir}" && app::util::realpath -qm "${site_config[root]}")"
}

app::site::load_plugin_config() {
    if [[ -v 'site_config[plugin_config]' ]]; then
        app::error::error "Plugin already loaded: ${site_config[plugin]:-}"
    fi

    app::site::check_site_root_exists_and_readable

    local plugin="${site_config[plugin]:-}"
    local plugin_config=''

    if [[ -z "${plugin}" ]]; then
        local plg=''
        local plg_config=''

        for plg in $(app::plugin::plugins_list); do
            if plg_config="$(cd "${site_config[root]}" && "${plg}")"; then
                plugin="${plg}"
                plugin_config="${plg_config}"

                break
            fi
        done

        [[ -z "${plugin}" ]] && plugin='default'

    elif [[ ! "${plugin}" == default ]]; then
        if ! plugin_config="$(cd "${site_config[root]}" && "${plugin}")"; then
            app::error::error "Error occured while loading plugin: ${plugin}"
        fi
    fi

    site_config[plugin]="${plugin}"
    site_config[plugin_name]="${plugin##*/}"
    site_config[plugin_config]="${plugin_config}"

    if [[ -n "${plugin_config}" ]]; then
        app::site::load_config "${plugin}" 'plugin' <<<"${plugin_config}"
    fi
}

app::site::load_local_config() {
    [[ -z "${site_config[local_config_pattern]}" ]] && return

    app::site::check_site_root_exists_and_readable

    local -a config_files=("${site_config[root]}"/${site_config[local_config_pattern]})

    [[ "${#config_files[@]}" -eq 0 ]] && return

    if [[ "${#config_files[@]}" -gt 1 ]]; then
        app::error::error "Multiple site config files found: ${config_files[*]}"
    fi

    site_config[local_config_file]="$(app::util::realpath "${config_files[0]}")"

    app::site::load_config "${site_config[local_config_file]}" 'local' < "${site_config[local_config_file]}"
}

app::site::load_config() {
    local src="${1}"
    local context="${2}"

    while IFS=': ' read -r key value; do
        case "${key}" in
            root )
                [[ "${context}" != 'main' ]] && app::error::error \
                    "${src}: key \"${key}\" allowed only in main config file"

                site_config[root]="${value}"
                ;;
            plugin )
                [[ "${context}" != 'main' ]] && app::error::error \
                    "${src}: key \"${key}\" allowed only in main config file"

                site_config[plugin]="${value}"
                ;;
            plugin_name )
                [[ "${context}" != 'plugin' ]] && app::error::error \
                    "${src}: key \"${key}\" allowed only for plugins"

                site_config[plugin_name]="${value}"
                ;;
            local_config_pattern )
                [[ "${context}" == 'local' ]] && app::error::error \
                    "${src}: key \"${key}\" not allowed in local config file"

                site_config[local_config_pattern]="${value}"
                ;;
            exclude )
                site_config[exclude]+="${site_config[exclude]:+ }${value}"
                ;;
            include )
                site_config[include]+="${site_config[include]:+ }${value}"
                ;;
            database_name )
                site_config[database_name]="${value}"
                ;;
            database_user )
                site_config[database_user]="${value}"
                ;;
            database_password )
                site_config[database_password]="${value}"
                ;;
            database_dump_suffix )
                site_config[database_dump_suffix]="${value}"
                ;;
            ''|'#' )
                continue
                ;;
            * )
                app::error::error "${src}: invalid key: ${key}"
                ;;
        esac
    done
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
