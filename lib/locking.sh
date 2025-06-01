#!/usr/bin/env bash

# acquire a lock to prevent race conditions
acquire_lock() {
    local retries=10
    local wait_time=0.5
    
    mkdir -p "$(dirname "$LOCK_FILE")"
    
    while [[ $retries -gt 0 ]]; do
        if mkdir "$LOCK_FILE" 2>/dev/null; then
            echo "$$" > "${LOCK_FILE}/pid"
            debug "lock acquired by pid $$"
            return 0
        fi
        
        # check if the lock is stale
        if [[ -f "${LOCK_FILE}/pid" ]]; then
            local lock_pid
            lock_pid=$(<"${LOCK_FILE}/pid")
            if ! kill -0 "$lock_pid" 2>/dev/null; then
                warn "removing stale lock from pid $lock_pid"
                rm -rf "$LOCK_FILE"
                continue
            fi
        fi
        
        debug "waiting for lock (retries left: $retries)"
        sleep "$wait_time"
        retries=$((retries - 1))
    done
    
    error "could not acquire lock after multiple attempts. another instance might be running."
    return 1
}

# release the lock
release_lock() {
    if [[ -d "$LOCK_FILE" ]]; then
        debug "releasing lock by pid $$"
        rm -rf "$LOCK_FILE" 2>/dev/null || true
    fi
}

# ensure lock is released when script exits
cleanup() {
    release_lock
    debug "cleanup completed for pid $$"
}

# set up signal traps
setup_traps() {
    trap 'cleanup; exit 130' INT
    trap 'cleanup; exit 143' TERM
    trap cleanup EXIT
} 