#!/usr/bin/env bash
set -euo pipefail

LOG_DEBUG=0
LOG_INFO=1
LOG_WARN=2
LOG_ERROR=3

: "${LOG_LEVEL:=$LOG_INFO}"

# Logging levels with colors
log_debug()  { 
    if (( LOG_LEVEL <= LOG_DEBUG )); then
        echo -e "\033[1;34m[DEBUG]\033[0m $*" >&2;
    fi
}

log_info()   { 
    if (( LOG_LEVEL <= LOG_INFO )); then
         echo -e "\033[1;32m[INFO]\033[0m  $*" >&2; 
    fi
}

log_warn()   { 
    if (( LOG_LEVEL <= LOG_WARN )); then
        echo -e "\033[1;33m[WARN]\033[0m  $*" >&2;
    fi
}

log_error()  { 
    if (( LOG_LEVEL <= LOG_ERROR )); then
        echo -e "\033[1;31m[ERROR]\033[0m $*" >&2;
    fi
}

# Get the canonical absolute path to the script directory
get_script_path() {
    local src="${BASH_SOURCE[0]:-$0}"
    while [ -h "$src" ]; do
        src="$(readlink "$src")"
    done
    local dir
    dir="$(cd -P "$(dirname "$src")" && pwd)"
    
    log_debug "Found repository root at $dir."
    echo "$dir"
}

# Ensure nix-portable exists and is executable, downloading if needed
ensure_nix_portable() {
    local script_dir="$1"
    local np_bin="$script_dir/nix-portable"

    log_info "Ensuring nix-portable is available at $np_bin..."

    if [[ -L "$np_bin" ]]; then
        log_error "$np_bin is a symlink."
        return 1
    elif [[ ! -e "$np_bin" ]]; then
        log_info "Downloading nix-portable..."
        curl -Lf "https://github.com/DavHau/nix-portable/releases/latest/download/nix-portable-$(uname -m)" -o "$np_bin"
        chmod +x "$np_bin"
    elif [[ ! -f "$np_bin" ]]; then
        log_error "Found $np_bin but it is not a regular file."
        return 1
    elif [[ ! -s "$np_bin" ]]; then
        log_error "Found $np_bin but it is empty — possibly a failed download."
        return 1
    elif [[ ! -x "$np_bin" ]]; then
        log_error "Found $np_bin but it is not executable."
        return 1
    else
        log_debug "nix-portable already present and executable."
    fi

    echo "$np_bin"
}

# Custom nix wrapper
nix() {
    "$NP_BIN" nix "$@"
}

main() {
    local script_path
    script_path="$(get_script_path)"
    export SCRIPT_PATH="$script_path"

    local np_bin
    if ! np_bin="$(ensure_nix_portable "$script_path")"; then
        log_error "Failed to prepare nix-portable."
        exit 1
    fi
    export NP_BIN="$np_bin"

    log_info "Verifying that the flake can be built..."
    nix flake check "$script_path"
}

main "$@"
