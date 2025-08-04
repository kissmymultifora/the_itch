# Refactor wordle.sh for Maintainability

## Notes
- User requested to refactor wordle.sh to improve maintainability.
- The script is a Bash implementation of Wordle, currently monolithic and procedural.
- The code has repeated logic for output formatting and word validation.
- Identified main functional blocks and refactored script into modular functions with improved variable naming and comments.
- All automated tests now use proper 5-letter words for validation.
- User requested further improvements to make the script even more maintainable.
- Next phase: align advanced maintainability features (config, logging, extensibility) with approach used for oneliner.sh.
- Phase 1 (core infrastructure) now in progress: configuration system, logging, enhanced CLI, error handling.
- EXIT_CODES unbound variable error fixed; script now fails with an unbound variable error for associative array theme (e.g., "CORRECT").
- Associative array theme initialization bug diagnosed; Bash version lacks associative array support.
- Next: Refactor theme handling for Bash compatibility (use simple variables or indexed arrays).
- Phase 1 infrastructure (including Bash-compatible theme handling) is now complete and functional.

## Task List
- [x] Identify main functional blocks in wordle.sh (input, validation, output, game loop)
- [x] Modularize code into functions for each responsibility
- [x] Replace repeated logic with reusable functions
- [x] Add comments and improve variable naming for clarity
- [x] Test refactored script for correctness
- [ ] Analyze script for further maintainability improvements
- [x] Implement Phase 1: core infrastructure
  - [x] Add configuration file support (e.g., .wordle.conf)
  - [x] Add logging/verbose/debug output
  - [x] Enhance CLI with comprehensive argument parsing
  - [x] Add robust error handling and validation
- [x] Test and debug Phase 1 infrastructure
  - [x] Refactor theme handling for Bash compatibility
- [ ] Implement advanced maintainability enhancements (e.g., extensibility hooks, code style)
- [ ] Retest script and update documentation if needed
- [ ] Create comprehensive README.md documentation

## Current Goal
Analyze script for further maintainability improvements