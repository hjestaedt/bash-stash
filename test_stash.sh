#!/usr/bin/env bash
#
# test_stash.sh - comprehensive test suite for the stash utility
#
# usage: ./test_stash.sh [path/to/stash]

set -euo pipefail

# configuration
readonly TEST_DIR="/tmp/stash_test_$$"
readonly STASH_HOME="${TEST_DIR}/home"
readonly STASH_VAR="${STASH_HOME}/var"
readonly STASH_STORAGE="${STASH_VAR}/stash"
readonly ORIGINAL_HOME="$HOME"
readonly GREEN="\033[0;32m"
readonly RED="\033[0;31m"
readonly YELLOW="\033[0;33m"
readonly RESET="\033[0m"

# find the stash script to test
if [[ $# -gt 0 ]]; then
    STASH_CMD="$1"
else
    # try to find it in common locations
    if command -v stash > /dev/null 2>&1; then
        STASH_CMD="stash"
    elif [[ -x "$HOME/bin/stash" ]]; then
        STASH_CMD="$HOME/bin/stash"
    elif [[ -x "./stash" ]]; then
        STASH_CMD="./stash"
    else
        echo -e "${RED}error: could not find stash script. please provide path as an argument.${RESET}"
        exit 1
    fi
fi

# count of tests passed, failed, and skipped
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0
TESTS_TOTAL=0

# cleanup function to remove test files
cleanup() {
    echo "cleaning up test environment..."
    HOME="$ORIGINAL_HOME"
    rm -rf "$TEST_DIR"
    echo "done."
}

# log a message with timestamp
log() {
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] $*"
}

# function to mark a test as passed
pass() {
    local test_name="$1"
    echo -e "${GREEN}✓ pass:${RESET} $test_name"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

# function to mark a test as failed
fail() {
    local test_name="$1"
    local message="${2:-no details provided}"
    echo -e "${RED}✗ fail:${RESET} $test_name - $message"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

# function to mark a test as skipped
skip() {
    local test_name="$1"
    local reason="${2:-no reason provided}"
    echo -e "${YELLOW}⚠ skip:${RESET} $test_name - $reason"
    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
}

# function to run a test
run_test() {
    local test_name="$1"
    local test_func="$2"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    echo "======================================================================"
    echo "running test: $test_name"
    
    # create a completely new test environment for each test
    rm -rf "$TEST_DIR"
    mkdir -p "$STASH_VAR"
    mkdir -p "${TEST_DIR}/files/subdir1/subdir2"
    echo "Test file 1 content" > "${TEST_DIR}/files/file1.txt"
    echo "Test file 2 content" > "${TEST_DIR}/files/file2.txt"
    echo "Test file 3 content" > "${TEST_DIR}/files/subdir1/file3.txt"
    echo "Test file 4 content" > "${TEST_DIR}/files/subdir1/subdir2/file4.txt"
    
    # set HOME to our test home
    mkdir -p "$STASH_HOME"
    export HOME="$STASH_HOME"
    
    # make sure no stashes exist
    if [[ -d "$STASH_STORAGE" ]]; then
        rm -rf "${STASH_STORAGE}/stash-"*
    fi
    
    # debug: check stash count before test
    local initial_count
    initial_count=$(count_stashes)
    echo "debug: initial stash count before test: $initial_count"
    
    # run the test function
    if $test_func; then
        pass "$test_name"
        return 0
    else
        fail "$test_name"
        return 1
    fi
}

# function to create a clean test environment
clean_test_env() {
    rm -rf "$TEST_DIR"
    mkdir -p "$STASH_VAR"
    mkdir -p "${TEST_DIR}/files/subdir1/subdir2"
    echo "Test file 1 content" > "${TEST_DIR}/files/file1.txt"
    echo "Test file 2 content" > "${TEST_DIR}/files/file2.txt"
    echo "Test file 3 content" > "${TEST_DIR}/files/subdir1/file3.txt"
    echo "Test file 4 content" > "${TEST_DIR}/files/subdir1/subdir2/file4.txt"
    
    mkdir -p "$STASH_HOME"
    export HOME="$STASH_HOME"
}

# function to check if a file exists
assert_file_exists() {
    local file="$1"
    if [[ -f "$file" ]]; then
        return 0
    else
        echo "file does not exist: $file"
        return 1
    fi
}

# function to check if a directory exists
assert_dir_exists() {
    local dir="$1"
    if [[ -d "$dir" ]]; then
        return 0
    else
        echo "directory does not exist: $dir"
        return 1
    fi
}

# function to check if a file or directory does not exist
assert_not_exists() {
    local path="$1"
    if [[ ! -e "$path" ]]; then
        return 0
    else
        echo "path exists when it should not: $path"
        return 1
    fi
}

# function to check if a file contains specific content
assert_file_contains() {
    local file="$1"
    local pattern="$2"
    if grep -q "$pattern" "$file"; then
        return 0
    else
        echo "file does not contain expected pattern: $pattern"
        echo "file content:"
        cat "$file"
        return 1
    fi
}

# function to count the number of stash entries
count_stashes() {
    if [[ -d "$STASH_STORAGE" ]]; then
        local count
        count=$(find "$STASH_STORAGE" -maxdepth 1 -name "stash-*" -type d | wc -l)
        echo "$count"
    else
        echo "0"
    fi
}

# function to extract the id of the first stash
get_first_stash_id() {
    if [[ -d "$STASH_STORAGE" ]]; then
        local stash_id
        stash_id=$(find "$STASH_STORAGE" -maxdepth 1 -name "stash-*" -type d | sort | head -1)
        if [[ -n "$stash_id" ]]; then
            basename "$stash_id"
            return 0
        fi
    fi
    echo ""
    return 1
}

# test basic stash functionality
test_stash_basic() {
    local file_path="${TEST_DIR}/files/file1.txt"
    
    assert_file_exists "$file_path" || return 1
    $STASH_CMD save "$file_path" -m "test stash" > /dev/null || return 1
    assert_not_exists "$file_path" || return 1
    
    local stash_count
    stash_count=$(count_stashes)
    if [[ "$stash_count" -ne 1 ]]; then
        echo "expected 1 stash, found $stash_count"
        return 1
    fi
    
    return 0
}

# test stashing with copy option
test_stash_copy() {
    local file_path="${TEST_DIR}/files/file1.txt"
    
    assert_file_exists "$file_path" || return 1
    $STASH_CMD save --copy "$file_path" -m "test copy stash" > /dev/null || return 1
    assert_file_exists "$file_path" || return 1
    
    local stash_count
    stash_count=$(count_stashes)
    if [[ "$stash_count" -ne 1 ]]; then
        echo "expected 1 stash, found $stash_count"
        return 1
    fi
    
    return 0
}

# test stashing with compression
test_stash_compress() {
    local file_path="${TEST_DIR}/files/file1.txt"
    
    assert_file_exists "$file_path" || return 1
    $STASH_CMD save --compress "$file_path" -m "test compress stash" > /dev/null || return 1
    assert_not_exists "$file_path" || return 1
    
    local stash_count
    stash_count=$(count_stashes)
    if [[ "$stash_count" -ne 1 ]]; then
        echo "expected 1 stash, found $stash_count"
        return 1
    fi
    
    # verify we have a compressed file in the stash
    local stash_id
    stash_id=$(get_first_stash_id)
    if [[ ! -f "${STASH_STORAGE}/${stash_id}/content/file1.txt.tar.gz" ]]; then
        echo "compressed file not found in stash"
        return 1
    fi
    
    return 0
}

# test stashing multiple files at once
test_stash_multiple() {
    local file1_path="${TEST_DIR}/files/file1.txt"
    local file2_path="${TEST_DIR}/files/file2.txt"
    
    assert_file_exists "$file1_path" || return 1
    assert_file_exists "$file2_path" || return 1
    
    $STASH_CMD save "$file1_path" "$file2_path" -m "multiple files" > /dev/null || return 1
    
    assert_not_exists "$file1_path" || return 1
    assert_not_exists "$file2_path" || return 1
    
    local stash_count
    stash_count=$(count_stashes)
    if [[ "$stash_count" -ne 1 ]]; then
        echo "expected 1 stash, found $stash_count"
        return 1
    fi
    
    return 0
}

# test stashing a directory
test_stash_directory() {
    local dir_path="${TEST_DIR}/files/subdir1"
    
    assert_dir_exists "$dir_path" || return 1
    $STASH_CMD save "$dir_path" -m "directory stash" > /dev/null || return 1
    assert_not_exists "$dir_path" || return 1
    
    local stash_count
    stash_count=$(count_stashes)
    if [[ "$stash_count" -ne 1 ]]; then
        echo "expected 1 stash, found $stash_count"
        return 1
    fi
    
    return 0
}

# test listing stashes
test_stash_list() {
    local file_path="${TEST_DIR}/files/file1.txt"
    local message="test list stash"
    
    $STASH_CMD save "$file_path" -m "$message" > /dev/null || return 1
    
    local list_output
    list_output=$($STASH_CMD list)
    
    if ! echo "$list_output" | grep -q "$message"; then
        echo "stash list does not contain our message: $message"
        echo "list output:"
        echo "$list_output"
        return 1
    fi
    
    return 0
}

# test showing stash details
test_stash_show() {
    local file_path="${TEST_DIR}/files/file1.txt"
    local message="test show stash"
    
    $STASH_CMD save "$file_path" -m "$message" > /dev/null || return 1
    
    local show_output
    show_output=$($STASH_CMD show 1)
    
    if ! echo "$show_output" | grep -q "$message"; then
        echo "stash show does not contain our message: $message"
        echo "show output:"
        echo "$show_output"
        return 1
    fi
    
    if ! echo "$show_output" | grep -q "file1.txt"; then
        echo "stash show does not contain the file name: file1.txt"
        echo "show output:"
        echo "$show_output"
        return 1
    fi
    
    return 0
}

# test applying a stash
test_stash_apply() {
    local file_path="${TEST_DIR}/files/file1.txt"
    local content="Test file 1 content"
    
    assert_file_exists "$file_path" || return 1
    $STASH_CMD save "$file_path" -m "test apply stash" > /dev/null || return 1
    assert_not_exists "$file_path" || return 1
    
    echo "n" | $STASH_CMD apply 1 > /dev/null || return 1
    
    assert_file_exists "$file_path" || return 1
    assert_file_contains "$file_path" "$content" || return 1
    
    return 0
}

# test applying a stash and choosing to drop it
test_stash_apply_and_drop() {
    local file_path="${TEST_DIR}/files/file1.txt"
    
    assert_file_exists "$file_path" || return 1
    $STASH_CMD save "$file_path" -m "test apply and drop" > /dev/null || return 1
    
    local stash_count
    stash_count=$(count_stashes)
    if [[ "$stash_count" -ne 1 ]]; then
        echo "expected 1 stash, found $stash_count"
        return 1
    fi
    
    echo "y" | $STASH_CMD apply 1 > /dev/null || return 1
    
    assert_file_exists "$file_path" || return 1
    
    stash_count=$(count_stashes)
    if [[ "$stash_count" -ne 0 ]]; then
        echo "expected 0 stashes, found $stash_count"
        return 1
    fi
    
    return 0
}

# test applying a stash when file already exists (should skip)
test_stash_apply_existing_file() {
    local file_path="${TEST_DIR}/files/file1.txt"
    local original_content="Test file 1 content"
    local new_content="Modified content"
    
    # stash the original file
    assert_file_exists "$file_path" || return 1
    $STASH_CMD save "$file_path" -m "test apply with existing file" > /dev/null || return 1
    assert_not_exists "$file_path" || return 1
    
    # create a new file with different content at the same location
    echo "$new_content" > "$file_path"
    
    # apply stash without -f flag (should skip)
    echo "n" | $STASH_CMD apply 1 > /dev/null 2>&1 || return 1
    
    # verify the new file content is preserved (not overwritten)
    assert_file_contains "$file_path" "$new_content" || return 1
    
    return 0
}

# test applying a stash with -f flag to force overwrite
test_stash_apply_force_overwrite() {
    local file_path="${TEST_DIR}/files/file1.txt"
    local original_content="Test file 1 content"
    local new_content="Modified content"
    
    # stash the original file
    assert_file_exists "$file_path" || return 1
    $STASH_CMD save "$file_path" -m "test force apply" > /dev/null || return 1
    assert_not_exists "$file_path" || return 1
    
    # create a new file with different content at the same location
    echo "$new_content" > "$file_path"
    assert_file_contains "$file_path" "$new_content" || return 1
    
    # apply stash with -f flag (should overwrite)
    echo "n" | $STASH_CMD apply 1 -f > /dev/null 2>&1 || return 1
    
    # verify the original content is restored (file was overwritten)
    assert_file_contains "$file_path" "$original_content" || return 1
    
    return 0
}

# test applying a stash with --force flag (long form)
test_stash_apply_force_long_flag() {
    local file_path="${TEST_DIR}/files/file1.txt"
    local original_content="Test file 1 content"
    local new_content="Modified content"
    
    # stash the original file
    assert_file_exists "$file_path" || return 1
    $STASH_CMD save "$file_path" -m "test force apply long flag" > /dev/null || return 1
    assert_not_exists "$file_path" || return 1
    
    # create a new file with different content at the same location
    echo "$new_content" > "$file_path"
    
    # apply stash with --force flag
    echo "n" | $STASH_CMD apply 1 --force > /dev/null 2>&1 || return 1
    
    # verify the original content is restored
    assert_file_contains "$file_path" "$original_content" || return 1
    
    return 0
}

# test applying with -f flag where stash id comes after flag
test_stash_apply_force_flag_order() {
    local file_path="${TEST_DIR}/files/file1.txt"
    local original_content="Test file 1 content"
    local new_content="Modified content"
    
    # stash the original file
    assert_file_exists "$file_path" || return 1
    $STASH_CMD save "$file_path" -m "test flag order" > /dev/null || return 1
    assert_not_exists "$file_path" || return 1
    
    # create a new file with different content
    echo "$new_content" > "$file_path"
    
    # apply stash with -f flag before stash id
    echo "n" | $STASH_CMD apply -f 1 > /dev/null 2>&1 || return 1
    
    # verify the original content is restored
    assert_file_contains "$file_path" "$original_content" || return 1
    
    return 0
}

# test error case - unknown option for apply command
test_apply_unknown_option() {
    local file_path="${TEST_DIR}/files/file1.txt"
    
    $STASH_CMD save "$file_path" -m "test unknown option" > /dev/null || return 1
    
    if $STASH_CMD apply 1 --unknown-flag > /dev/null 2>&1; then
        echo "expected failure with unknown flag, but command succeeded"
        return 1
    fi
    
    return 0
}

# test error case - multiple stash ids
test_apply_multiple_stash_ids() {
    local file_path="${TEST_DIR}/files/file1.txt"
    
    $STASH_CMD save "$file_path" -m "test multiple ids" > /dev/null || return 1
    
    if $STASH_CMD apply 1 2 > /dev/null 2>&1; then
        echo "expected failure with multiple stash ids, but command succeeded"
        return 1
    fi
    
    return 0
}

# test dropping a stash
test_stash_drop() {
    local file_path="${TEST_DIR}/files/file1.txt"
    
    $STASH_CMD save "$file_path" -m "test drop" > /dev/null || return 1
    
    local stash_count
    stash_count=$(count_stashes)
    if [[ "$stash_count" -ne 1 ]]; then
        echo "expected 1 stash, found $stash_count"
        return 1
    fi
    
    $STASH_CMD drop 1 > /dev/null || return 1
    
    stash_count=$(count_stashes)
    if [[ "$stash_count" -ne 0 ]]; then
        echo "expected 0 stashes, found $stash_count"
        return 1
    fi
    
    return 0
}

# test clearing all stashes
test_stash_clear() {
    local file1_path="${TEST_DIR}/files/file1.txt"
    local file2_path="${TEST_DIR}/files/file2.txt"
    
    $STASH_CMD save "$file1_path" -m "first stash" > /dev/null || return 1
    sleep 1
    $STASH_CMD save "$file2_path" -m "second stash" > /dev/null || return 1
    
    local stash_count
    stash_count=$(count_stashes)
    if [[ "$stash_count" -ne 2 ]]; then
        echo "expected 2 stashes, found $stash_count"
        return 1
    fi
    
    echo "y" | $STASH_CMD clear > /dev/null || return 1
    
    stash_count=$(count_stashes)
    if [[ "$stash_count" -ne 0 ]]; then
        echo "expected 0 stashes, found $stash_count"
        return 1
    fi
    
    return 0
}

# test error cases - stashing non-existent file
test_stash_nonexistent() {
    if $STASH_CMD save "/nonexistent/file" > /dev/null 2>&1; then
        echo "expected failure when stashing non-existent file, but command succeeded"
        return 1
    fi
    
    local stash_count
    stash_count=$(count_stashes)
    if [[ "$stash_count" -ne 0 ]]; then
        echo "expected 0 stashes, found $stash_count"
        return 1
    fi
    
    return 0
}

# test error cases - stashing current directory
test_stash_current_dir() {
    local original_pwd="$PWD"
    cd "${TEST_DIR}/files"
    
    local result=0
    if $STASH_CMD save . > /dev/null 2>&1; then
        echo "expected failure when stashing current directory, but command succeeded"
        result=1
    fi
    
    # always return to original directory
    cd "$original_pwd"
    return $result
}

# test error cases - apply non-existent stash
test_apply_nonexistent() {
    if $STASH_CMD apply 999 > /dev/null 2>&1; then
        echo "expected failure when applying non-existent stash, but command succeeded"
        return 1
    fi
    
    return 0
}

# test error cases - drop non-existent stash
test_drop_nonexistent() {
    if $STASH_CMD drop 999 > /dev/null 2>&1; then
        echo "expected failure when dropping non-existent stash, but command succeeded"
        return 1
    fi
    
    return 0
}

# test error cases - show non-existent stash
test_show_nonexistent() {
    if $STASH_CMD show 999 > /dev/null 2>&1; then
        echo "expected failure when showing non-existent stash, but command succeeded"
        return 1
    fi
    
    return 0
}

# main test runner
run_tests() {
    log "starting test suite for stash script: $STASH_CMD"
    log "using temporary directory: $TEST_DIR"
    
    # basic functionality tests
    run_test "basic stash functionality" test_stash_basic
    run_test "stash with copy option" test_stash_copy
    run_test "stash with compression" test_stash_compress
    run_test "stash multiple files" test_stash_multiple
    run_test "stash a directory" test_stash_directory
    run_test "list stashes" test_stash_list
    run_test "show stash details" test_stash_show
    run_test "apply a stash" test_stash_apply
    run_test "apply and drop a stash" test_stash_apply_and_drop
    run_test "apply with existing file (should skip)" test_stash_apply_existing_file
    run_test "apply with force overwrite (-f)" test_stash_apply_force_overwrite
    run_test "apply with force overwrite (--force)" test_stash_apply_force_long_flag
    run_test "apply with -f flag before stash id" test_stash_apply_force_flag_order
    run_test "drop a stash" test_stash_drop
    run_test "clear all stashes" test_stash_clear
    
    # error case tests
    run_test "error: stash non-existent file" test_stash_nonexistent
    run_test "error: stash current directory" test_stash_current_dir
    run_test "error: apply non-existent stash" test_apply_nonexistent
    run_test "error: apply with unknown option" test_apply_unknown_option
    run_test "error: apply with multiple stash ids" test_apply_multiple_stash_ids
    run_test "error: drop non-existent stash" test_drop_nonexistent
    run_test "error: show non-existent stash" test_show_nonexistent
    
    # summarize results
    log "test summary:"
    log "total: $TESTS_TOTAL"
    log "passed: $TESTS_PASSED"
    log "failed: $TESTS_FAILED"
    log "skipped: $TESTS_SKIPPED"
    
    if [[ "$TESTS_FAILED" -eq 0 ]]; then
        echo -e "${GREEN}all tests passed!${RESET}"
        return 0
    else
        echo -e "${RED}some tests failed!${RESET}"
        return 1
    fi
}

# set up trap to clean up
trap cleanup EXIT

# run all the tests
run_tests

exit $?
