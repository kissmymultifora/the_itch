#!/bin/bash

# Test suite for oneliner.sh
# Comprehensive testing of all features and edge cases

set -euo pipefail

# Test configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ONELINER_SCRIPT="$SCRIPT_DIR/oneliner.sh"
readonly TEST_DIR="$SCRIPT_DIR/test_data"
readonly TEMP_DIR="$(mktemp -d)"

# Colors for test output
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly RESET='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Cleanup function
cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# Test helper functions
log_test() {
    printf "${BLUE}[TEST]${RESET} %s\n" "$1"
}

log_pass() {
    printf "${GREEN}[PASS]${RESET} %s\n" "$1"
    ((TESTS_PASSED++))
}

log_fail() {
    printf "${RED}[FAIL]${RESET} %s\n" "$1"
    ((TESTS_FAILED++))
}

run_test() {
    local test_name="$1"
    shift
    ((TESTS_RUN++))
    
    log_test "$test_name"
    
    if "$@"; then
        log_pass "$test_name"
        return 0
    else
        log_fail "$test_name"
        return 1
    fi
}

# Setup test data
setup_test_data() {
    mkdir -p "$TEST_DIR"
    
    # Create test files with pipe-delimited data
    cat > "$TEST_DIR/file1.txt" << 'EOF'
1|A|apple pie recipe
2|B|brown sugar cookies
3|C|cinnamon rolls
4|D|delicious cake
5|E|egg sandwich
EOF

    cat > "$TEST_DIR/file2.txt" << 'EOF'
1|A|apple pie recipe
6|F|fresh bread
2|B|brown sugar cookies
7|G|green salad
8|H|hot soup
9|I|ice cream
EOF

    # Create CSV test files
    cat > "$TEST_DIR/csv1.txt" << 'EOF'
1,A,apple pie recipe
2,B,brown sugar cookies
3,C,cinnamon rolls
EOF

    cat > "$TEST_DIR/csv2.txt" << 'EOF'
1,A,apple pie recipe
4,D,delicious cake
2,B,brown sugar cookies
5,E,egg sandwich
EOF

    # Create empty files for edge case testing
    touch "$TEST_DIR/empty1.txt"
    touch "$TEST_DIR/empty2.txt"
}

# Test basic functionality
test_basic_functionality() {
    local output
    output=$("$ONELINER_SCRIPT" "$TEST_DIR/file1.txt" "$TEST_DIR/file2.txt" 2>/dev/null)
    
    local expected_lines=3
    local actual_lines
    actual_lines=$(echo "$output" | wc -l)
    
    [[ $actual_lines -eq $expected_lines ]]
}

# Test help option
test_help_option() {
    "$ONELINER_SCRIPT" --help >/dev/null 2>&1
}

# Test version option
test_version_option() {
    local output
    output=$("$ONELINER_SCRIPT" --version 2>/dev/null)
    [[ "$output" == *"version"* ]]
}

# Test verbose mode
test_verbose_mode() {
    local output
    output=$("$ONELINER_SCRIPT" --verbose "$TEST_DIR/file1.txt" "$TEST_DIR/file2.txt" 2>&1)
    [[ "$output" == *"INFO"* ]]
}

# Test debug mode
test_debug_mode() {
    local output
    output=$("$ONELINER_SCRIPT" --debug "$TEST_DIR/file1.txt" "$TEST_DIR/file2.txt" 2>&1)
    [[ "$output" == *"DEBUG"* ]]
}

# Test timing option
test_timing_option() {
    local output
    output=$("$ONELINER_SCRIPT" --timing "$TEST_DIR/file1.txt" "$TEST_DIR/file2.txt" 2>&1)
    [[ "$output" == *"completed in"* ]]
}

# Test custom separator
test_custom_separator() {
    local output
    output=$("$ONELINER_SCRIPT" --separator ',' "$TEST_DIR/csv1.txt" "$TEST_DIR/csv2.txt" 2>/dev/null)
    
    local expected_lines=2
    local actual_lines
    actual_lines=$(echo "$output" | wc -l)
    
    [[ $actual_lines -eq $expected_lines ]]
}

# Test JSON output format
test_json_output() {
    local output
    output=$("$ONELINER_SCRIPT" --format json "$TEST_DIR/file1.txt" "$TEST_DIR/file2.txt" 2>/dev/null)
    [[ "$output" == *'"results":'* ]] && [[ "$output" == *'"line":'* ]]
}

# Test CSV output format
test_csv_output() {
    "$ONELINER_SCRIPT" --format csv "$TEST_DIR/file1.txt" "$TEST_DIR/file2.txt" >/dev/null 2>&1
}

# Test bash implementation
test_bash_implementation() {
    local output
    output=$("$ONELINER_SCRIPT" --implementation bash "$TEST_DIR/file1.txt" "$TEST_DIR/file2.txt" 2>/dev/null)
    
    local expected_lines=3
    local actual_lines
    actual_lines=$(echo "$output" | wc -l)
    
    [[ $actual_lines -eq $expected_lines ]]
}

# Test awk implementation
test_awk_implementation() {
    local output
    output=$("$ONELINER_SCRIPT" --implementation awk "$TEST_DIR/file1.txt" "$TEST_DIR/file2.txt" 2>/dev/null)
    
    local expected_lines=3
    local actual_lines
    actual_lines=$(echo "$output" | wc -l)
    
    [[ $actual_lines -eq $expected_lines ]]
}

# Test error handling - missing first file
test_missing_first_file() {
    ! "$ONELINER_SCRIPT" "nonexistent.txt" "$TEST_DIR/file2.txt" >/dev/null 2>&1
}

# Test error handling - missing second file
test_missing_second_file() {
    ! "$ONELINER_SCRIPT" "$TEST_DIR/file1.txt" "nonexistent.txt" >/dev/null 2>&1
}

# Test error handling - invalid output format
test_invalid_output_format() {
    ! "$ONELINER_SCRIPT" --format invalid "$TEST_DIR/file1.txt" "$TEST_DIR/file2.txt" >/dev/null 2>&1
}

# Test error handling - invalid implementation
test_invalid_implementation() {
    ! "$ONELINER_SCRIPT" --implementation invalid "$TEST_DIR/file1.txt" "$TEST_DIR/file2.txt" >/dev/null 2>&1
}

# Test empty files
test_empty_files() {
    local output
    output=$("$ONELINER_SCRIPT" "$TEST_DIR/empty1.txt" "$TEST_DIR/empty2.txt" 2>/dev/null)
    [[ -z "$output" ]]
}

# Test configuration file
test_config_file() {
    local config_file="$TEMP_DIR/test.conf"
    cat > "$config_file" << 'EOF'
LOG_LEVEL=DEBUG
OUTPUT_FORMAT=text
IMPLEMENTATION=awk
EOF
    
    local output
    output=$("$ONELINER_SCRIPT" --config "$config_file" --verbose "$TEST_DIR/file1.txt" "$TEST_DIR/file2.txt" 2>&1)
    [[ "$output" == *"DEBUG"* ]]
}

# Main test runner
main() {
    printf "${YELLOW}=== oneliner.sh Test Suite ===${RESET}\n\n"
    
    # Setup
    log_test "Setting up test data"
    setup_test_data
    log_pass "Test data setup complete"
    
    # Run all tests
    run_test "Basic functionality" test_basic_functionality
    run_test "Help option" test_help_option
    run_test "Version option" test_version_option
    run_test "Verbose mode" test_verbose_mode
    run_test "Debug mode" test_debug_mode
    run_test "Timing option" test_timing_option
    run_test "Custom separator" test_custom_separator
    run_test "JSON output format" test_json_output
    run_test "CSV output format" test_csv_output
    run_test "Bash implementation" test_bash_implementation
    run_test "AWK implementation" test_awk_implementation
    run_test "Missing first file error" test_missing_first_file
    run_test "Missing second file error" test_missing_second_file
    run_test "Invalid output format error" test_invalid_output_format
    run_test "Invalid implementation error" test_invalid_implementation
    run_test "Empty files handling" test_empty_files
    run_test "Configuration file" test_config_file
    
    # Summary
    printf "\n${YELLOW}=== Test Results ===${RESET}\n"
    printf "Tests run: %d\n" $TESTS_RUN
    printf "${GREEN}Tests passed: %d${RESET}\n" $TESTS_PASSED
    printf "${RED}Tests failed: %d${RESET}\n" $TESTS_FAILED
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        printf "\n${GREEN}All tests passed!${RESET}\n"
        exit 0
    else
        printf "\n${RED}Some tests failed.${RESET}\n"
        exit 1
    fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
