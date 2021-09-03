#!/bin/bash
set -o xtrace   # Write all commands first to stderr
set -o errexit  # Exit the script with error if any of the commands fail

# variables
PROJECT_DIRECTORY=${PROJECT_DIRECTORY:-$PWD}
SWIFT_VERSION=${SWIFT_VERSION:-5.2.4}
INSTALL_DIR="${PROJECT_DIRECTORY}/opt"
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
RAW_TEST_RESULTS="${PROJECT_DIRECTORY}/rawTestResults"
XML_TEST_RESULTS="${PROJECT_DIRECTORY}/testResults.xml"
SANITIZE=${SANITIZE:-"false"}

# enable swiftenv
export SWIFTENV_ROOT="${INSTALL_DIR}/swiftenv"
export PATH="${SWIFTENV_ROOT}/bin:$PATH"
eval "$(swiftenv init -)"

# select the latest Xcode for Swift 5.1 support on MacOS
if [ "$OS" == "darwin" ]; then
    sudo xcode-select -s /Applications/Xcode11.3.app
fi

SANITIZE_STATEMENT=""
if [ "$SANITIZE" != "false" ]; then
    SANITIZE_STATEMENT="--sanitize ${SANITIZE}"
fi

# switch swift version, and run tests
swiftenv local $SWIFT_VERSION

# build the driver
swift build $SANITIZE_STATEMENT

# even if tests fail we want to parse the results, so disable errexit
set +o errexit
# propagate error codes in the following pipes
set -o pipefail

# test the driver
swift test --enable-test-discovery $SANITIZE_STATEMENT 2>&1 | tee ${RAW_TEST_RESULTS}

# save tests exit code
EXIT_CODE=$?

# convert tests to XML
cat ${RAW_TEST_RESULTS} | swift "${PROJECT_DIRECTORY}/etc/convert-test-results.swift" > ${XML_TEST_RESULTS}

# exit with exit code for running the tests
exit $EXIT_CODE
