# bash-stash

a utility to temporarily store and restore files and directories, similar to git stash but for general files and directories.

## installation

### option 1: using makefile (recommended)

1. clone this repository:
   ```bash
   git clone <repository-url> bash-stash
   cd bash-stash
   ```

2. install using make:
   ```bash
   make install
   ```
   
   this will install to `~/bin/` by default. to install to a different location:
   ```bash
   make install INSTALL_DIR=/usr/local/bin
   ```

3. to uninstall:
   ```bash
   make uninstall
   ```

### option 2: manual installation

1. clone this repository:
   ```bash
   git clone <repository-url> bash-stash
   cd bash-stash
   ```

2. make the script executable:
   ```bash
   chmod +x stash
   ```

3. copy the script and libraries to your PATH:
   ```bash
   cp stash ~/bin/           # or /usr/local/bin/
   cp -r lib ~/bin/bash-stash.d    # or /usr/local/bin/bash-stash.d
   ```

## usage

```bash
stash <command> [options]
```

## commands

- `save <file1> [file2...] [-m "message"]` - stash files/directories with optional message
- `list` - list all stashed items
- `show <stash-id>` - show contents of a specific stash
- `apply <stash-id>` - restore a stashed item to its original location
- `drop <stash-id>` - remove a specific stash
- `clear` - remove all stashes
- `help` - display help message
- `version` - show version information

## options

- `-m, --message "message"` - add a description when saving a stash
- `-c, --copy` - copy files instead of moving them (for save command)
- `-z, --compress` - compress the stashed content (for save command)
- `-v, --verbose` - show verbose output
- `-d, --debug` - enable debug output (very verbose)

## examples

### basic usage
```bash
# stash a file (moves it to stash)
stash save important.txt -m "work in progress"

# stash multiple files
stash save file1.txt file2.txt dir/ -m "backup before changes"

# copy instead of move
stash save --copy config.txt -m "keep a backup"

# compress large files/directories
stash save --compress large_directory/ -m "compressed backup"

# list all stashes
stash list

# show details of a specific stash
stash show 1

# restore a stash (prompts to drop after restoration)
stash apply 1

# drop a specific stash
stash drop 2

# clear all stashes
stash clear
```

### referencing stashes
stashes can be referenced by:
- number: `1`, `2`, `3` (based on creation order)
- full id: `stash-20250315-123456` (timestamp-based)

## storage

stashes are stored in `~/var/stash/` with the following structure:
- `stash-YYYYMMDD-HHMMSS/` - each stash directory
  - `content/` - actual stashed files/directories
  - `description` - user message
  - `paths` - original file paths
  - `compressed` - compression flag
  - `copy_mode` - whether files were copied or moved

## safety features

- prevents stashing system directories (`/bin`, `/etc`, etc.)
- prevents stashing the current directory (`.`)
- prevents stashing the stash directory itself
- file locking to prevent concurrent operations
- validation of stash ids and paths

## notes

- by default, files are **moved** to the stash. use `--copy` to keep originals
- compressed stashes use tar.gz format
- stash operations are logged to `~/var/stash/stash.log`
- the tool is designed to be safe and will warn about potentially dangerous operations

## requirements

- bash 4.0 or later
- standard unix tools: `tar`, `find`, `mkdir`, `rm`, `cp`, `mv`
- optional: `realpath` (fallback implementation included)
