#!/bin/bash

# usage: ./etc/release.sh [new version string]

# exit if any command fails
set -e

# ensure we are on master before releasing
git checkout master

# regenerate documentation with new version string
./etc/generate-docs.sh ${1}

# tag release and push tag
git tag "v${1}"
git push --tags

# go to GitHub to publish release notes
open "https://github.com/mongodb/swift-bson/releases/tag/v${1}"
