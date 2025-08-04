#!/bin/bash

# =============================================================================
# Wordle Game - Enhanced for Maximum Maintainability
# =============================================================================
# Author: Enhanced Maintainability Team
# Version: 2.0
# Description: A command-line implementation of the Wordle word guessing game
#              with enterprise-grade maintainability features
# Usage: ./wordle.sh [OPTIONS]
# License: MIT
# =============================================================================

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# =============================================================================
# SCRIPT METADATA AND CONSTANTS
# =============================================================================

# Script metadata
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_VERSION="2.0"
readonly SCRIPT_AUTHOR="Enhanced Maintainability Team"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default configuration file
readonly DEFAULT_CONFIG_FILE="${SCRIPT_DIR}/.wordle.conf"

# Default game configuration
readonly DEFAULT_WORD_LENGTH=5
readonly DEFAULT_MAX_GUESSES=6
readonly UNLIMITED_GUESSES=999999
readonly DEFAULT_DICT_PATH="/usr/share/dict/words"
readonly DEFAULT_LOG_LEVEL="INFO"
readonly DEFAULT_THEME="classic"

# Exit codes for better error handling
readonly EXIT_SUCCESS=0
readonly EXIT_GENERAL_ERROR=1
readonly EXIT_INVALID_ARGS=2
readonly EXIT_DICT_ERROR=3
readonly EXIT_INPUT_ERROR=4
readonly EXIT_CONFIG_ERROR=5

# Logging levels
readonly LOG_ERROR=1
readonly LOG_WARN=2
readonly LOG_INFO=3
readonly LOG_DEBUG=4

# =============================================================================
# COLOR THEMES
# =============================================================================

# Current theme colors (populated by init_theme function)
COLOR_CORRECT=""
COLOR_PRESENT=""
COLOR_ABSENT=""
COLOR_RESET=""
COLOR_BOLD=""
COLOR_DIM=""
COLOR_SUCCESS=""
COLOR_ERROR=""
COLOR_WARN=""
COLOR_INFO=""

# =============================================================================
# CONFIGURATION VARIABLES
# =============================================================================

# Game configuration (can be overridden by config file or CLI)
WORD_LENGTH="$DEFAULT_WORD_LENGTH"
MAX_GUESSES="$DEFAULT_MAX_GUESSES"
DICT_PATH="$DEFAULT_DICT_PATH"
LOG_LEVEL="$DEFAULT_LOG_LEVEL"
THEME="$DEFAULT_THEME"
CONFIG_FILE="$DEFAULT_CONFIG_FILE"

# Runtime options
VERBOSE=false
DEBUG_MODE=false
SHOW_STATS=false
SHOW_TIMING=false
QUIET_MODE=false
PRACTICE_MODE=false
CUSTOM_WORD_LIST=""

# Game state variables
declare -a g_word_list=()
declare g_target_word=""
declare -i g_guess_count=0
declare g_game_over=false
declare g_start_time=""

# Statistics tracking
declare -i g_games_played=0
declare -i g_games_won=0
declare -i g_total_guesses=0

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Get numeric log level
get_log_level_num() {
    local level
    level=$(echo "$1" | tr '[:lower:]' '[:upper:]')
    case "$level" in
        ERROR) echo $LOG_ERROR ;;
        WARN|WARNING) echo $LOG_WARN ;;
        INFO) echo $LOG_INFO ;;
        DEBUG) echo $LOG_DEBUG ;;
        *) echo $LOG_INFO ;;
    esac
}

# Initialize current theme with simple variables for Bash compatibility
init_theme() {
    local theme_name="$1"
    
    case "$theme_name" in
        classic)
            COLOR_CORRECT="\033[30;102m"     # Green background
            COLOR_PRESENT="\033[30;103m"     # Yellow background
            COLOR_ABSENT="\033[30;107m"      # Gray background
            COLOR_RESET="\033[0m"            # Reset formatting
            COLOR_BOLD="\033[1m"             # Bold text
            COLOR_DIM="\033[2m"              # Dim text
            COLOR_SUCCESS="\033[0;32m"       # Green text
            COLOR_ERROR="\033[0;31m"         # Red text
            COLOR_WARN="\033[1;33m"          # Yellow text
            COLOR_INFO="\033[0;34m"          # Blue text
            ;;
        high-contrast)
            COLOR_CORRECT="\033[37;42m"      # White on green
            COLOR_PRESENT="\033[30;43m"      # Black on yellow
            COLOR_ABSENT="\033[37;40m"       # White on black
            COLOR_RESET="\033[0m"
            COLOR_BOLD="\033[1m"
            COLOR_DIM="\033[2m"
            COLOR_SUCCESS="\033[1;32m"
            COLOR_ERROR="\033[1;31m"
            COLOR_WARN="\033[1;33m"
            COLOR_INFO="\033[1;34m"
            ;;
        colorblind)
            COLOR_CORRECT="\033[37;44m"      # White on blue
            COLOR_PRESENT="\033[30;46m"      # Black on cyan
            COLOR_ABSENT="\033[37;40m"       # White on black
            COLOR_RESET="\033[0m"
            COLOR_BOLD="\033[1m"
            COLOR_DIM="\033[2m"
            COLOR_SUCCESS="\033[1;36m"
            COLOR_ERROR="\033[1;35m"
            COLOR_WARN="\033[1;33m"
            COLOR_INFO="\033[1;34m"
            ;;
        *)
            # For unknown themes, use classic as fallback
            COLOR_CORRECT="\033[30;102m"
            COLOR_PRESENT="\033[30;103m"
            COLOR_ABSENT="\033[30;107m"
            COLOR_RESET="\033[0m"
            COLOR_BOLD="\033[1m"
            COLOR_DIM="\033[2m"
            COLOR_SUCCESS="\033[0;32m"
            COLOR_ERROR="\033[0;31m"
            COLOR_WARN="\033[1;33m"
            COLOR_INFO="\033[0;34m"
            ;;
    esac
}

# Logging functions
log_message() {
    local level="$1"
    local message="$2"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    local level_num current_level_num
    
    level_num=$(get_log_level_num "$level")
    current_level_num=$(get_log_level_num "$LOG_LEVEL")
    
    # Only log if message level is <= current log level
    if [[ $level_num -le $current_level_num ]]; then
        local level_upper color
        level_upper=$(echo "$level" | tr '[:lower:]' '[:upper:]')
        
        case "$level_upper" in
            ERROR) color="$COLOR_ERROR" ;;
            WARN|WARNING) color="$COLOR_WARN" ;;
            INFO) color="$COLOR_INFO" ;;
            DEBUG) color="$COLOR_DIM" ;;
        esac
        
        if [[ "$DEBUG_MODE" == "true" ]]; then
            printf "%s[%s] %s: %s%s\n" "$color" "$timestamp" "$level_upper" "$message" "$COLOR_RESET" >&2
        elif [[ "$VERBOSE" == "true" ]]; then
            printf "%s%s: %s%s\n" "$color" "$level_upper" "$message" "$COLOR_RESET" >&2
        else
            printf "%s%s%s\n" "$color" "$message" "$COLOR_RESET" 
        fi
    fi
}

log_error() { log_message "ERROR" "$1"; }
log_warn() { log_message "WARN" "$1"; }
log_info() { log_message "INFO" "$1"; }
log_debug() { log_message "DEBUG" "$1"; }

# Performance timing functions
start_timer() {
    echo "$(date +%s.%N)"
}

end_timer() {
    local start_time="$1"
    local end_time="$(date +%s.%N)"
    echo "$end_time - $start_time" | bc -l 2>/dev/null || awk "BEGIN {print $end_time - $start_time}"
}

format_duration() {
    local duration="$1"
    local seconds
    
    if command -v bc >/dev/null 2>&1; then
        seconds=$(echo "$duration" | bc -l)
    else
        seconds="$duration"
    fi
    
    if (( $(echo "$seconds < 60" | bc -l 2>/dev/null || echo "$seconds < 60" | awk '{print ($1 < 60)}') )); then
        printf "%.3fs" "$seconds"
    else
        printf "%.1fm" "$(echo "$seconds / 60" | bc -l 2>/dev/null || awk "BEGIN {print $seconds / 60}")"
    fi
}

# Cleanup function for graceful exit
cleanup() {
    local exit_code=${1:-$EXIT_SUCCESS}
    log_debug "Cleaning up and exiting with code $exit_code"
    exit "$exit_code"
}

# Error handler
error_handler() {
    local line_no=$1
    local error_code=$2
    log_error "An error occurred on line $line_no (exit code: $error_code)"
    cleanup "$EXIT_GENERAL_ERROR"
}

# Set up error handling
trap 'error_handler ${LINENO} $?' ERR
trap 'cleanup' EXIT INT TERM

# =============================================================================
# CONFIGURATION SYSTEM
# =============================================================================

# Load configuration from file
load_config() {
    local config_file="$1"
    
    if [[ -f "$config_file" ]]; then
        log_debug "Loading configuration from: $config_file"
        
        while IFS='=' read -r key value; do
            # Skip comments and empty lines
            [[ "$key" =~ ^[[:space:]]*# ]] && continue
            [[ -z "$key" ]] && continue
            
            # Remove leading/trailing whitespace
            key=$(echo "$key" | xargs)
            value=$(echo "$value" | xargs)
            
            # Set configuration variables
            case "$key" in
                WORD_LENGTH) 
                    if [[ "$value" =~ ^[0-9]+$ ]] && [[ $value -ge 3 ]] && [[ $value -le 10 ]]; then
                        WORD_LENGTH="$value"
                    else
                        log_warn "Invalid WORD_LENGTH in config: $value (using default: $DEFAULT_WORD_LENGTH)"
                    fi
                    ;;
                MAX_GUESSES)
                    if [[ "$value" =~ ^[0-9]+$ ]] && [[ $value -ge 1 ]]; then
                        MAX_GUESSES="$value"
                    else
                        log_warn "Invalid MAX_GUESSES in config: $value (using default: $DEFAULT_MAX_GUESSES)"
                    fi
                    ;;
                DICT_PATH) 
                    if [[ -f "$value" ]]; then
                        DICT_PATH="$value"
                    else
                        log_warn "Dictionary file not found: $value (using default: $DEFAULT_DICT_PATH)"
                    fi
                    ;;
                LOG_LEVEL) LOG_LEVEL="$value" ;;
                THEME) THEME="$value" ;;
                VERBOSE) [[ "$value" =~ ^(true|1|yes)$ ]] && VERBOSE=true ;;
                DEBUG_MODE) [[ "$value" =~ ^(true|1|yes)$ ]] && DEBUG_MODE=true ;;
                SHOW_STATS) [[ "$value" =~ ^(true|1|yes)$ ]] && SHOW_STATS=true ;;
                QUIET_MODE) [[ "$value" =~ ^(true|1|yes)$ ]] && QUIET_MODE=true ;;
                *) log_warn "Unknown configuration option: $key" ;;
            esac
        done < "$config_file"
        
        log_info "Configuration loaded successfully"
    else
        log_debug "Configuration file not found: $config_file (using defaults)"
    fi
}

# =============================================================================
# HELP AND VERSION FUNCTIONS
# =============================================================================

# Display usage information
show_usage() {
    cat << EOF
${COLOR_BOLD}$SCRIPT_NAME v$SCRIPT_VERSION${COLOR_RESET}

A command-line implementation of the Wordle word guessing game with
enterprise-grade maintainability features.

${COLOR_BOLD}USAGE:${COLOR_RESET}
    $SCRIPT_NAME [OPTIONS]

${COLOR_BOLD}OPTIONS:${COLOR_RESET}
    -h, --help              Show this help message
    -v, --version           Show version information
    -c, --config FILE       Use custom configuration file
    -d, --debug             Enable debug mode with detailed logging
    -V, --verbose           Enable verbose output
    -q, --quiet             Suppress non-essential output
    -s, --stats             Show game statistics
    -t, --timing            Show timing information
    -p, --practice          Enable practice mode (hints available)
    -w, --word-list FILE    Use custom word list file
    -l, --length N          Set word length (3-10, default: $DEFAULT_WORD_LENGTH)
    -g, --guesses N         Set maximum guesses (default: $DEFAULT_MAX_GUESSES)
    -T, --theme THEME       Set color theme (classic, high-contrast, colorblind)
    --unlimit               Allow unlimited guesses

${COLOR_BOLD}THEMES:${COLOR_RESET}
    classic                 Default green/yellow/gray theme
    high-contrast           High contrast theme for better visibility
    colorblind              Colorblind-friendly blue/cyan/black theme

${COLOR_BOLD}CONFIGURATION:${COLOR_RESET}
    Configuration can be set via $DEFAULT_CONFIG_FILE or specified config file.
    Command line options override configuration file settings.

${COLOR_BOLD}EXAMPLES:${COLOR_RESET}
    $SCRIPT_NAME                    # Play with default settings
    $SCRIPT_NAME --debug --timing   # Play with debug info and timing
    $SCRIPT_NAME --theme colorblind # Use colorblind-friendly theme
    $SCRIPT_NAME --length 6 -g 8    # Play with 6-letter words, 8 guesses
    $SCRIPT_NAME --practice         # Practice mode with hints

EOF
}

# Show version information
show_version() {
    echo "$SCRIPT_NAME version $SCRIPT_VERSION"
    echo "Author: $SCRIPT_AUTHOR"
    echo "License: MIT"
}

# =============================================================================
# ENHANCED GAME FUNCTIONS
# =============================================================================

# Initialize the word list from dictionary with enhanced error handling
init_word_list() {
    log_debug "Initializing word list from $DICT_PATH (length: $WORD_LENGTH)"
    
    if [[ -n "$CUSTOM_WORD_LIST" ]] && [[ -f "$CUSTOM_WORD_LIST" ]]; then
        log_debug "Using custom word list: $CUSTOM_WORD_LIST"
        mapfile -t g_word_list < <(
            grep -i "^[a-zA-Z]\{$WORD_LENGTH\}$" "$CUSTOM_WORD_LIST" 2>/dev/null | \
            tr '[:lower:]' '[:upper:]' | \
            sort -u
        )
    else
        # Use system dictionary
        local word_pattern="^[a-zA-Z]\{$WORD_LENGTH\}$"
        mapfile -t g_word_list < <(
            grep -i "$word_pattern" "$DICT_PATH" 2>/dev/null | \
            tr '[:lower:]' '[:upper:]' | \
            sort -u
        )
    fi
    
    if [[ ${#g_word_list[@]} -eq 0 ]]; then
        log_error "No $WORD_LENGTH-letter words found in dictionary: $DICT_PATH"
        log_error "Please check your dictionary file or use --word-list option"
        cleanup "$EXIT_DICT_ERROR"
    fi
    
    log_debug "Loaded ${#g_word_list[@]} words from dictionary"
}

# Select a random target word with enhanced randomization
select_target_word() {
    if [[ ${#g_word_list[@]} -eq 0 ]]; then
        log_error "Word list is empty. Cannot select target word."
        cleanup "$EXIT_DICT_ERROR"
    fi
    
    local random_index=$((RANDOM % ${#g_word_list[@]}))
    g_target_word="${g_word_list[$random_index]}"
    
    log_debug "Selected target word: $g_target_word"
}

# Enhanced argument parsing with comprehensive options
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                cleanup "$EXIT_SUCCESS"
                ;;
            -v|--version)
                show_version
                cleanup "$EXIT_SUCCESS"
                ;;
            -c|--config)
                if [[ -n "$2" ]]; then
                    CONFIG_FILE="$2"
                    shift 2
                else
                    log_error "--config requires a file path"
                    cleanup "$EXIT_INVALID_ARGS"
                fi
                ;;
            -d|--debug)
                DEBUG_MODE=true
                VERBOSE=true
                LOG_LEVEL="DEBUG"
                shift
                ;;
            -V|--verbose)
                VERBOSE=true
                if [[ "$LOG_LEVEL" == "$DEFAULT_LOG_LEVEL" ]]; then
                    LOG_LEVEL="INFO"
                fi
                shift
                ;;
            -q|--quiet)
                QUIET_MODE=true
                LOG_LEVEL="ERROR"
                shift
                ;;
            -s|--stats)
                SHOW_STATS=true
                shift
                ;;
            -t|--timing)
                SHOW_TIMING=true
                shift
                ;;
            -p|--practice)
                PRACTICE_MODE=true
                log_info "Practice mode enabled (hints available)"
                shift
                ;;
            -w|--word-list)
                if [[ -n "$2" ]] && [[ -f "$2" ]]; then
                    CUSTOM_WORD_LIST="$2"
                    shift 2
                else
                    log_error "--word-list requires a valid file path"
                    cleanup "$EXIT_INVALID_ARGS"
                fi
                ;;
            -l|--length)
                if [[ -n "$2" ]] && [[ "$2" =~ ^[0-9]+$ ]] && [[ $2 -ge 3 ]] && [[ $2 -le 10 ]]; then
                    WORD_LENGTH="$2"
                    shift 2
                else
                    log_error "--length requires a number between 3 and 10"
                    cleanup "$EXIT_INVALID_ARGS"
                fi
                ;;
            -g|--guesses)
                if [[ -n "$2" ]] && [[ "$2" =~ ^[0-9]+$ ]] && [[ $2 -ge 1 ]]; then
                    MAX_GUESSES="$2"
                    shift 2
                else
                    log_error "--guesses requires a positive number"
                    cleanup "$EXIT_INVALID_ARGS"
                fi
                ;;
            -T|--theme)
                if [[ -n "$2" ]]; then
                    case "$2" in
                        classic|high-contrast|colorblind)
                            THEME="$2"
                            ;;
                        *)
                            log_error "Invalid theme: $2. Available: classic, high-contrast, colorblind"
                            cleanup "$EXIT_INVALID_ARGS"
                            ;;
                    esac
                    shift 2
                else
                    log_error "--theme requires a theme name"
                    cleanup "$EXIT_INVALID_ARGS"
                fi
                ;;
            --unlimit|unlimit)
                MAX_GUESSES=$UNLIMITED_GUESSES
                log_debug "Unlimited guesses mode enabled"
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                log_error "Use --help for usage information"
                cleanup "$EXIT_INVALID_ARGS"
                ;;
            *)
                log_error "Unknown argument: $1"
                log_error "Use --help for usage information"
                cleanup "$EXIT_INVALID_ARGS"
                ;;
        esac
    done
}

# Enhanced word validation with performance optimization
is_valid_word() {
    local guess="$1"
    
    # Use associative array for O(1) lookup if word list is large
    if [[ ${#g_word_list[@]} -gt 1000 ]]; then
        local -A word_dict
        for word in "${g_word_list[@]}"; do
            word_dict["$word"]=1
        done
        [[ -n "${word_dict[$guess]:-}" ]]
    else
        # Use pattern matching for smaller lists
        [[ " ${g_word_list[*]} " =~ " $guess " ]]
    fi
}

# Enhanced character formatting with validation
format_character() {
    local char="$1"
    local color_key="$2"
    
    local color_code=""
    case "$color_key" in
        CORRECT) color_code="$COLOR_CORRECT" ;;
        PRESENT) color_code="$COLOR_PRESENT" ;;
        ABSENT) color_code="$COLOR_ABSENT" ;;
        *) 
            log_warn "Color key '$color_key' not found in theme"
            printf " %s " "$char"
            return
            ;;
    esac
    
    printf "%s %s %s" "$color_code" "$char" "$COLOR_RESET"
}

# Check if the guess matches the target word exactly
is_correct_guess() {
    local guess="$1"
    [[ "$g_target_word" == "$guess" ]]
}

# Input validation function
validate_input() {
    local input="$1"
    
    # Check length
    if [[ ${#input} -ne $WORD_LENGTH ]]; then
        return 1
    fi
    
    # Check if contains only letters
    if [[ ! $input =~ ^[A-Z]+$ ]]; then
        return 1
    fi
    
    return 0
}

# Enhanced guess output generation with improved algorithm
generate_guess_output() {
    local guess="$1"
    local output=""
    local -A target_char_count remaining_char_count
    local char target_char
    
    # Count characters in target word
    for ((i = 0; i < WORD_LENGTH; i++)); do
        char="${g_target_word:$i:1}"
        ((target_char_count["$char"]++))
    done
    
    # Copy for tracking remaining characters
    for char in "${!target_char_count[@]}"; do
        remaining_char_count["$char"]=${target_char_count["$char"]}
    done
    
    # First pass: mark correct positions
    local -a result_colors
    for ((i = 0; i < WORD_LENGTH; i++)); do
        char="${guess:$i:1}"
        target_char="${g_target_word:$i:1}"
        
        if [[ "$char" == "$target_char" ]]; then
            result_colors[i]="CORRECT"
            ((remaining_char_count["$char"]--)) || true
        else
            result_colors[i]=""
        fi
    done
    
    # Second pass: mark present characters
    for ((i = 0; i < WORD_LENGTH; i++)); do
        if [[ -n "${result_colors[i]}" ]]; then
            continue  # Already marked as correct
        fi
        
        char="${guess:$i:1}"
        if [[ ${remaining_char_count["$char"]:-0} -gt 0 ]]; then
            result_colors[i]="PRESENT"
            ((remaining_char_count["$char"]--)) || true
        else
            result_colors[i]="ABSENT"
        fi
    done
    
    # Generate output
    for ((i = 0; i < WORD_LENGTH; i++)); do
        char="${guess:$i:1}"
        output+=$(format_character "$char" "${result_colors[i]}")
    done
    
    echo "$output"
}

# Enhanced guess processing with better error handling
process_guess() {
    local guess="$1"
    
    # Validate input format
    if ! validate_input "$guess"; then
        log_error "Invalid input format. Please enter exactly $WORD_LENGTH letters."
        return 1
    fi
    
    # Validate word existence
    if ! is_valid_word "$guess"; then
        log_error "'$guess' is not a valid $WORD_LENGTH-letter word."
        if [[ "$PRACTICE_MODE" == "true" ]]; then
            log_info "Hint: Try common English words with $WORD_LENGTH letters"
        fi
        return 1
    fi
    
    # Process the guess
    if is_correct_guess "$guess"; then
        echo "${COLOR_BOLD}🎉 Congratulations! You guessed it!${COLOR_RESET}"
        generate_guess_output "$guess"
        g_game_over=true
        ((g_games_won++))
    else
        generate_guess_output "$guess"
        if [[ "$PRACTICE_MODE" == "true" ]] && [[ $g_guess_count -ge $((MAX_GUESSES / 2)) ]]; then
            provide_hint "$guess"
        fi
    fi
    
    return 0
}

# Provide hints in practice mode
provide_hint() {
    local guess="$1"
    local hint_msg=""
    local correct_count=0
    local present_count=0
    
    # Count correct and present letters
    for ((i = 0; i < WORD_LENGTH; i++)); do
        local char="${guess:$i:1}"
        local target_char="${g_target_word:$i:1}"
        
        if [[ "$char" == "$target_char" ]]; then
            ((correct_count++))
        elif [[ "$g_target_word" == *"$char"* ]]; then
            ((present_count++))
        fi
    done
    
    if [[ $correct_count -gt 0 ]] || [[ $present_count -gt 0 ]]; then
        hint_msg="💡 Hint: You have $correct_count letters in correct positions"
        if [[ $present_count -gt 0 ]]; then
            hint_msg+=" and $present_count letters in wrong positions"
        fi
        log_info "$hint_msg"
    else
        log_info "💡 Hint: None of these letters are in the target word"
    fi
}

# Enhanced user input with validation
get_user_guess() {
    local guess
    local prompt="Enter your guess (${g_guess_count}/${MAX_GUESSES}): "
    
    while true; do
        echo -n "$prompt"
        if ! read -r guess; then
            log_error "Failed to read input"
            cleanup "$EXIT_INPUT_ERROR"
        fi
        
        # Convert to uppercase and trim whitespace
        guess=$(echo "$guess" | tr '[:lower:]' '[:upper:]' | xargs)
        
        # Basic validation
        if [[ -n "$guess" ]]; then
            echo "$guess"
            return 0
        else
            echo "Please enter a word."
        fi
    done
}

# Check if the game should end due to max guesses reached
check_game_over() {
    if [[ $g_guess_count -ge $MAX_GUESSES ]]; then
        echo "${COLOR_ERROR}💀 Game Over! The word was:${COLOR_RESET}"
        echo "${COLOR_BOLD}$g_target_word${COLOR_RESET}"
        g_game_over=true
    fi
}

# Enhanced main game loop with statistics tracking
play_game() {
    log_debug "Starting game with $WORD_LENGTH-letter word, max $MAX_GUESSES guesses"
    
    while [[ $g_game_over != true ]]; do
        ((g_guess_count++))
        ((g_total_guesses++))
        
        if [[ $g_guess_count -le $MAX_GUESSES ]]; then
            local user_guess
            user_guess=$(get_user_guess)
            
            if process_guess "$user_guess"; then
                # Valid guess was processed
                log_debug "Processed guess $g_guess_count: $user_guess"
                continue
            else
                # Invalid guess, don't count it
                ((g_guess_count--))
                ((g_total_guesses--))
            fi
        else
            check_game_over
        fi
    done
    
    ((g_games_played++))
    log_debug "Game completed. Total games: $g_games_played, Won: $g_games_won"
}

# Display game statistics
show_stats() {
    if [[ $g_games_played -eq 0 ]]; then
        log_info "No games played yet."
        return
    fi
    
    local win_rate
    win_rate=$(echo "scale=1; $g_games_won * 100 / $g_games_played" | bc -l 2>/dev/null || awk "BEGIN {printf \"%.1f\", $g_games_won * 100 / $g_games_played}")
    
    local avg_guesses
    if [[ $g_games_won -gt 0 ]]; then
        avg_guesses=$(echo "scale=1; $g_total_guesses / $g_games_won" | bc -l 2>/dev/null || awk "BEGIN {printf \"%.1f\", $g_total_guesses / $g_games_won}")
    else
        avg_guesses="N/A"
    fi
    
    echo
    echo "${COLOR_BOLD}📊 Game Statistics${COLOR_RESET}"
    echo "${COLOR_DIM}==================${COLOR_RESET}"
    echo "Games Played: $g_games_played"
    echo "Games Won: $g_games_won"
    echo "Win Rate: $win_rate%"
    echo "Average Guesses (wins): $avg_guesses"
    echo
}

# Enhanced main function with proper initialization
main() {
    local start_time duration
    
    # Initialize theme first (needed for logging colors)
    init_theme "$THEME"
    
    # Load configuration file first (before parsing arguments so CLI can override)
    load_config "$CONFIG_FILE"
    
    # Parse command line arguments (overrides config file settings)
    parse_arguments "$@"
    
    # Re-initialize theme in case it was changed by arguments
    init_theme "$THEME"
    
    log_debug "Starting $SCRIPT_NAME v$SCRIPT_VERSION"
    log_debug "Configuration: length=$WORD_LENGTH, guesses=$MAX_GUESSES, theme=$THEME"
    
    # Start timing if requested
    if [[ "$SHOW_TIMING" == "true" ]]; then
        start_time=$(start_timer)
        log_info "Starting Wordle game..."
    fi
    
    # Initialize game components
    init_word_list
    select_target_word
    
    # Show game header
    if [[ "$QUIET_MODE" != "true" ]]; then
        echo
        echo "${COLOR_BOLD}🎯 Wordle v$SCRIPT_VERSION${COLOR_RESET}"
        echo "${COLOR_DIM}Guess the $WORD_LENGTH-letter word in $MAX_GUESSES tries!${COLOR_RESET}"
        if [[ "$PRACTICE_MODE" == "true" ]]; then
            echo "${COLOR_INFO}💡 Practice mode: Hints available${COLOR_RESET}"
        fi
        echo
    fi
    
    # Play the game
    play_game
    
    # Show statistics if requested
    if [[ "$SHOW_STATS" == "true" ]]; then
        show_stats
    fi
    
    # Show timing information if requested
    if [[ "$SHOW_TIMING" == "true" ]]; then
        duration=$(end_timer "$start_time")
        log_info "Game completed in $(format_duration "$duration")"
    fi
    
    log_debug "$SCRIPT_NAME completed successfully"
}

# Run the game if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi