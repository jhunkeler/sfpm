# Dumbed down virtualenv-style activation script
deactivate (){
    if [[ ${_OLD_SFPM_PATH} ]]; then
        export PATH=${_OLD_SFPM_PATH}
        unset _OLD_SFPM_PATH
    fi

    if [[ ${_OLD_SFPM_MANPATH} ]]; then
        export MANPATH=${_OLD_SFPM_MANPATH}
        unset _OLD_SFPM_MANPATH
    fi

    if [[ ${_OLD_SFPM_INFOPATH} ]]; then
        export INFOPATH=${_OLD_SFPM_INFOPATH}
        unset _OLD_SFPM_INFOPATH
    fi

    if [[ ${_OLD_SFPM_PKG_CONFIG_PATH} ]]; then
        export PKG_CONFIG_PATH=${_OLD_PKG_CONFIG_PATH}
        unset _OLD_SFPM_PKG_CONFIG_PATH
    fi

    if [[ ${_OLD_SFPM_PS1} ]]; then
        export PS1="${_OLD_SFPM_PS1}"
        unset _OLD_SFPM_PS1
    fi

    unset SFPM_ENV
    if [[ ${1} != nondestructive ]]; then
        unset -f deactivate
    fi

    hash -r 2>/dev/null
}

deactivate nondestructive

export SFPM_ENV="__SFPM_ENV__"

export _OLD_SFPM_PATH="${PATH}"
export PATH="${SFPM_ENV}/bin:${PATH}"

export _OLD_SFPM_MANPATH="${MANPATH}"
export MANPATH="${SFPM_ENV}/share/man:${MANPATH}"

export _OLD_SFPM_INFOPATH="${INFOPATH}"
export INFOPATH="${SFPM_ENV}/share/info:${INFOPATH}"

export _OLD_SFPM_PKG_CONFIG_PATH="${PKG_CONFIG_PATH}"
export PKG_CONFIG_PATH="${SFPM_ENV}/lib/pkgconfig:${PKG_CONFIG_PATH}"

export _OLD_SFPM_PS1="${PS1}"
export PS1="($(basename ${SFPM_ENV})) ${PS1}"

hash -r 2>/dev/null
