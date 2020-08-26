#!/bin/bash

# usage: ./etc/release.sh [new version string]

# exit if any command fails
set -e

# ensure we are on master before releasing
#git checkout master

version=${1}
# Ensure version is non-empty
[ ! -z "${version}" ] || { echo "ERROR: Missing version string"; exit 1; }

# regenerate documentation with new version string
./etc/generate-docs.sh ${version}

# tag release and push tag
git tag "v${version}"
git push --tags

# go to GitHub to publish release notes
open "https://github.com/mongodb/swift-bson/releases/tag/v${version}"
