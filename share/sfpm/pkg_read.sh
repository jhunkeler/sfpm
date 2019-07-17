function sfpm_package_exists() {
    # Returns empty string on failure (implicit)
    local path="${sfpm_pkgdir}/${1}"
    if [[ ! -f ${path} ]]; then
        return 1
    fi
    echo ${path}
}

function sfpm_package_verify() {
    local name="$(basename ${1})"
    local path="${sfpm_pkgdir}/${name}"

    if [[ ! -f $(sfpm_package_exists ${name}) ]]; then
        msg_error "sfpm_package_verify(): Package does not exist: ${path}"
        exit 1
    fi

    local vdir=$(mktemp -d ${TMPDIR}/sfpm.verify.XXXXXX)
    pushd "${vdir}"
        msg2 "Verifying Package: ${name}"
        tar -xf "${path}"

        while read line
        do
            msg3 "${line}"
        done < <(sha256sum -c .SFPM-MANIFEST)

        while read line
        do
            msg3 "${line}"
        done < <(find . -type f | xargs file | grep ELF | awk -F':' '{ print $1 }' | xargs readelf -d | grep rpath)
    popd
    if [[ -d ${vdir} ]] && [[ ${vdir} == *${TMPDIR}* ]]; then
        rm -rf "${vdir}"
    fi
}
