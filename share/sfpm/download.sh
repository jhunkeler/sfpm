DOWNLOADERS=(
    curl
    wget
)


function fetch_select()
{
    # Good chance this will not be used. cURL is sufficient as it is...
    for prog in "${DOWNLOADERS[@]}"
    do
        fetcher=$(type -p ${prog})
        if [[ ${fetcher} ]]; then
            break
        fi
    done

    if [[ ! ${fetcher} ]]; then
        msg_error "Cannot continue; no program available to download files with."
        exit 1
    fi
    echo ${fetcher}
}


function fetch()
{
    args=( --fail )
    while (( "${#}" )); do
        case "${1}" in
            -r|--redirect)
                args+=( -L )
                shift
                ;;
            -O|--remote-name)
                args+=( -O )
                shift
                ;;
            -o|--output)
                output="${2}"
                shift 2
                ;;
            -s|--skip-exists)
                skip=1
                shift
                ;;
            -c|--checksum)
                checksum=1
                shift
                ;;
            --)
                shift
                break
                ;;
            -*|--*)
                msg_error "Invalid argument: ${1}" >&2
                exit 1
                ;;
            *)
                url="${1}"
                shift
                ;;
        esac
    done

    set -- "${args[@]}"

    filename="$(basename ${url})"
    msg "Fetching ${filename}"

    if [[ ${output} ]]; then
        output="${output}/${filename}"
        filename_checksum="${output}.sha256"

        if [[ -f ${filename_checksum} ]]; then
            msg2 "Verifying checksum: ${filename_checksum}"
            for line in "$(sha256sum -c ${filename_checksum})"
            do
                msg3 "${line}"
            done

            if (( $? )); then
                exit 1
            fi
        fi

        if (( ${skip} )) && [[ -f ${output} ]]; then
            msg2 "Source exists: ${output}"
            return 0
        fi
        args+=( -o ${output} )
    fi

    $(fetch_select) ${args[@]} ${url}
    fetch_retval=$?
    if (( ${fetch_retval} )); then
        msg_error "Failed to fetch: (${fetch_retval}): ${url}"
        exit 1
    fi

    if [[ ${output} ]]; then
        if (( ${checksum} )); then
            if [[ ! -f ${filename_checksum} ]]; then
                sha256sum "${output}" > "${filename_checksum}"
            fi
        fi
    fi
}

