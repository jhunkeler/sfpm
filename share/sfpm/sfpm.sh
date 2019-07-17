sfpm_bindir=${sfpm_root}/bin
sfpm_sbindir=${sfpm_root}/sbin
sfpm_sysconfdir=${sfpm_root}/etc
sfpm_libdir=${sfpm_root}/lib
sfpm_libexecdir=${sfpm_root}/libexec
sfpm_datarootdir=${sfpm_root}/share
sfpm_datadir=${sfpm_datarootdir} # alias for GNU sake
sfpm_docdir=${sfpm_datarootdir}/doc
sfpm_mandir=${sfpm_datadir}/man
sfpm_infodir=${sfpm_datadir}/info
sfpm_localstatedir=${sfpm_root}/var
sfpm_pkgdir=${sfpm_localstatedir}/lib/pkgs
sfpm_cache=${sfpm_localstatedir}/cache
sfpm_srcdir=${sfpm_cache}/src
sfpm_runstatedir=${sfpm_localstatedir}/run
sfpm_includedir=${sfpm_root}/include
sfpm_tmpdir=${sfpm_root}/tmp
sfpm_envdir=${sfpm_root}/envs

# Set default prefix. It happens to be the name of the variable...
sfpm_build_prefix="/sfpm_build_prefix"
sfpm_build_cflags="-I${sfpm_includedir}"
sfpm_build_ldflags="-L${sfpm_libdir} -Wl,-rpath="'\$$ORIGIN'/../lib

sfpm_INTERNAL_PATHS=(
    sfpm_root
    sfpm_bindir
    sfpm_sbindir
    sfpm_sysconfdir
    sfpm_libdir
    sfpm_libexecdir
    sfpm_datarootdir
    sfpm_datadir
    sfpm_docdir
    sfpm_mandir
    sfpm_infodir
    sfpm_localstatedir
    sfpm_pkgdir
    sfpm_cache
    sfpm_srcdir
    sfpm_runstatedir
    sfpm_includedir
    sfpm_tmpdir
    sfpm_envdir
)


export TMPDIR="${sfpm_tmpdir}"


function sfpm_abspath() {
    local filename="${1}"
    local start="$(dirname ${filename})"

    pushd "${start}" &>/dev/null
        end="$(pwd)"
    popd &>/dev/null

    if [[ -f ${filename} ]]; then
        end="${end}/$(basename ${filename})"
    fi

    echo "${end}"
}


function sfpm_gen_sysroot() {
    local env_path="${1}"

    for envpath in "${sfpm_INTERNAL_PATHS[@]}"
    do
        p="${!envpath}"

        # For environment creation, override sysroot with new root path
        if [[ ${env_path} ]]; then
            # Environments will not be chained
            if [[ ${envpath} == sfpm_envdir ]]; then
                continue
            fi
            p="${p/${sfpm_root}/${env_path}}"
        fi

        [[ ! -d ${p} ]] && mkdir -p "${p}"
    done
}



