#!/bin/bash

# Wordle Game - Refactored for Maintainability
# Usage: ./wordle.sh [unlimit]

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

# Process a single guess
process_guess() {
    local guess="$1"
    
    if ! is_valid_word "$guess"; then
        echo "Please enter a valid word with $WORD_LENGTH letters!"
        return 1
    fi
    
    if is_correct_guess "$guess"; then
        echo "You guessed right!"
        generate_guess_output "$guess"
        GAME_OVER=true
    else
        generate_guess_output "$guess"
    fi
    
    return 0
}

# Get user input for a guess
get_user_guess() {
    local guess
    echo "Enter your guess ($GUESS_COUNT / $MAX_GUESSES):"
    read -r guess
    echo "${guess^^}"  # Convert to uppercase
}

# Check if the game should end due to max guesses reached
check_game_over() {
    if [[ $GUESS_COUNT -ge $MAX_GUESSES ]]; then
        echo "You lose! The word was:"
        echo "$TARGET_WORD"
        GAME_OVER=true
    fi
}

# Main game loop
play_game() {
    while [[ $GAME_OVER != true ]]; do
        ((GUESS_COUNT++))
        
        if [[ $GUESS_COUNT -le $MAX_GUESSES ]]; then
            local user_guess
            user_guess=$(get_user_guess)
            
            if process_guess "$user_guess"; then
                # Valid guess was processed
                continue
            else
                # Invalid guess, don't count it
                ((GUESS_COUNT--))
            fi
        else
            check_game_over
        fi
    done
}

# Main function
main() {
    init_word_list
    select_target_word
    parse_arguments "$@"
    play_game
}

# Run the game if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi