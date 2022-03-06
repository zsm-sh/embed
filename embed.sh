#!/usr/bin/env bash

declare -A EMBEDDED

function is_true() {
    local bool="${1}"
    case "${bool}" in
    T* | t* | Y* | y* | 1 | on)
        return 0
        ;;
    F* | f* | N* | n* | 0 | off)
        return 1
        ;;
    *)
        return 2
        ;;
    esac
}

function replace_source() {
    local rel_file="${1}"
    local rel_root_file="${2}"
    sed "s#\${BASH_SOURCE\[0]}#${rel_file}#g" | sed "s#\${0}#${rel_root_file}#g" | sed "s#\${0}#${rel_root_file}#g"
}

# Embed source file
function embed_source() {
    local file="${1}"
    local root_file="${2}"
    local current="${3}"
    local once="${4:-f}"
    local content
    local rel_file
    local rel_root_file
    local raw_embed_row
    local embed_row

    content="$(cat "${file}")"
    rel_file="$(realpath "${file}" --relative-to="${current}")"
    rel_root_file="$(realpath "${root_file}" --relative-to="${current}")"

    for line in ${content}; do
        # Skip comments
        if [[ "${line}" =~ ^\s*\# ]]; then
            echo "${line}"
            continue
        fi

        # Skip not EMBEDDED source
        if ! [[ "${line}" =~ ^"source " || "${line}" =~ ^". " ]]; then
            echo "${line}"
            continue
        fi

        # Expand variables
        line="$(echo "${line}" | replace_source "${rel_file}" "${rel_root_file}")"

        # Get EMBEDDED file
        raw_embed_row="$(echo ${line#* })"
        raw_embed_row="$(eval "echo ${raw_embed_row}")"
        if [[ ! "${raw_embed_row}" =~ ^/ ]]; then
            raw_embed_row="$(realpath "${current}/${raw_embed_row}")"
        fi
        embed_row="$(realpath "${raw_embed_row}" --relative-to="${current}")"

        # Skip cannot find EMBEDDED file
        if [[ "${embed_row}" == "" ]]; then
            echo "${line} # Embed file not found"
            continue
        fi

        if [[ -v "EMBEDDED["${embed_row}"]" ]]; then
            if is_true "${once}"; then
                echo "# source ${embed_row} # Embed file already embedded by ${EMBEDDED["${embed_row}"]}"
                EMBEDDED["${embed_row}"]+=" ${rel_file}"
                continue
            else
                EMBEDDED["${embed_row}"]+=" ${rel_file}"
            fi
        else
            EMBEDDED["${embed_row}"]="${rel_file}"
        fi
        echo "# {{{ source ${embed_row}"
        embed_source "${raw_embed_row}" "${root_file}" "${current}" "${once}"
        echo "# }}} source ${embed_row}"
    done
}

# Embed source file and add header and footer
function embed_file() {
    local file="${1}"
    local once="${2}"
    local dir

    file="$(realpath "${file}")"
    dir="$(dirname "${file}")"

    IFS=$'\n'
    embed_source "${file}" "${file}" "${dir}" "${once}"
    unset IFS
    echo
    echo "#"
    for key in ${!EMBEDDED[*]}; do
        echo "# ${key} is quoted by ${EMBEDDED[$key]}"
    done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    function usage() {
        echo "Usage: ${0} [flags] <file>"
        echo
        echo "Expand source <file> and output to stdout."
        echo
        echo "Flags:"
        echo "  -h, --help    Show this help."
        echo "  --once=false  Embed source file once once for same source file."
        echo "                This behavior is different from the default source behavior,"
        echo "                no repeated Source for multiple times."
        echo "                default: false"
        echo
        echo "Example:"
        echo "  ${0} src/test.sh"
        echo "  ${0} src/test.sh > dist/test.sh"
        echo
        exit 1
    }

    function main() {
        local once

        while [[ $# -gt 0 ]]; do
            key="$1"
            case ${key} in
            --once | --once=*)
                [[ "${key#*=}" != "$key" ]] && once="${key#*=}" || { once="$2" && shift; }
                ;;

            --help | -h)
                usage
                exit 0
                ;;
            *)
                if [[ "${key}" =~ ^- ]]; then
                    echo "Unknown flag: ${key}"
                    usage
                    exit 1
                fi
                if [[ ! -f "${key}" ]]; then
                    echo "File not found: ${key}"
                    exit 1
                fi
                embed_file "${key}" "${once}"
                ;;
            esac
            shift
        done
    }

    main "$@"
fi
