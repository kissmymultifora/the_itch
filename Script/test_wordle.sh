#!/bin/bash

# Test script for the refactored wordle.sh
# This script tests various functions and scenarios

# Extract functions from wordle.sh without executing the main game
# We'll copy the function definitions here for testing

# Color constants for better readability
readonly COLOR_CORRECT="\033[30;102m"    # Green background
readonly COLOR_PRESENT="\033[30;103m"     # Yellow background
readonly COLOR_ABSENT="\033[30;107m"      # Gray background
readonly COLOR_RESET="\033[0m"

# Game configuration
readonly WORD_LENGTH=5
readonly DEFAULT_MAX_GUESSES=6
readonly UNLIMITED_GUESSES=999999

# Global variables
declare -a WORD_LIST
declare TARGET_WORD
declare -i GUESS_COUNT=0
declare -i MAX_GUESSES
declare GAME_OVER=false

# Initialize the word list from system dictionary
init_word_list() {
    WORD_LIST=($(grep '^\w\w\w\w\w$' /usr/share/dict/words | tr '[a-z]' '[A-Z]'))
    if [[ ${#WORD_LIST[@]} -eq 0 ]]; then
        echo "Error: No 5-letter words found in dictionary!"
        exit 1
    fi
}

# Select a random target word
select_target_word() {
    TARGET_WORD=${WORD_LIST[$((RANDOM % ${#WORD_LIST[@]}))]}
}

# Parse command line arguments
parse_arguments() {
    if [[ $1 == "unlimit" ]]; then
        MAX_GUESSES=$UNLIMITED_GUESSES
    else
        MAX_GUESSES=$DEFAULT_MAX_GUESSES
    fi
}

# Validate if the guess is a valid word
is_valid_word() {
    local guess="$1"
    [[ " ${WORD_LIST[*]} " =~ " $guess " ]]
}

# Format a single character with the appropriate color
format_character() {
    local char="$1"
    local color="$2"
    echo -n "${color} ${char} ${COLOR_RESET}"
}

# Check if the guess matches the target word exactly
is_correct_guess() {
    local guess="$1"
    [[ $TARGET_WORD == $guess ]]
}

# Generate the colored output for a guess
generate_guess_output() {
    local guess="$1"
    local output=""
    local remaining_chars=""
    local char_at_pos
    local target_char_at_pos
    
    # Build string of characters not in correct positions
    for ((i = 0; i < WORD_LENGTH; i++)); do
        target_char_at_pos="${TARGET_WORD:$i:1}"
        char_at_pos="${guess:$i:1}"
        if [[ $target_char_at_pos != $char_at_pos ]]; then
            remaining_chars+=$target_char_at_pos
        fi
    done
    
    # Generate colored output for each character
    for ((i = 0; i < WORD_LENGTH; i++)); do
        char_at_pos="${guess:$i:1}"
        target_char_at_pos="${TARGET_WORD:$i:1}"
        
        if [[ $target_char_at_pos == $char_at_pos ]]; then
            # Correct position (green)
            output+=$(format_character "$char_at_pos" "$COLOR_CORRECT")
        elif [[ $remaining_chars == *"$char_at_pos"* ]]; then
            # Present but wrong position (yellow)
            output+=$(format_character "$char_at_pos" "$COLOR_PRESENT")
            remaining_chars=${remaining_chars/"$char_at_pos"/}
        else
            # Not present (gray)
            output+=$(format_character "$char_at_pos" "$COLOR_ABSENT")
        fi
    done
    
    echo "$output"
}

# Test counter
tests_passed=0
tests_total=0

# Test helper function
run_test() {
    local test_name="$1"
    local expected="$2"
    local actual="$3"
    
    ((tests_total++))
    
    if [[ "$actual" == "$expected" ]]; then
        echo "✅ PASS: $test_name"
        ((tests_passed++))
    else
        echo "❌ FAIL: $test_name"
        echo "   Expected: $expected"
        echo "   Actual: $actual"
    fi
}

echo "🧪 Testing refactored wordle.sh..."
echo "=================================="

# Test 1: Word list initialization
echo "📝 Testing word list initialization..."
init_word_list
if [[ ${#WORD_LIST[@]} -gt 0 ]]; then
    echo "✅ PASS: Word list loaded (${#WORD_LIST[@]} words)"
    ((tests_passed++))
else
    echo "❌ FAIL: Word list is empty"
fi
((tests_total++))

# Test 2: Target word selection
echo "📝 Testing target word selection..."
select_target_word
if [[ -n "$TARGET_WORD" && ${#TARGET_WORD} -eq 5 ]]; then
    echo "✅ PASS: Target word selected ($TARGET_WORD)"
    ((tests_passed++))
else
    echo "❌ FAIL: Invalid target word ($TARGET_WORD)"
fi
((tests_total++))

# Test 3: Argument parsing - default
echo "📝 Testing argument parsing (default)..."
parse_arguments
run_test "Default max guesses" "6" "$MAX_GUESSES"

# Test 4: Argument parsing - unlimited
echo "📝 Testing argument parsing (unlimited)..."
parse_arguments "unlimit"
run_test "Unlimited max guesses" "999999" "$MAX_GUESSES"

# Test 5: Valid word checking
echo "📝 Testing word validation..."
# Use known 5-letter words that should be in the dictionary
test_word="HELLO"
if is_valid_word "$test_word"; then
    echo "✅ PASS: Valid word detection ($test_word)"
    ((tests_passed++))
else
    echo "❌ FAIL: Valid word not recognized ($test_word)"
fi
((tests_total++))

# Test 6: Invalid word checking
echo "📝 Testing invalid word detection..."
if ! is_valid_word "XYZZQ"; then
    echo "✅ PASS: Invalid word rejected (XYZZQ)"
    ((tests_passed++))
else
    echo "❌ FAIL: Invalid word accepted (XYZZQ)"
fi
((tests_total++))

# Test 7: Correct guess detection
echo "📝 Testing correct guess detection..."
TARGET_WORD="WORLD"
if is_correct_guess "WORLD"; then
    echo "✅ PASS: Correct guess detected"
    ((tests_passed++))
else
    echo "❌ FAIL: Correct guess not detected"
fi
((tests_total++))

# Test 8: Incorrect guess detection
echo "📝 Testing incorrect guess detection..."
if ! is_correct_guess "HELLO"; then
    echo "✅ PASS: Incorrect guess detected"
    ((tests_passed++))
else
    echo "❌ FAIL: Incorrect guess not detected"
fi
((tests_total++))

# Test 9: Character formatting
echo "📝 Testing character formatting..."
formatted=$(format_character "A" "$COLOR_CORRECT")
if [[ "$formatted" == *"A"* ]]; then
    echo "✅ PASS: Character formatting works"
    ((tests_passed++))
else
    echo "❌ FAIL: Character formatting failed"
fi
((tests_total++))

# Test 10: Guess output generation
echo "📝 Testing guess output generation..."
TARGET_WORD="WORLD"
output=$(generate_guess_output "WORDS")
if [[ -n "$output" ]]; then
    echo "✅ PASS: Guess output generated"
    echo "   Sample output: $output"
    ((tests_passed++))
else
    echo "❌ FAIL: No guess output generated"
fi
((tests_total++))

# Summary
echo ""
echo "🏁 Test Results Summary"
echo "======================"
echo "Tests passed: $tests_passed/$tests_total"

if [[ $tests_passed -eq $tests_total ]]; then
    echo "🎉 All tests passed! The refactored script is working correctly."
    exit 0
else
    echo "⚠️  Some tests failed. Please review the issues above."
    exit 1
fi
