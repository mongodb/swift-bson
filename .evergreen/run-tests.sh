#!/bin/bash
set -o xtrace   # Write all commands first to stderr
set -o errexit  # Exit the script with error if any of the commands fail

# variables
PROJECT_DIRECTORY=${PROJECT_DIRECTORY:-"MISSING_PROJECT_DIRECTORY"}
SWIFT_VERSION=${SWIFT_VERSION:-"MISSING_SWIFT_VERSION"}
INSTALL_DIR="${PROJECT_DIRECTORY}/opt"

RAW_TEST_RESULTS="${PROJECT_DIRECTORY}/rawTestResults"
XML_TEST_RESULTS="${PROJECT_DIRECTORY}/testResults.xml"
SANITIZE=${SANITIZE:-"false"}

# configure Swift
. ${PROJECT_DIRECTORY}/.evergreen/configure-swift.sh

SANITIZE_STATEMENT=""
if [ "$SANITIZE" != "false" ]; then
    SANITIZE_STATEMENT="--sanitize ${SANITIZE}"
fi

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
