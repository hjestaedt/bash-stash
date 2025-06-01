#!/usr/bin/env bash

# log message to the log file
log_message() {
    local level="$1"
    local msg="$2"
    local timestamp
    
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $msg" >> "$LOG_FILE"
}

# print error messages to stderr and log
error() {
    echo "[error] $*" >&2
    log_message "ERROR" "$*"
    return 1
}

# print fatal error messages and exit
fatal_error() {
    error "$*"
    exit 1
}

# print warning messages to stderr and log
warn() {
    echo "[warning] $*" >&2
    log_message "WARNING" "$*"
}

# print info messages to stdout and log
info() {
    echo "$*"
    log_message "INFO" "$*"
}

# debug messages (only when debug mode is enabled)
debug() {
    if [[ "${DEBUG:-0}" -eq 1 ]]; then
        echo "[debug] $*" >&2
        log_message "DEBUG" "$*"
    fi
} 