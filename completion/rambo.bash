# bash completion for rambo                    -*- shell-script -*-
#
# User install:   ~/.local/share/bash-completion/completions/rambo
# System install: /usr/share/bash-completion/completions/rambo
#
# Without bash-completion just source this file from ~/.bashrc.

declare -g _rambo_fallback_commands='backup db:cli db:dump detect help plugins restore'

# Parent of the bin directory containing the rambo executable being completed.
_rambo_root_dir() {
    local bin

    bin=$(type -P -- "${COMP_WORDS[0]:-rambo}") || return 1
    # Resolve symlinks (bin/rambo is usually linked from ~/.local/bin).
    bin=$(readlink -f -- "${bin}" 2>/dev/null || printf '%s' "${bin}")

    printf '%s\n' "$(dirname -- "$(dirname -- "${bin}")")"
}

_rambo_commands() {
    local root dir cmd

    root=$(_rambo_root_dir) || return 1
    dir="${root}/command"

    if [[ -d "${dir}" ]]; then
        for cmd in "${dir}"/*; do
            if [[ -f "${cmd}" && -x "${cmd}" ]]; then
                printf '%s\n' "${cmd##*/}"
            fi
        done
    fi

    return 0
}

_rambo_command_list() {
    local commands

    commands=$(_rambo_commands)

    if [[ -z "${commands}" ]]; then
        commands="${_rambo_fallback_commands}"
    fi

    printf '%s' "${commands}"
}

_rambo_options() {
    case "${1}" in
    backup | restore | db:dump | db:cli) printf '%s' '-h --help' ;;
    detect) printf '%s' '-p --show-password -h --help' ;;
    plugins) printf '%s' '-a --all -p --paths -h --help' ;;
    '') printf '%s' '-h --help' ;;
    esac
}

_rambo_complete_path() {
    mapfile -t COMPREPLY < <(compgen -f -- "${1}")

    compopt -o filenames 2>/dev/null || true
}

_rambo_complete_zip() {
    local file
    local -a matches=()

    # Directories stay (so the user can descend); files must end in .zip.
    while IFS= read -r file; do
        if [[ -d "${file}" || "${file}" == *.zip ]]; then
            matches+=("${file}")
        fi
    done < <(compgen -f -- "${1}")

    COMPREPLY=("${matches[@]}")

    compopt -o filenames 2>/dev/null || true
}

# Readline splits words on every character in COMP_WORDBREAKS, including ":".
# It replaces only the part after the last break, so replies for "db:" must be
# trimmed back to the part after that colon or "db:dump" turns into
# "db:db:dump".
_rambo_complete_trim_colon() {
    local cur="${1}" colon_word i

    [[ "${COMP_WORDBREAKS}" == *:* && "${cur}" == *:* ]] || return 0

    colon_word="${cur%${cur##*:}}"

    for i in "${!COMPREPLY[@]}"; do
        COMPREPLY[i]="${COMPREPLY[i]#"${colon_word}"}"
    done
}

_rambo() {
    local char cmd cur i idx line noopts opts quote word
    local -a positional=() words=()
    noopts=false

    COMPREPLY=()

    line="${COMP_LINE:0:COMP_POINT}"
    word=''
    quote=''

    # Split the line on whitespace only (not COMP_WORDBREAKS, which would cut
    # command names like "db:dump" apart) and keep quotes out of the words.
    for ((i = 0; i < ${#line}; i++)); do
        char="${line:i:1}"

        if [[ -n "${quote}" ]]; then
            if [[ "${char}" == "${quote}" ]]; then
                quote=''
            else
                word+="${char}"
            fi
        else
            case "${char}" in
            "'" | '"') quote="${char}" ;;
            '\')
                i=$((i + 1))
                word+="${line:i:1}"
                ;;
            ' ' | $'\t')
                if [[ -n "${word}" ]]; then
                    words+=("${word}")
                    word=''
                fi
                ;;
            *) word+="${char}" ;;
            esac
        fi
    done

    words+=("${word}")

    if [[ "${#words[@]}" -eq 0 ]]; then
        return
    fi

    cur="${words[${#words[@]} - 1]}"
    cmd=''

    # Everything but the program name and the word under the cursor.
    for ((idx = 1; idx < ${#words[@]} - 1; idx++)); do
        word="${words[idx]}"

        if [[ "${word}" == '--' && "${noopts}" == 'false' ]]; then
            noopts=true

            continue
        fi

        # Options are never positional arguments.
        if [[ "${noopts}" == 'false' && "${word}" == -* ]]; then
            continue
        fi

        if [[ -z "${cmd}" ]]; then
            cmd="${word}"
        else
            positional+=("${word}")
        fi
    done

    if [[ "${noopts}" == 'false' && "${cur}" == -* ]]; then
        opts=$(_rambo_options "${cmd}")

        if [[ -n "${opts}" ]]; then
            mapfile -t COMPREPLY < <(compgen -W "${opts}" -- "${cur}")
        fi

        return 0
    fi

    case "${cmd}" in
    '')
        mapfile -t COMPREPLY < <(compgen -W "$(_rambo_command_list)" -- "${cur}")
        ;;
    backup | restore)
        case "${#positional[@]}" in
        0) _rambo_complete_path "${cur}" ;;
        1)
            if [[ "${cmd}" == 'restore' ]]; then
                _rambo_complete_zip "${cur}"
            else
                _rambo_complete_path "${cur}"
            fi
            ;;
        esac
        ;;
    detect | db:dump | db:cli)
        [[ "${#positional[@]}" -eq 0 ]] && _rambo_complete_path "${cur}"
        ;;
    help)
        [[ "${#positional[@]}" -eq 0 ]] && mapfile -t COMPREPLY < <(compgen -W "$(_rambo_command_list)" -- "${cur}")
        ;;
    esac

    _rambo_complete_trim_colon "${cur}"
}

complete -F _rambo rambo
