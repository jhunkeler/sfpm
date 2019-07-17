function sfpm_env_exists() {
    # Returns empty string on failure (implicit)
    local name="${1}"
    if [[ ! ${name} ]]; then
        msg_error "sfpm_env_exists(): missing environment name"
        exit 1
    fi

    local path="${sfpm_envdir}/${name}"
    if [[ ! -d ${path} ]]; then
        return 1
    fi
    echo ${path}
}


function sfpm_env_create() {
    local name="${1}"
    local path="${sfpm_envdir}/${name}"
    if [[ ! $(sfpm_env_exists ${name}) ]]; then
        msg "Creating environment root: ${name}"
        sfpm_gen_sysroot "${path}"
    fi

    if [[ ! -f ${path}/bin/activate ]]; then
        sed -e "s|__SFPM_ENV__|${path}|g" \
            ${sfpm_sysconfdir}/sfpm.activate.sh > ${path}/bin/activate
    fi

}


function sfpm_env_remove() {
    local name="${1}"
    local path="${sfpm_envdir}/${name}"
    if [[ $(sfpm_env_exists ${name}) ]]; then
        msg "Removing environment root: ${name}"
        rm -rf "${path}"
    fi
}

function sfpm_rpath_nearest() {
    local cwd="$(pwd)"
    local start=$(dirname $(sfpm_abspath ${1}))
    local result=

    # Jump to location of file
    cd "$(dirname ${start})"

    # Scan upward until we find a "lib" directory
    # OR when:
    # - Top of filesystem is reached (pretty much total failure [missing local dep])
    # - Top of active environment is reached (post installation)
    # - Top of default installation prefix is reached (during packaging)
    while [[ $(pwd) != / ]]
    do
        result+="../"
        if [[ -d lib ]] || [[ $(pwd) == ${SFPM_ENV} ]] || [[ $(pwd) == *${sfpm_build_prefix} ]]; then
            result+="lib"
            break
        fi
        cd ..
    done

    # Sanitize: removing double-slashes (if any)
    result=${result/\/\//\/}

    # Return to where we were instantiated
    cd "${cwd}"

    echo "${result}"
}


function sfpm_install() {
    local env_name="${1}"
    local env_path=$(sfpm_env_exists "${env_name}")
    local pkg_name="${2}"
    local pkg_version="${3}"
    local pkg_release="${4}"
    local pkg="${pkg_name}-${pkg_version}-${pkg_release}"
    local pkg_path
    local metadata
    local staging
    local have_prefix_text
    local have_prefix_bin

    msg "Installing ${pkg_name} [env: ${env_name}]"
    if [[ ! ${env_path} ]]; then
        msg_error "sfpm_install(): Environment does not exist: ${env_name}"
        exit 1
    fi

    if [[ ${pkg_name} == */*.tar.bz2 ]]; then
        pkg_path="${pkg_name}"
    else
        pkg_path=$(sfpm_package_exists "${pkg}.tar.bz2")
    fi

    if [[ ! -f ${pkg_path} ]]; then
        msg_error "sfpm_install(): Package does not exist: ${pkg}"
        exit 1
    fi


    msg2 "Extracting metadata"
    metadata=$(mktemp -d ${TMPDIR}/sfpm.metadata.XXXXXX)
    tar -xf "${pkg_path}" \
        -C "${metadata}" \
        --wildcards "\.SFPM-*"

    msg2 "Extracting package"
    staging=$(mktemp -d ${TMPDIR}/sfpm.staging.XXXXXX)
    tar -xf "${pkg_path}" \
        -C "${staging}" \
        --strip-components=1 \
        --wildcards "${sfpm_build_prefix/\//}*"

    have_prefix_text=$(wc -l ${metadata}/.SFPM-PREFIX-TEXT | cut -d ' ' -f 1)
    if [[ ${have_prefix_text} != 0 ]]; then
        msg2 "Relocating text paths"
        while read filename
        do
            msg3 "${filename}"
            sfpm_file_relocate --text --env "${env_name}" --path "${filename}"
        done < <(sed -e "s|.${sfpm_build_prefix}|${staging}|g" "${metadata}/.SFPM-PREFIX-TEXT")
    fi

    # TODO: Not implemented
    #have_prefix_bin=$(wc -l ${metadata}/.SFPM-PREFIX-BIN | cut -d ' ' -f 1)
    #if [[ ${have_prefix_bin} != 0 ]]; then
    #    msg2 "Relocating binary paths"
    #    while read filename
    #    do
    #        msg3 "${filename}"
    #        sfpm_file_relocate --bin --env "${env_name}" --path "${filename}"
    #    done < <(sed -e "s|.${sfpm_build_prefix}|${staging}|g" "${metadata}/.SFPM-PREFIX-BIN")
    #fi
    rsync -a "${staging}/" "${env_path}"

    rm -rf "${staging}"
    rm -rf "${metadata}"
}


function sfpm_file_relocate() {
    # TODO: binary relocation
    # easy peasy... already wrote sfpm_rpath_nearest()
    #local env_name="${1}"
    #local env_path=$(sfpm_env_exists "${env_name}")
    #local path="${2}"

    local path
    local env_name
    local mode_text=0
    local mode_bin=0

    while (( "${#}" )); do
        case "${1}" in
            -t|--text)
                mode_text=1
                shift
                ;;
            -b|--bin)
                # TODO: Not implemented
                mode_bin=1
                shift
                ;;
            -e|--env)
                env_name="${2}"
                shift 2
                ;;
            -p|--path)
                path="${2}"
                shift 2
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
                # do nothing with positional args
                shift
                ;;
        esac
    done

    if (( ${mode_text} )) && (( ${mode_bin} )); then
        msg_error "-t/--text and -b/--bin are mutually exclusive arguments"
        exit 1
    fi

    local env_path=$(sfpm_env_exists "${env_name}")
    if [[ ! ${env_path} ]]; then
        msg_error "sfpm_file_relocate(): Environment does not exist: ${env_name}"
        exit 1
    fi

    if [[ ! -f ${path} ]] && [[ ! -L ${path} ]]; then
        msg_warn "sfpm_file_relocate(): ${path}: not a file or symbolic link"
        return 1
    fi

    tmpfile=$(mktemp ${TMPDIR}/sfpm.relocate.XXXXXX)
    if [[ ! -f ${tmpfile} ]]; then
        msg_error "sfpm_file_relocate(): Failed to create temporary relocation file."
        exit 1
    fi

    filemode=$(stat -c '%a' "${path}")
    if (( ${mode_text} )); then
        sed -e "s|${sfpm_build_prefix}|${env_path}|g" < "${path}" > "${tmpfile}"
    elif (( ${mode_bin} )); then
        # TODO
        :
    else
        msg_error "sfpm_file_relocate(): Invalid modification mode. --text nor --bin specified"
        exit 1
    fi

    chmod ${filemode} "${tmpfile}"
    mv "${tmpfile}" "${path}"

    if (( $? )); then
        msg_error "sfpm_file_relocate(): Failed to move temporary relocation file. Purging."
        rm -f "${tmpfile}"
    fi
}

