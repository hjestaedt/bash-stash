#!/usr/bin/env bash

# save files/directories to a stash
save_stash() {
    local message=""
    local items=()
    local compress=0
    local copy_files=0
    local verbose=0
    
    # parse arguments to separate files from options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -m|--message)
                shift
                if [[ $# -eq 0 ]]; then
                    error "no message provided after -m/--message option."
                    return 1
                fi
                message="$1"
                validate_input "$message" "message" || return 1
                shift
                ;;
            -z|--compress)
                compress=1
                shift
                ;;
            -c|--copy)
                copy_files=1
                shift
                ;;
            -v|--verbose)
                verbose=1
                shift
                ;;
            -d|--debug)
                export DEBUG=1
                shift
                ;;
            -*)
                error "unknown option: $1"
                echo "use 'stash help' to see available options."
                return 1
                ;;
            *)
                items+=("$1")
                shift
                ;;
        esac
    done
    
    # check if we have files to stash
    if [[ ${#items[@]} -eq 0 ]]; then
        error "no files or directories specified to stash."
        echo "usage: stash save <file1> [file2...] [-m \"message\"]"
        return 1
    fi
    
    # generate a unique stash id based on date and time
    local stash_id
    stash_id="stash-$(date +%Y%m%d-%H%M%S)"
    local stash_path="${STASH_DIR}/${stash_id}"
    
    # initialize flag to track if any items were successfully stashed
    local any_valid_items=0
    
    # first, check if any items are valid to stash before creating the stash directory
    for item in "${items[@]}"; do
        [[ -z "$item" ]] && continue
        
        if [[ "$item" = "." ]]; then
            error "stashing the current directory ('.') is not allowed."
            continue
        fi
        
        if [[ -e "$item" ]]; then
            if is_safe_path "$item"; then
                any_valid_items=1
                break
            fi
        else
            warn "'$item' does not exist, skipping."
        fi
    done
    
    # only continue if we have valid items to stash
    if [[ $any_valid_items -eq 0 ]]; then
        error "no valid files to stash. operation aborted."
        return 1
    fi
    
    # acquire lock
    acquire_lock || return 1
    
    # now create the stash directory since we have valid items
    mkdir -p "${stash_path}/content"
    
    # set default message if not provided
    if [[ -z "$message" ]]; then
        message="stashed on $(date)"
    fi
    
    # save the message
    echo "$message" > "${stash_path}/description"
    
    # save whether content is compressed
    echo "$compress" > "${stash_path}/compressed"
    
    # process all items
    local success=0
    for item in "${items[@]}"; do
        [[ -z "$item" ]] && continue
        
        if [[ "$item" = "." ]]; then
            error "stashing the current directory ('.') is not allowed."
            continue
        fi
        
        if [[ -e "$item" ]]; then
            if ! is_safe_path "$item"; then
                continue
            fi
            
            local abs_path
            abs_path=$(safe_realpath "$item") || continue
            
            local base_name dir_name
            base_name="${abs_path##*/}"
            dir_name="${abs_path%/"$base_name"}"
            
            echo "${dir_name}/${base_name}" >> "${stash_path}/paths"
            
            if [[ $compress -eq 1 ]]; then
                if [[ $verbose -eq 1 ]]; then
                    info "compressing: $item"
                fi
                
                local tar_file="${stash_path}/content/${base_name}.tar.gz"
                if ! tar -czf "$tar_file" -C "$dir_name" "$base_name"; then
                    error "failed to compress: $item"
                    continue
                fi
                
                if [[ $copy_files -eq 0 && -f "$tar_file" ]]; then
                    if [[ $verbose -eq 1 ]]; then
                        info "removing original: $item"
                    fi
                    rm -rf "$abs_path"
                fi
            else
                if [[ $copy_files -eq 1 ]]; then
                    if [[ $verbose -eq 1 ]]; then
                        info "copying: $item"
                    fi
                    cp -a "$abs_path" "${stash_path}/content/" || {
                        error "failed to copy: $item"
                        continue
                    }
                else
                    if [[ $verbose -eq 1 ]]; then
                        info "moving: $item"
                    fi
                    mv -f "$abs_path" "${stash_path}/content/" || {
                        error "failed to move: $item"
                        continue
                    }
                fi
            fi
            
            echo "$copy_files" > "${stash_path}/copy_mode"
            
            info "stashed: $item"
            success=1
        else
            warn "'$item' does not exist, skipping."
        fi
    done
    
    # handle success or failure
    if [[ $success -eq 1 ]]; then
        info "stashed as: $stash_id"
        info "description: $message"
    else
        rm -rf "${stash_path}"
        error "no files were stashed."
        return 1
    fi
    
    return 0
}

# list all stashes
list_stash() {
    local sorted_stashes=()
    
    mapfile -t sorted_stashes < <(get_sorted_stashes)
    
    if [[ ${#sorted_stashes[@]} -eq 0 ]]; then
        info "no stashes found."
        return 0
    fi
    
    info "available stashes:"
    local idx=1
    for stash in "${sorted_stashes[@]}"; do
        if [[ -d "$stash" ]]; then
            local stash_id description
            stash_id="${stash##*/}"
            
            if [[ -f "$stash/description" ]]; then
                description=$(<"$stash/description")
            else
                description="no description"
            fi
            
            local copy_mode=""
            if [[ -f "$stash/copy_mode" && "$(<"$stash/copy_mode")" -eq 1 ]]; then
                copy_mode=" [copied]"
            fi
            
            local compressed=""
            if [[ -f "$stash/compressed" && "$(<"$stash/compressed")" -eq 1 ]]; then
                compressed=" [compressed]"
            fi
            
            info "  $idx: $stash_id: $description$copy_mode$compressed"
            idx=$((idx+1))
        fi
    done
    
    return 0
}

# show contents of a specific stash
show_stash() {
    if [[ -z "${1:-}" ]]; then
        error "no stash id specified."
        echo "usage: stash show <stash-id>"
        return 1
    fi
    
    local resolved_id
    resolved_id=$(resolve_stash_id "$1") || return 1
    
    local stash_path="${STASH_DIR}/$resolved_id"
    
    if [[ ! -d "${stash_path}" ]]; then
        error "stash '$resolved_id' not found."
        return 1
    fi
    
    local description
    if [[ -f "${stash_path}/description" ]]; then
        description=$(<"${stash_path}/description")
    else
        description="no description"
    fi
    
    info "stash: $resolved_id"
    info "description: $description"
    
    if [[ -f "${stash_path}/copy_mode" && "$(<"${stash_path}/copy_mode")" -eq 1 ]]; then
        info "mode: copy (originals were kept)"
    else
        info "mode: move (originals were removed)"
    fi
    
    local compressed=0
    if [[ -f "${stash_path}/compressed" ]]; then
        compressed=$(<"${stash_path}/compressed")
        if [[ $compressed -eq 1 ]]; then
            info "storage: compressed"
        fi
    fi
    
    info "contents:"
    
    if [[ -d "${stash_path}/content" ]]; then
        if [[ $compressed -eq 1 ]]; then
            if [[ -n "$(ls -A "${stash_path}/content" 2>/dev/null)" ]]; then
                for file in "${stash_path}/content"/*.tar.gz; do
                    [[ -f "$file" ]] || continue
                    local base_name
                    base_name="${file##*/}"
                    base_name="${base_name%.tar.gz}"
                    info "  [compressed] $base_name"
                done
            else
                info "  no content found in stash."
            fi
        else
            if [[ -n "$(ls -A "${stash_path}/content" 2>/dev/null)" ]]; then
                while IFS= read -r -d '' entry; do
                    if [[ -f "$entry" ]]; then
                        info "  [file] ${entry#"${stash_path}"/content/}"
                    elif [[ -d "$entry" ]]; then
                        info "  [dir] ${entry#"${stash_path}"/content/}"
                    fi
                done < <(find "${stash_path}/content" -mindepth 1 -print0 2>/dev/null)
            else
                info "  no content found in stash."
            fi
        fi
    else
        info "  no content directory found in stash."
    fi
    
    if [[ -f "${stash_path}/paths" && -s "${stash_path}/paths" ]]; then
        info "original paths:"
        while IFS= read -r path; do
            info "  $path"
        done < "${stash_path}/paths"
    fi
    
    return 0
}

# apply/restore a stash
apply_stash() {
    if [[ -z "${1:-}" ]]; then
        error "no stash id specified."
        echo "usage: stash apply <stash-id>"
        return 1
    fi
    
    local resolved_id
    resolved_id=$(resolve_stash_id "$1") || return 1
    
    local stash_path="${STASH_DIR}/$resolved_id"
    
    if [[ ! -d "${stash_path}" ]]; then
        error "stash '$resolved_id' not found."
        return 1
    fi
    
    if [[ ! -f "${stash_path}/paths" || ! -s "${stash_path}/paths" ]]; then
        error "path information for stash '$resolved_id' is missing or empty."
        return 1
    fi
    
    acquire_lock || return 1
    
    local compressed=0
    if [[ -f "${stash_path}/compressed" ]]; then
        compressed=$(<"${stash_path}/compressed")
    fi
    
    local restored=0
    while IFS= read -r original_path; do
        local base_name dir_name
        base_name="${original_path##*/}"
        dir_name="${original_path%/"$base_name"}"
        
        if ! mkdir -p "$dir_name"; then
            error "failed to create directory: $dir_name"
            continue
        fi
        
        if [[ -e "$original_path" ]]; then
            warn "'$original_path' already exists. skipping restoration."
            continue
        fi
        
        if [[ $compressed -eq 1 ]]; then
            local source_path="${stash_path}/content/${base_name}.tar.gz"
            
            if [[ -f "$source_path" ]]; then
                if tar -xzf "$source_path" -C "$dir_name"; then
                    info "restored: $original_path (decompressed)"
                    restored=1
                else
                    error "failed to decompress: $original_path"
                fi
            else
                warn "'${base_name}.tar.gz' not found in stash."
            fi
        else
            local source_path="${stash_path}/content/${base_name}"
            
            if [[ -e "$source_path" ]]; then
                if cp -a "$source_path" "$original_path"; then
                    info "restored: $original_path"
                    restored=1
                else
                    error "failed to restore: $original_path"
                fi
            else
                warn "'$base_name' not found in stash."
            fi
        fi
    done < "${stash_path}/paths"
    
    if [[ "$restored" -eq 1 ]]; then
        echo ""
        echo "do you want to drop stash '$resolved_id'? [y/N]"
        read -r confirm
        if [[ "$confirm" =~ ^[Yy] ]]; then
            rm -rf "${stash_path}"
            info "stash '$resolved_id' has been dropped."
        else
            info "stash '$resolved_id' kept."
        fi
    else
        warn "no items from stash '$resolved_id' were restored."
    fi
    
    return 0
}

# remove a specific stash
drop_stash() {
    if [[ -z "${1:-}" ]]; then
        error "no stash id specified."
        echo "usage: stash drop <stash-id>"
        return 1
    fi
    
    local resolved_id
    resolved_id=$(resolve_stash_id "$1") || return 1
    
    local stash_path="${STASH_DIR}/$resolved_id"
    
    if [[ ! -d "${stash_path}" ]]; then
        error "stash '$resolved_id' not found."
        return 1
    fi
    
    acquire_lock || return 1
    
    if rm -rf "${stash_path}"; then
        info "stash '$resolved_id' has been dropped."
    else
        error "failed to drop stash '$resolved_id'."
        return 1
    fi
    
    return 0
}

# remove all stashes
clear_stashes() {
    local sorted_stashes=()
    
    mapfile -t sorted_stashes < <(get_sorted_stashes)
    
    if [[ ${#sorted_stashes[@]} -eq 0 ]]; then
        info "no stashes found."
        return 0
    fi
    
    acquire_lock || return 1
    
    echo "are you sure you want to remove all stashes? [y/N]"
    read -r confirm
    if [[ "$confirm" =~ ^[Yy] ]]; then
        if rm -rf "${STASH_DIR}"/stash-*; then
            info "all stashes have been removed."
        else
            error "failed to remove all stashes."
            return 1
        fi
    else
        info "operation cancelled."
    fi
    
    return 0
} 