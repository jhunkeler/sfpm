# Override default directory stack output behavior
pushd () {
    command pushd "$@" > /dev/null
}

popd () {
    command popd "$@" > /dev/null
}

sfpm_root="$(readlink -f $(dirname ${BASH_SOURCE[0]})/../..)"
sfpm_internal_include=${sfpm_root}/share/sfpm
source ${sfpm_internal_include}/msg.sh
source ${sfpm_internal_include}/sfpm.sh
source ${sfpm_internal_include}/env.sh
source ${sfpm_internal_include}/pkg_read.sh
source ${sfpm_internal_include}/index.sh
source ${sfpm_internal_include}/download.sh
