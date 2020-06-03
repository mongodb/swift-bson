#! /usr/bin/env bash

function fixes_help {
    printf '\n\e[35myou got hooked!\e[0m\n'
    echo 'Make sure Lint/Format/Build pass:'
    echo '  make lint all'
    exit 1
}

FILES_CHANGED=$(git diff --diff-filter=ACMRT --stat --cached --name-only '*.swift')
LINTER=$(which swiftlint)
FORMATTER=$(which swiftformat)

$LINTER lint --strict --quiet $FILES_CHANGED
if [ $? -ne 0 ]; then
    fixes_help
fi

$FORMATTER --lint --quiet $FILES_CHANGED
if [ $? -ne 0 ]; then
    fixes_help
fi

make all
if [ $? -ne 0 ]; then
    fixes_help
fi

printf "\e[33mReminder: Have you tested?\e[0m\n"
printf "\e[32mPassed Linting.\e[0m\n"
