#!/usr/bin/env bash

# get all stashes sorted by date
get_sorted_stashes() {
    local stash_dirs=()
    
    # check if stash directory exists
    if [[ ! -d "$STASH_DIR" ]]; then
        debug "stash directory does not exist yet"
        return 0
    fi
    
    # use nullglob to avoid errors if no matches are found
    shopt -s nullglob
    stash_dirs=("${STASH_DIR}"/stash-*)
    shopt -u nullglob
    
    # return early if no stashes found
    if [[ ${#stash_dirs[@]} -eq 0 ]]; then
        debug "no stashes found"
        return 0
    fi
    
    # sort stashes by name (which is date-based)
    if [[ "${#stash_dirs[@]}" -gt 0 ]]; then
        printf '%s\n' "${stash_dirs[@]}" | sort
    fi
}

# resolve stash id from number or full id
resolve_stash_id() {
    local input="$1"
    
    # return empty if input is empty
    if [[ -z "$input" ]]; then
        error "empty stash id provided."
        return 1
    fi
    
    # if it's a number, lookup the corresponding stash
    if [[ "$input" =~ ^[0-9]+$ ]]; then
        local sorted_stashes=()
        
        # get sorted stashes - compatible with bash 3.2
        while IFS= read -r line; do
            sorted_stashes+=("$line")
        done < <(get_sorted_stashes)
        
        # check if we have any stashes at all
        if [[ "${#sorted_stashes[@]}" -eq 0 ]]; then
            error "no stashes found."
            return 1
        else
            local index=$(( input - 1 ))
            
            # check if index is valid
            if [[ "$index" -ge 0 && "$index" -lt "${#sorted_stashes[@]}" ]]; then
                echo "${sorted_stashes[$index]##*/}"
                return 0
            else
                error "invalid stash number: $input. valid range is 1-${#sorted_stashes[@]}."
                return 1
            fi
        fi
    else
        # check if the id exists - validate format first
        if [[ ! "$input" =~ ^stash-[0-9]{8}-[0-9]{6}$ ]]; then
            error "invalid stash id format: $input. expected format: stash-YYYYMMDD-HHMMSS"
            return 1
        fi
        
        if [[ ! -d "${STASH_DIR}/$input" ]]; then
            error "stash id not found: $input"
            return 1
        fi
        
        echo "$input"
        return 0
    fi
} 