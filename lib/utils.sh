#!/usr/bin/env bash

# safely get the real path of a file with bash builtins where possible
safe_realpath() {
    local path="$1"
    local resolved
    
    # try using realpath if available
    if command -v realpath >/dev/null 2>&1; then
        resolved=$(realpath -e "$path" 2>/dev/null) || {
            error "path does not exist: $path"
            return 1
        }
    else
        # fallback for systems without realpath
        if [[ ! -e "$path" ]]; then
            error "path does not exist: $path"
            return 1
        fi
        
        # handle absolute paths
        if [[ "${path:0:1}" = "/" ]]; then
            resolved="$path"
        else
            # handle relative paths
            resolved="$(pwd)/$path"
        fi
        
        # normalize path (basic implementation)
        resolved=$(echo "$resolved" | sed -e 's/\/\.\//\//g' -e 's/\/[^\/]*\/\.\.\//\//g')
    fi
    
    echo "$resolved"
    return 0
}

# check if a path is safe to stash
is_safe_path() {
    local path="$1"
    local abs_path
    
    # get absolute path safely
    abs_path=$(safe_realpath "$path") || return 1
    
    # prevent stashing the current directory
    if [[ "$abs_path" = "$(pwd)" ]]; then
        error "stashing the current directory is not allowed."
        return 1
    fi
    
    # prevent stashing the stash directory itself
    if [[ "$abs_path" = "$STASH_DIR" || "$abs_path" = "${STASH_DIR}/"* ]]; then
        error "cannot stash the stash directory or its contents."
        return 1
    fi
    
    # comprehensive system directory check
    local system_dirs=(
        "/bin" "/sbin" "/usr/bin" "/usr/sbin" "/etc" "/var"
        "/lib" "/lib64" "/usr/lib" "/usr/lib64" "/boot" "/dev"
        "/proc" "/sys" "/tmp" "/run" "/opt" "/srv" "/root"
    )
    
    for dir in "${system_dirs[@]}"; do
        if [[ "$abs_path" = "$dir" || "$abs_path" = "${dir}/"* ]]; then
            error "stashing system directories ($dir) is not allowed."
            return 1
        fi
    done
    
    # additional sensitive paths
    if [[ "$abs_path" = "/home" ]]; then
        error "stashing the entire /home directory is not allowed."
        return 1
    fi
    
    # check for symbolic links
    if [[ -L "$path" ]]; then
        warn "note: '$path' is a symbolic link. only the link will be stashed, not its target."
    fi
    
    return 0
}

# validate user input for security
validate_input() {
    local input="$1"
    local type="$2"
    
    case "$type" in
        message)
            # check for control characters
            if [[ "$input" =~ [[:cntrl:]]+ ]]; then
                error "message contains invalid control characters."
                return 1
            fi
            ;;
        path)
            # additional path validations could be added here
            ;;
        *)
            # default validation
            ;;
    esac
    
    return 0
} 