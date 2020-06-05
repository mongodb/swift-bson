#! /usr/bin/env bash

function fixes_help {
    printf '\n\e[35myou got hooked!\e[0m\n'
    echo 'Make sure Lint/Format/Build pass:'
    echo '  make lint all'
    exit 1
}

# All varriables use this syntax A=${A:-something}
# Which means you can override FILES_CHANGED, LINTER, FORMATTER, RUN_COMPILE_CHECK in your environment

# Files changed is a list of the modified files in your git working tree
# notably the --diff-filter argument includes files that are:
#   A: Added, C: Copied, M: Modified, R: Renamed, T: Changed
# This is to omit deleted files as the linters will fail if given them
FILES_CHANGED=${FILES_CHANGED:-$(git diff --diff-filter=ACMRT --stat --cached --name-only '*.swift')}

# Find swiftlint in user's PATH (could be special)
LINTER=${LINTER:-$(which swiftlint)}

# Find swiftformat in user's PATH (could be special)
FORMATTER=${FORMATTER:-$(which swiftformat)}

# Lint the changed files with strict settings, --quiet omits status logs like 'Linting <file>' & 'Done linting'
$LINTER lint --strict --quiet $FILES_CHANGED
if [ $? -ne 0 ]; then
    fixes_help
fi

# Check if there would be formatting changes to the files, --lint make formatter fail on potential changes
$FORMATTER --lint --quiet $FILES_CHANGED
if [ $? -ne 0 ]; then
    fixes_help
fi

# Compilation can be slow even with a library this small, change RUN_COMPILE_CHECK to false to skip compilation
RUN_COMPILE_CHECK=${RUN_COMPILE_CHECK:-true}
if [ $RUN_COMPILE_CHECK = true ] ; then
    make all
    if [ $? -ne 0 ]; then
        fixes_help
    fi
fi

printf "\e[32mPassed Linting!\e[0m\n"
printf "\e[33mReminder: Have you tested?\e[0m\n"
