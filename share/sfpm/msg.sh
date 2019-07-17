function _msg() {
    printf "$@"
}

function plain() {
    _msg "    %s\n" "$@"
}

function msg() {
    _msg "==> %s\n" "$@"
}


function msg2() {
    _msg "  -> %s\n" "$@"
}


function msg3() {
    _msg "    . %s\n" "$@"
}

function msg_error() {
    _msg "[ERROR] %s\n" "$@" >&2
}

function msg_warn() {
    _msg "[WARNING] %s\n" "$@" >&2
}
