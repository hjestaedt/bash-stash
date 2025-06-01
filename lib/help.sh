#!/usr/bin/env bash

# print usage information
usage() {
    cat << EOF
usage: $SCRIPT_NAME <command> [options]

commands:
  save <file1> [file2...] [-m "message"]  - stash files/directories with optional message
  list                                   - list all stashed items
  show <stash-id>                        - show contents of a specific stash
  apply <stash-id>                       - restore a stashed item to its original location
  drop <stash-id>                        - remove a specific stash
  clear                                  - remove all stashes
  help                                   - display this help message
  version                                - show version information

options:
  -m, --message "message"                - add a description when saving a stash
  -c, --copy                             - copy files instead of moving them (for save command)
  -z, --compress                         - compress the stashed content (for save command)
  -v, --verbose                          - show verbose output
  -d, --debug                            - enable debug output (very verbose)

examples:
  $SCRIPT_NAME save file1.txt src/ -m "work in progress"
  $SCRIPT_NAME save --copy important.txt -m "keep a copy"
  $SCRIPT_NAME list
  $SCRIPT_NAME show 1         # show stash by number
  $SCRIPT_NAME apply stash-20250315-123456  # apply by id
  $SCRIPT_NAME drop 2         # drop stash by number
  $SCRIPT_NAME clear

notes:
  - stash ids can be referenced by number (1, 2, 3) or full id (stash-YYYYMMDD-HHMMSS)
  - the current directory ('.') cannot be stashed directly
  - by default, files are moved to the stash. use --copy to keep originals.
EOF
    return 0
} 