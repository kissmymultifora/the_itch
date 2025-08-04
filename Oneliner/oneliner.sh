#!/bin/bash

# File Comparison Script
# Compares two pipe-delimited files and outputs lines from the second file
# that don't exist in the first file (ignoring the first two fields)
#
# Version: 2.0
# Author: Refactored for maintainability
# License: MIT

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Script metadata
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_VERSION="2.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default configuration
readonly DEFAULT_CONFIG_FILE="${SCRIPT_DIR}/.oneliner.conf"
readonly DEFAULT_FIELD_SEPARATOR='|'
readonly DEFAULT_FIRST_FILE="first.txt"
readonly DEFAULT_SECOND_FILE="second.txt"
readonly DEFAULT_LOG_LEVEL="INFO"
readonly DEFAULT_OUTPUT_FORMAT="text"
readonly DEFAULT_IMPLEMENTATION="awk"

# Configuration variables (can be overridden by config file or command line)
FIELD_SEPARATOR="$DEFAULT_FIELD_SEPARATOR"
FIRST_FILE=""
SECOND_FILE=""
LOG_LEVEL="$DEFAULT_LOG_LEVEL"
OUTPUT_FORMAT="$DEFAULT_OUTPUT_FORMAT"
IMPLEMENTATION="$DEFAULT_IMPLEMENTATION"
VERBOSE=false
SHOW_TIMING=false
CONFIG_FILE="$DEFAULT_CONFIG_FILE"

# Logging levels
readonly LOG_ERROR=1
readonly LOG_WARN=2
readonly LOG_INFO=3
readonly LOG_DEBUG=4

# Color codes for output
readonly COLOR_RED='\033[0;31m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_RESET='\033[0m'

# Logging functions
get_log_level_num() {
    local level
    level=$(echo "$1" | tr '[:lower:]' '[:upper:]')  # Convert to uppercase
    case "$level" in
        ERROR) echo $LOG_ERROR ;;
        WARN|WARNING) echo $LOG_WARN ;;
        INFO) echo $LOG_INFO ;;
        DEBUG) echo $LOG_DEBUG ;;
        *) echo $LOG_INFO ;;  # Default to INFO
    esac
}

log_message() {
    local level="$1"
    local message="$2"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    local level_num
    local current_level_num
    local color=""
    
    level_num=$(get_log_level_num "$level")
    current_level_num=$(get_log_level_num "$LOG_LEVEL")
    
    # Only log if message level is <= current log level
    if [[ $level_num -le $current_level_num ]]; then
        local level_upper
        level_upper=$(echo "$level" | tr '[:lower:]' '[:upper:]')
        case "$level_upper" in
            ERROR) color="$COLOR_RED" ;;
            WARN|WARNING) color="$COLOR_YELLOW" ;;
            INFO) color="$COLOR_GREEN" ;;
            DEBUG) color="$COLOR_BLUE" ;;
        esac
        
        if [[ "$VERBOSE" == "true" ]]; then
            printf "${color}[%s] %s: %s${COLOR_RESET}\n" "$timestamp" "$level_upper" "$message" >&2
        elif [[ "$level_upper" == "ERROR" ]] || [[ "$level_upper" == "WARN" ]]; then
            printf "${color}%s: %s${COLOR_RESET}\n" "$level_upper" "$message" >&2
        fi
    fi
}

log_error() { log_message "ERROR" "$1"; }
log_warn() { log_message "WARN" "$1"; }
log_info() { log_message "INFO" "$1"; }
log_debug() { log_message "DEBUG" "$1"; }

# Load configuration from file
load_config() {
    local config_file="$1"
    
    if [[ -f "$config_file" ]]; then
        log_debug "Loading configuration from: $config_file"
        
        # Source the config file safely
        while IFS='=' read -r key value; do
            # Skip comments and empty lines
            [[ "$key" =~ ^[[:space:]]*# ]] && continue
            [[ -z "$key" ]] && continue
            
            # Remove leading/trailing whitespace
            key=$(echo "$key" | xargs)
            value=$(echo "$value" | xargs)
            
            # Set configuration variables
            case "$key" in
                FIELD_SEPARATOR) FIELD_SEPARATOR="$value" ;;
                LOG_LEVEL) LOG_LEVEL="$value" ;;
                OUTPUT_FORMAT) OUTPUT_FORMAT="$value" ;;
                IMPLEMENTATION) IMPLEMENTATION="$value" ;;
                *) log_warn "Unknown configuration option: $key" ;;
            esac
        done < "$config_file"
        
        log_info "Configuration loaded successfully"
    else
        log_debug "Configuration file not found: $config_file"
    fi
}

# Display usage information
show_usage() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS] [first_file] [second_file]

Compares two delimited files and outputs lines from the second file
that don't exist in the first file (ignoring the first two fields).

Arguments:
  first_file   First file to compare (default: $DEFAULT_FIRST_FILE)
  second_file  Second file to compare (default: $DEFAULT_SECOND_FILE)

Options:
  -h, --help              Show this help message
  -v, --verbose           Enable verbose output
  -d, --debug             Enable debug logging
  -t, --timing            Show timing information
  -c, --config FILE       Use custom configuration file
  -s, --separator SEP     Field separator (default: '$DEFAULT_FIELD_SEPARATOR')
  -f, --format FORMAT     Output format: text, json, csv (default: $DEFAULT_OUTPUT_FORMAT)
  -i, --implementation    Implementation: awk, bash (default: $DEFAULT_IMPLEMENTATION)
  --version               Show version information

Configuration:
  Configuration can be set via ~/.oneliner.conf or specified config file.
  Command line options override configuration file settings.

Examples:
  $SCRIPT_NAME data1.txt data2.txt
  $SCRIPT_NAME --verbose --timing file1.csv file2.csv
  $SCRIPT_NAME --separator ',' --format json input1.csv input2.csv
  $SCRIPT_NAME --config ./custom.conf data1.txt data2.txt
EOF
}

# Show version information
show_version() {
    echo "$SCRIPT_NAME version $SCRIPT_VERSION"
}

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
    local seconds minutes hours
    
    if command -v bc >/dev/null 2>&1; then
        seconds=$(echo "$duration" | bc -l)
    else
        seconds="$duration"
    fi
    
    if (( $(echo "$seconds < 60" | bc -l 2>/dev/null || echo "$seconds < 60" | awk '{print ($1 < 60)}') )); then
        printf "%.3fs" "$seconds"
    elif (( $(echo "$seconds < 3600" | bc -l 2>/dev/null || echo "$seconds < 3600" | awk '{print ($1 < 3600)}') )); then
        minutes=$(echo "$seconds / 60" | bc -l 2>/dev/null || awk "BEGIN {print $seconds / 60}")
        printf "%.1fm" "$minutes"
    else
        hours=$(echo "$seconds / 3600" | bc -l 2>/dev/null || awk "BEGIN {print $seconds / 3600}")
        printf "%.1fh" "$hours"
    fi
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            --version)
                show_version
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                LOG_LEVEL="INFO"
                shift
                ;;
            -d|--debug)
                VERBOSE=true
                LOG_LEVEL="DEBUG"
                shift
                ;;
            -t|--timing)
                SHOW_TIMING=true
                shift
                ;;
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -s|--separator)
                FIELD_SEPARATOR="$2"
                shift 2
                ;;
            -f|--format)
                case "$2" in
                    text|json|csv)
                        OUTPUT_FORMAT="$2"
                        ;;
                    *)
                        log_error "Invalid output format: $2. Supported: text, json, csv"
                        exit 1
                        ;;
                esac
                shift 2
                ;;
            -i|--implementation)
                case "$2" in
                    awk|bash)
                        IMPLEMENTATION="$2"
                        ;;
                    *)
                        log_error "Invalid implementation: $2. Supported: awk, bash"
                        exit 1
                        ;;
                esac
                shift 2
                ;;
            -*)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                # Positional arguments
                if [[ -z "$FIRST_FILE" ]]; then
                    FIRST_FILE="$1"
                elif [[ -z "$SECOND_FILE" ]]; then
                    SECOND_FILE="$1"
                else
                    log_error "Too many arguments provided"
                    show_usage
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # Set defaults if not provided
    FIRST_FILE="${FIRST_FILE:-$DEFAULT_FIRST_FILE}"
    SECOND_FILE="${SECOND_FILE:-$DEFAULT_SECOND_FILE}"
}

# Validate that input files exist and are readable
validate_files() {
    local first_file="$1"
    local second_file="$2"
    
    log_debug "Validating input files: '$first_file' and '$second_file'"
    
    if [[ ! -f "$first_file" ]]; then
        log_error "First file '$first_file' does not exist or is not readable."
        return 1
    fi
    
    if [[ ! -f "$second_file" ]]; then
        log_error "Second file '$second_file' does not exist or is not readable."
        return 1
    fi
    
    # Log file statistics if in debug mode
    if [[ "$LOG_LEVEL" == "DEBUG" ]]; then
        local first_lines second_lines first_size second_size
        first_lines=$(wc -l < "$first_file")
        second_lines=$(wc -l < "$second_file")
        first_size=$(wc -c < "$first_file")
        second_size=$(wc -c < "$second_file")
        
        log_debug "First file: $first_lines lines, $first_size bytes"
        log_debug "Second file: $second_lines lines, $second_size bytes"
    fi
    
    return 0
}

# Output formatting functions
format_output_text() {
    local line="$1"
    echo "$line"
}

format_output_json() {
    local line="$1"
    local fields
    IFS="$FIELD_SEPARATOR" read -ra fields <<< "$line"
    
    printf '{"line":"%s"' "$(echo "$line" | sed 's/"/\\"/g')"
    for i in "${!fields[@]}"; do
        printf ',"field_%d":"%s"' "$((i+1))" "$(echo "${fields[i]}" | sed 's/"/\\"/g')"
    done
    printf '}\n'
}

format_output_csv() {
    local line="$1"
    # Escape quotes and wrap in quotes if contains separator or quotes
    if [[ "$line" == *"$FIELD_SEPARATOR"* ]] || [[ "$line" == *'"'* ]]; then
        line="\"$(echo "$line" | sed 's/"/""/g')\""
    fi
    echo "$line"
}

format_and_output() {
    local line="$1"
    
    case "$OUTPUT_FORMAT" in
        json)
            format_output_json "$line"
            ;;
        csv)
            format_output_csv "$line"
            ;;
        text|*)
            format_output_text "$line"
            ;;
    esac
}

# Extract comparison key from a line (everything except first two fields)
get_comparison_key() {
    local line="$1"
    local field_separator="$2"
    
    # Check if line contains the separator
    if [[ "$line" == *"$field_separator"* ]]; then
        # Use awk to remove first two fields and return the rest
        echo "$line" | awk -F"$field_separator" '{ $1=""; $2=""; print $0 }'
    else
        # For non-delimited files, use the entire line as comparison key
        echo "$line"
    fi
}

# Build a lookup table of keys from the first file
build_lookup_table() {
    local first_file="$1"
    local -n lookup_ref=$2
    local key
    
    while IFS= read -r line; do
        key=$(get_comparison_key "$line" "$FIELD_SEPARATOR")
        lookup_ref["$key"]=1
    done < "$first_file"
}

# Process the second file and output lines not found in the first file
process_second_file() {
    local second_file="$1"
    local -n lookup_ref=$2
    local key
    local line_count=0
    local unique_count=0
    
    log_debug "Processing second file: $second_file"
    
    while IFS= read -r line; do
        ((line_count++))
        key=$(get_comparison_key "$line" "$FIELD_SEPARATOR")
        
        # If key is not in lookup table, output the original line
        if [[ -z "${lookup_ref["$key"]:-}" ]]; then
            format_and_output "$line"
            ((unique_count++))
        fi
    done < "$second_file"
    
    log_debug "Processed $line_count lines, found $unique_count unique lines"
}

# Main comparison function using associative array approach
compare_files_bash() {
    local first_file="$1"
    local second_file="$2"
    
    # Check if associative arrays are supported
    if declare -A test_array 2>/dev/null; then
        # Use associative arrays for efficient lookup
        declare -A seen_keys
        build_lookup_table "$first_file" seen_keys
        process_second_file "$second_file" seen_keys
    else
        # Fallback: use AWK implementation when associative arrays not supported
        log_warn "Associative arrays not supported, falling back to AWK implementation"
        compare_files_awk "$first_file" "$second_file"
    fi
}

# Alternative implementation using AWK (more efficient for large files)
compare_files_awk() {
    local first_file="$1"
    local second_file="$2"
    local unique_count=0
    
    log_debug "Using AWK implementation for file comparison"
    
    # For text output, use the original efficient AWK approach
    if [[ "$OUTPUT_FORMAT" == "text" ]]; then
        awk -F"$FIELD_SEPARATOR" -v sep="$FIELD_SEPARATOR" '
            # First pass: read first file and store comparison keys
            NR == FNR {
                # Check if line contains separator
                if (index($0, sep) > 0) {
                    # Remove first two fields and store the rest as key
                    $1 = ""
                    $2 = ""
                    seen[$0]++
                } else {
                    # For non-delimited files, use entire line as key
                    seen[$0]++
                }
                next
            }
            
            # Second pass: read second file and check for unique lines
            {
                # Store original line
                orig = $0
                
                # Check if line contains separator
                if (index($0, sep) > 0) {
                    # Remove first two fields to create comparison key
                    $1 = ""
                    $2 = ""
                    key = $0
                } else {
                    # For non-delimited files, use entire line as key
                    key = $0
                }
                
                # If key not seen in first file, print original line
                if (!seen[key]) {
                    print orig
                    unique_count++
                }
            }
            
            END {
                if (ENVIRON["LOG_LEVEL"] == "DEBUG") {
                    print "AWK processed " NR-FNR " lines, found " unique_count " unique lines" > "/dev/stderr"
                }
            }
        ' "$first_file" "$second_file"
    else
        # For JSON/CSV output, process line by line to use formatting functions
        # Check if associative arrays are supported
        if declare -A test_array 2>/dev/null; then
            declare -A seen_keys
            build_lookup_table "$first_file" seen_keys
            process_second_file "$second_file" seen_keys
        else
            # Fallback: use AWK even for JSON/CSV (less pretty but functional)
            log_warn "Associative arrays not supported, using AWK fallback for JSON/CSV output"
            awk -F"$FIELD_SEPARATOR" -v sep="$FIELD_SEPARATOR" '
                NR == FNR {
                    if (index($0, sep) > 0) {
                        $1 = ""; $2 = ""; seen[$0]++
                    } else {
                        seen[$0]++
                    }
                    next
                }
                {
                    orig = $0
                    if (index($0, sep) > 0) {
                        $1 = ""; $2 = ""; key = $0
                    } else {
                        key = $0
                    }
                    if (!seen[key]) print orig
                }
            ' "$first_file" "$second_file"
        fi
    fi
}

# Main function
main() {
    local start_time
    local duration
    
    # Load configuration file first (before parsing arguments so CLI can override)
    load_config "$CONFIG_FILE"
    
    # Parse command line arguments (overrides config file settings)
    parse_arguments "$@"
    
    log_debug "Starting $SCRIPT_NAME v$SCRIPT_VERSION"
    log_debug "Configuration: separator='$FIELD_SEPARATOR', format='$OUTPUT_FORMAT', implementation='$IMPLEMENTATION'"
    log_debug "Files: first='$FIRST_FILE', second='$SECOND_FILE'"
    
    # Start timing if requested
    if [[ "$SHOW_TIMING" == "true" ]]; then
        start_time=$(start_timer)
        log_info "Starting file comparison..."
    fi
    
    # Validate input files
    if ! validate_files "$FIRST_FILE" "$SECOND_FILE"; then
        exit 1
    fi
    
    # Output format header for JSON
    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        echo '{"results":['
    fi
    
    # Choose implementation based on configuration
    case "$IMPLEMENTATION" in
        bash)
            log_debug "Using Bash implementation"
            compare_files_bash "$FIRST_FILE" "$SECOND_FILE"
            ;;
        awk|*)
            log_debug "Using AWK implementation"
            compare_files_awk "$FIRST_FILE" "$SECOND_FILE"
            ;;
    esac
    
    # Output format footer for JSON
    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        echo ']}'
    fi
    
    # Show timing information if requested
    if [[ "$SHOW_TIMING" == "true" ]]; then
        duration=$(end_timer "$start_time")
        log_info "File comparison completed in $(format_duration "$duration")"
    fi
    
    log_debug "$SCRIPT_NAME completed successfully"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi