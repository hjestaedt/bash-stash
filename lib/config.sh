#!/usr/bin/env bash

# configuration constants
readonly STASH_DIR="${HOME}/var/stash"
readonly LOCK_FILE="${STASH_DIR}/.lock"
SCRIPT_NAME=$(basename "$0")
readonly SCRIPT_NAME
readonly VERSION="1.2"
readonly LOG_FILE="${STASH_DIR}/stash.log"

# ensure stash directory exists
mkdir -p "${STASH_DIR}" 