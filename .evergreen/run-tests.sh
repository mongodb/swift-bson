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

# work around https://github.com/mattgallagher/CwlPreconditionTesting/issues/22 (bug still exists in version 1.x
# when using Xcode 13.2)
if [ "$OS" == "darwin" ]; then
    EXTRA_FLAGS="-Xswiftc -Xfrontend -Xswiftc -validate-tbd-against-ir=none"
fi

# build the driver
swift build $EXTRA_FLAGS $SANITIZE_STATEMENT

# even if tests fail we want to parse the results, so disable errexit
set +o errexit
# propagate error codes in the following pipes
set -o pipefail

# test the driver
swift test --enable-test-discovery $EXTRA_FLAGS $SANITIZE_STATEMENT 2>&1 | tee ${RAW_TEST_RESULTS}

# save tests exit code
EXIT_CODE=$?

# convert tests to XML
cat ${RAW_TEST_RESULTS} | swift "${PROJECT_DIRECTORY}/etc/convert-test-results.swift" > ${XML_TEST_RESULTS}

# exit with exit code for running the tests
exit $EXIT_CODE
