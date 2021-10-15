#!/bin/sh
set -o xtrace   # Write all commands first to stderr
set -o errexit  # Exit the script with error if any of the commands fail

# variables
PROJECT_DIRECTORY=${PROJECT_DIRECTORY:-"MISSING_PROJECT_DIRECTORY"}
SWIFT_VERSION=${SWIFT_VERSION:-"MISSING_SWIFT_VERSION"}
INSTALL_DIR="${PROJECT_DIRECTORY}/opt"

export SWIFTENV_ROOT="${INSTALL_DIR}/swiftenv"
export PATH="${SWIFTENV_ROOT}/bin:$PATH"

# install swiftenv
git clone --depth 1 -b "osx-install-path" https://github.com/kmahar/swiftenv.git "${SWIFTENV_ROOT}"

# install swift
eval "$(swiftenv init -)"
swiftenv install --install-local $SWIFT_VERSION
