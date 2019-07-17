function sfpm_index_lock() {
    local hostname=$(hostname)
    local lockfile=${sfpm_pkgdir}/.LOCK

    if [[ -f ${lockfile} ]]; then
        local lockhost=$(awk -F':' '{ print $1 }' ${lockfile})
        local lockpid=$(awk -F':' '{ print $2 }' ${lockfile})

        if [[ ! ${lockhost} ]] || [[ ! ${lockpid} ]]; then
            msg_error "Invalid lock file detected (contents follow):"
            msg_error "---- BEGIN ----" "$(cat ${lockfile})" "---- END ----"
            exit 1
        fi

        msg_warn "Index locked by ${lockhost} with PID ${lockpid}" \
                 "Waiting for lock to clear..."

        if [[ ${lockhost} == ${hostname} ]]; then
            if ps -e ${lockpid} > /dev/null; then
                msg_warn "PID on host is dead" \
                         "Removing stale lock"
                sfpm_index_unlock
            fi
        fi

        while true
        do
            [[ ! -f ${lockfile} ]] && break
            sleep 1
        done
    fi

    # Lock file format:
    #   hostname.domain.tld:1234
    echo "${hostname}:$$" > ${lockfile}
}


function sfpm_index_unlock() {
    rm -f ${sfpm_pkgdir}/.LOCK
}


function sfpm_index_create() {
    local index="${sfpm_pkgdir}/.SFPM-INDEX"

    msg "Creating package index"
    sfpm_index_lock
    > ${index}

    msg2 "Indexing"
    # Aggregate list of packages, excluding hidden files
    local pkgs=$(find ${sfpm_pkgdir} -type f -not -name '.*' 2>/dev/null)

    for pkg in ${pkgs}
    do
        local tarball=$(basename ${pkg})
        local no_ext=${tarball%%.[tTzZ]*}
        local result=$(echo ${no_ext} | awk -F'-' '{ printf "%s,%s,%s\n", $1, $2, $3 }')

        msg3 "${tarball}"
        echo "${tarball},${result}" >> "${index}"
    done

    msg2 "Ordering index"
    tmpfile=$(mktemp ${TMPDIR}/sfpm.index.sorted.XXXXXX)
    sort -n "${index}" > ${tmpfile}
    mv "${tmpfile}" "${index}"

    sfpm_index_unlock
}

# Sometimes it's just easier...
# https://stackoverflow.com/questions/229551/how-to-check-if-a-string-contains-a-substring-in-bash#229585
has_substr() { [ -z "${2##*$1*}" ] && { [ -z "$1" ] || [ -n "$2" ] ;} ; }

function sfpm_index_search() {
    local index="${sfpm_pkgdir}/.SFPM-INDEX"
    local name="${1}"  # required
    local version="${2}"  # optional
    local release="${3}"  # optional

    if [[ ! ${2} ]]; then
        verison=
    fi

    if [[ ! ${3} ]]; then
        release=
    fi

    # TODO: Rewrite this... barf
    local result=
    while read line
    do
        pkg_tarball=$(echo ${line} | awk -F',' '{ print $1 }')
        pkg_name=$(echo ${line} | awk -F',' '{ print $2 }')
        pkg_version=$(echo ${line} | awk -F',' '{ print $3 }')
        pkg_release=$(echo ${line} | awk -F',' '{ print $4 }')

        if has_substr "${name}" "${pkg_name}"; then
            found_name=1
        fi

        if (( ${found_name} )); then
            if has_substr "${version}" "${pkg_version}"; then
                found_version=1
            fi

            if has_substr "${release}" "${pkg_release}"; then
                found_release=1  # Barely...
            fi

            if (( ${found_name} )); then
                if [[ ${version} ]] && ! (( ${found_version} )); then
                    continue
                fi

                if [[ ${release} ]] && ! (( ${found_release} )); then
                    continue;
                fi

                result=$(sfpm_package_exists "${pkg_tarball}")
                break
            fi
        fi
    done < "${index}"
    echo "${result}"
}

