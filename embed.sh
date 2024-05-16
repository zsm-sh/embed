#!/usr/bin/env bash
# {{{ source ../vendor/std/src/log/error.sh
#!/usr/bin/env bash
# {{{ source ../vendor/std/src/runtime/stack_trace.sh
#!/usr/bin/env bash
function runtime::stack_trace() {
    local i=${1:-0}
    while caller $i; do
        ((i++))
    done | awk '{print  "[" NR "] " $3 ":" $1 " " $2}'
}
# }}} source ../vendor/std/src/runtime/stack_trace.sh
# Print error message and stack trace to stderr with timestamp
function log::error() {
    echo "[$(date +%Y-%m-%dT%H:%M:%S%z)] ERROR ${*}" >&2
    runtime::stack_trace 1 >&2
}
# }}} source ../vendor/std/src/log/error.sh
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
# Replace source
function replace_source() {
    local rel_file="${1}"
    local rel_root_file="${2}"
    sed "s#\${BASH_SOURCE\[0]}#${rel_file}#g" | sed "s#\${0}#${rel_root_file}#g" | sed "s#\$0#${rel_root_file}#g"
}
# Get realpath path
function realpath_path() {
    local file="${1}"
    if [[ "${file}" == "/"* && "${file}" != *"/../"* && "${file}" != *"/./"* ]]; then
        echo "${file}"
        return
    fi
    file="$(
        cd "$(dirname "${file}")"
        pwd -P
    )/$(basename "${file}")"
    echo "${file}"
}
# Get common path
function common_path() {
    local path1="$1"
    local path2="$2"
    IFS='/' read -ra ADDR1 <<<"${path1}"
    IFS='/' read -ra ADDR2 <<<"${path2}"
    local common_path=""
    for ((i = 0; i < ${#ADDR1[@]}; i++)); do
        if [[ "${ADDR1[i]}" != "${ADDR2[i]}" ]]; then
            break
        fi
        if [[ "${ADDR1[i]}" == "" ]]; then
            continue
        fi
        common_path="${common_path}/${ADDR1[i]}"
    done
    echo "${common_path}"
}
# Get relative path to current path
function relative_to() {
    local file="${1}"
    local current="${2}"
    local common
    file="$(realpath_path "${file}")"
    current="$(realpath_path "${current}")"
    if [[ "${file}" == "${current}/"* ]]; then
        echo "${file#"${current}/"}"
        return
    fi
    common="$(common_path "${file}" "${current}")"
    local out
    out="${file}"
    out="${out#"${common}/"}"
    local current_path="${file}"
    local new_current_path=""
    while [[ "${new_current_path}" != "${current_path}" ]]; do
        current_path="${new_current_path}"
        new_current_path="$(dirname "${current_path}")"
        out="../${out}"
    done
    echo "${out#..\/}"
}
# Embed source file
function embed_source() {
    local file="${1}"
    local root_file="${2}"
    local current="${3}"
    local once="${4}"
    local content
    local rel_file
    local rel_root_file
    local raw_embed_row
    local embed_row
    content="$(cat "${file}")"
    rel_file="$(relative_to "${file}" "${current}")"
    rel_root_file="$(relative_to "${root_file}" "${current}")"
    for line in ${content}; do
        # Skip comments
        if [[ "${line}" =~ ^'\s*#' ]]; then
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
            raw_embed_row="$(realpath_path "${current}/${raw_embed_row}")"
        fi
        embed_row="$(relative_to "${raw_embed_row}" "${current}")"
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
    file="$(realpath_path "${file}")"
    dir="$(dirname "${file}")"
    IFS=$'\n' embed_source "${file}" "${file}" "${dir}" "${once}"
    echo
    echo "#"
    for key in ${!EMBEDDED[*]}; do
        echo "# ${key} is quoted by ${EMBEDDED[${key}]}"
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
        echo "  --once=true   Embed source file once once for same source file."
        echo "                This behavior is different from the default source behavior,"
        echo "                no repeated Source for multiple times."
        echo "                default: true"
        echo
        echo "Example:"
        echo "  ${0} src/test.sh"
        echo "  ${0} src/test.sh > dist/test.sh"
        echo
        exit 1
    }
    function main() {
        local once=true
        local args=()
        while [[ $# -gt 0 ]]; do
            key="$1"
            case ${key} in
            --once | --once=*)
                [[ "${key#*=}" != "${key}" ]] && once="${key#*=}" || { once="$2" && shift; }
                ;;
            --help | -h)
                usage
                exit 0
                ;;
            *)
                if [[ "${key}" =~ ^- ]]; then
                    log::error "Unknown flag: ${key}"
                    usage
                    exit 1
                fi
                if [[ ! -f "${key}" ]]; then
                    log::error "File not found: ${key}"
                    exit 1
                fi
                args+=("${key}")
                ;;
            esac
            shift
        done
        if [[ ${#args[@]} -eq 0 ]]; then
            log::error "Missing file"
            usage
        elif [[ ${#args[@]} -gt 1 ]]; then
            log::error "Too many files"
            usage
        fi
        embed_file "${key}" "${once}"
    }
    main "$@"
fi

#
# ../vendor/std/src/runtime/stack_trace.sh is quoted by ../vendor/std/src/log/error.sh
# ../vendor/std/src/log/error.sh is quoted by embed.sh
