# Prints path of the command executable if it exists.
app::command::find_executable() {
    local executable="${app_commands_path}/${1}"

    [[ -f "${executable}" ]] && echo "${executable}"
}

# Prints sorted names of available commands.
app::command::commands_list() {
    for cmd in "${app_commands_path}/"*; do
        echo "${cmd##*/}"
    done | sort
}
