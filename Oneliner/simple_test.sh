#!/bin/bash

# Simple, reliable test suite for oneliner.sh
# This version focuses on actually working rather than complex features

echo "=== Simple oneliner.sh Test Suite ==="
echo

SCRIPT="./oneliner.sh"
PASSED=0
FAILED=0
TOTAL=0

# Simple test function
test_command() {
    local name="$1"
    local command="$2"
    local expected_exit_code="${3:-0}"
    
    echo -n "Testing $name... "
    ((TOTAL++))
    
    if eval "$command" >/dev/null 2>&1; then
        actual_exit=$?
    else
        actual_exit=$?
    fi
    
    if [[ $actual_exit -eq $expected_exit_code ]]; then
        echo "PASS"
        ((PASSED++))
    else
        echo "FAIL (exit code: $actual_exit, expected: $expected_exit_code)"
        ((FAILED++))
    fi
}

# Test basic functionality with original files
echo "Testing with original files:"
test_command "basic functionality" "$SCRIPT first.txt second.txt"

# Test help and version
echo
echo "Testing CLI options:"
test_command "help option" "$SCRIPT --help"
test_command "version option" "$SCRIPT --version"

# Test with our test files
echo
echo "Testing with pipe-delimited files:"
test_command "pipe-delimited files" "$SCRIPT test_first.txt test_second.txt"

# Test error conditions
echo
echo "Testing error conditions:"
test_command "missing first file" "$SCRIPT nonexistent.txt second.txt" 1
test_command "missing second file" "$SCRIPT first.txt nonexistent.txt" 1

# Test advanced options
echo
echo "Testing advanced options:"
test_command "verbose mode" "$SCRIPT --verbose first.txt second.txt"
test_command "timing mode" "$SCRIPT --timing first.txt second.txt"
test_command "JSON output" "$SCRIPT --format json first.txt second.txt"
test_command "bash implementation" "$SCRIPT --implementation bash first.txt second.txt"

# Summary
echo
echo "=== Test Results ==="
echo "Total tests: $TOTAL"
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [[ $FAILED -eq 0 ]]; then
    echo "All tests passed!"
    exit 0
else
    echo "Some tests failed."
    exit 1
fi
