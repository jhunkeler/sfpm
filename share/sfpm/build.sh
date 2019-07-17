required_keys=(
    name
    version
    release
)

function sfpm_CPUS() {
    local count=$(getconf _NPROCESSORS_ONLN)

    ((count--))
    if (( ${count} <= 0 )); then
        count=1
    fi

    echo ${count}
}

function sfpm_gen_srcdir() {
    local path="${sfpm_srcdir}/${name}-${version}-${release}"
    if [[ ! -d ${path} ]]; then
        mkdir -p ${path}
    fi
    echo ${path}
}


function sfpm_rm_srcdir() {
    local path="${sfpm_srcdir}/${name}-${version}-${release}"
    if [[ -d ${path} ]]; then
        rm -rf "${path}"
    fi
}


function sfpm_check_required_keys() {
    die=0
    for key in "${required_keys[@]}"
    do
        if [[ ! ${!key} ]]; then
            msg_error "Package '${key}' undefined!"
            die=1
        fi
    done

    if (( ${die} )); then
        exit 1
    fi
}


function sfpm_cmp_sha256() {
    # is a FILE
    local sum_file="${1}"
    if [[ ! -f ${sum_file} ]]; then
        msg_error "${sum_file} is not a file"
        exit 1
    fi

    # sha256 hashes
    local sum_left=$(sha256sum ${sum_file} | awk '{ print $1 }')
    local sum_right="${2}"

    # compare hashes
    if [[ ${sum_left} != ${sum_right} ]]; then
        return 1
    fi

    return 0
}

function sfpm_verify_gpg() {
    msg_warn "sfpm_verify_gpg(): Not implemented"
}

function prepare() {
    msg_warn "prepare() function undefined"
}


function build() {
    msg_warn "build() function undefined"
}

function check() {
    msg_warn "check() function undefined"
}

function package() {
    msg_error "package() function undefined"
    exit 1
}


function sources_fetch() {
    local path=$(sfpm_gen_srcdir)
    for src in "${sources[@]}"
    do
        fetch --checksum --skip-exists --redirect --output ${path} ${src}
    done
}


function sources_extract() {
    local destdir="${1}"
    if [[ ! ${destdir} ]]; then
        msg_error "sources_extract() destination undefined: ${destdir}"
        exit 1
    fi

    if [[ ! -d ${destdir} ]]; then
        mkdir -p "${destdir}"
    fi

    local srcdir="$(sfpm_gen_srcdir)"
    if [[ ! -d ${srcdir} ]]; then
        msg_error "${srcdir} does not exist!"
        exit 1
    fi

    archives_tar=$(find ${srcdir} -maxdepth 1 -type f \( -name "*.tar*" -o -name "*.t*" \) -and -not -name "*.sha256")
    archives_zip=$(find ${srcdir} -maxdepth 1 -type f \( -name "*.zip" \) -and -not -name "*.sha256")

    msg2 "Extracting"
    pushd "${srcdir}"
        if [[ ${archives_tar} ]]; then
            for archive in ${archives_tar}
            do
                msg3 "${archive}"
                tar xf "${archive}" -C "${destdir}"
            done
        fi

        if [[ ${archives_zip} ]]; then
            for archive in ${archives_zip}
            do
                msg3 "${archive}"
                unzip "${archive}" -d "${destdir}"
            done
        fi
    popd
}


function sfpm_sources_cmp_sha256() {
    source_count=${#sources[@]}
    sha256_count=${#sha256sums[@]}

    if (( ! ${sha256_count} )); then
        return 0
    fi

    msg2 "Comparing sha256 checksums"
    if [[ ${source_count} != ${sha256_count} ]]; then
        msg_error "Total sources (${source_count}) does not match total of hashes (${sha256_count})" \
                  "HINT: Place 'null' for each source without a hash."
        exit 1
    fi

    for url in "${sources[@]}"
    do
        for sha in "${sha256sums[@]}"
        do
            if [[ ${sha} == null ]] || [[ ${sha} == NULL ]]; then
                continue
            fi

            archive="${sfpm_srcdir}/${name}-${version}-${release}/$(basename ${url})"
            sfpm_cmp_sha256 ${archive} ${sha}
            if (( ${?} )); then
                msg_error "${sha} does not match $(basename ${archive})"
                exit 1
            fi
        done
    done
}

function sfpm_gen_buildroot() {
    export buildroot=$(mktemp -d ${TMPDIR}/sfpm.buildroot.XXXXXX)
    if [[ ! -d ${buildroot} ]]; then
        msg_error "Failed to create buildroot: ${buildroot}"
        exit 1
    fi

    echo ${buildroot}
}


function sfpm_rm_buildroot() {
    if [[ ${buildroot} == *${sfpm_tmpdir}* ]]; then
        msg "Removing ${buildroot}"
        rm -rf "${buildroot}"
    fi
}

function sfpm_build_env_do_depends() {
    local env_name="${1}"
    if [[ ${depends} ]]; then
        for dep in "${depends[@]}"
        do
            local pkg=$(sfpm_index_search ${dep})
            sfpm_install "${env_name}" "${pkg}"
        done
    fi
}

function sfpm_gen_package_manifest() {
    pushd "${pkgdir}"
        find . -type f -not -name ".SFPM-*" | xargs -I'{}' sha256sum "{}" > .SFPM-MANIFEST
    popd
}


# Don't use this. Getting rid of it.
function sfpm_gen_package_sizes() {
    pushd "${pkgdir}"
        find . -type f -not -name ".SFPM-*" | xargs -I'{}' -n1 du -b "{}" > .SFPM-SIZES
    popd
}

function sfpm_gen_package_depends_manifest() {
    pushd "${pkgdir}"
        >.SFPM-DEPENDS
        for dep in "${depends[@]}"
        do
            echo "${dep}" >> .SFPM-DEPENDS
        done
    popd
}

function sfpm_gen_package_rpath() {
    pushd "${pkgdir}"
        local rpath_orig
        local rpath_new
        local rpath_cache="$(mktemp ${TMPDIR}/sfpm.rpath_cache.XXXXXX)"

        # Assimilate all file paths that contain an RPATH
        for path in $(find . -type f -not -name '.SFPM-*')
        do
            readelf -d "${path}" 2>/dev/null | grep RPATH &>/dev/null
            if (( $? )); then
                continue
            fi
            echo "${path}" >> "${rpath_cache}"
        done

        msg2 "Adjusting depth of RPATHs"
        while read line
        do
            rpath_orig="$(readelf -d ${line} | grep RPATH | awk -F'[][]' '{ print $2 }')"
            rpath_new='$ORIGIN/'"$(sfpm_rpath_nearest ${line})"
            msg3 "${line}: ${rpath_orig} -> ${rpath_new}"
            patchelf --set-rpath "${rpath_new}" "${line}"
        done < "${rpath_cache}"
        [[ -f "${rpath_cache}" ]] && rm -f "${rpath_cache}"
    popd
}

function sfpm_gen_package_prefixes() {
    msg "Generating build prefix manifest"
    pushd "${pkgdir}"
        # Create record files
        >.SFPM-PREFIX-TEXT
        >.SFPM-PREFIX-BIN

        # Assimilate file path for anything containing our prefix
        local count_text=0
        local count_bin=0
        local count_total=0

        for path in $(find . -type f -not -name ".SFPM-*")
        do
            # Check for prefix
            grep -l "${sfpm_build_prefix}" "${path}" &>/dev/null

            # Prefix present? (0: yes, 1: no)
            if (( $? )); then
                continue
            fi

            # Get file type
            local mimetype="$(file -i ${path} | awk -F': ' '{ print $2 }')"
            local outfile

            # Record prefix data
            if [[ ${mimetype} = *text/* ]]; then
                outfile=.SFPM-PREFIX-TEXT
                (( count_text++ ))
            else
                outfile=.SFPM-PREFIX-BIN
                (( count_bin++ ))
            fi

            echo "${path}" >> "${outfile}"

        done

        count_total=$(( count_text + count_bin ))
        if (( ${count_total} )); then
            msg2 "Text: ${count_text}"
            msg2 "Binary: ${count_bin}"
            msg2 "Total: ${count_total}"
        else
            msg2 "No prefixes detected"
        fi
    popd
}

function sfpm_gen_packages() {
    local funcs=$(compgen -A function | grep ^package)
    local name_old="${name}"
    local pkgdir_old="${pkgdir}"
    for fn in ${funcs}
    do
        # Don't modify main package() behavior
        if [[ ${fn} != package ]]; then
            name=${fn#package_}
            pkgdir_child=$(mktemp -d ${TMPDIR}/sfpm.pkgdir_child.XXXXXX)
            pkgdir="${pkgdir_child}"
        fi

        ${fn}
        sfpm_gen_package

        if [[ -d ${pkgdir_child} ]]; then
            rm -rf "${pkgdir_child}"
            name="${name_old}"
            pkgdir="${pkgdir_old}"
        fi
    done
}

function sfpm_gen_package() {
    if [[ ! ${sfpm_build_scriptdir} ]]; then
        msg_error "Refusing to generate package outside of sfpm_makepkg"
        exit 1
    fi

    archive=${name}-${version}-${release}.tar.bz2
    pushd "${pkgdir}"
        msg "Generating ${archive}"
        sfpm_gen_package_manifest
        sfpm_gen_package_depends_manifest
        sfpm_gen_package_prefixes
        sfpm_gen_package_rpath
        tar cfj "${sfpm_build_scriptdir}/${archive}" .SFPM-* *
    popd
}
