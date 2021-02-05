#!/bin/bash

# usage: ./etc/release.sh [new version string]

# exit if any command fails
set -e

# ensure we are on main before releasing
git checkout main

version=${1}
# Ensure version is non-empty
[ ! -z "${version}" ] || { echo "ERROR: Missing version string"; exit 1; }

# regenerate documentation with new version string
./etc/generate-docs.sh ${version}

# switch to docs branch to commit and push
git checkout gh-pages

rm -r docs/current
cp -r docs-temp docs/current
mv docs-temp docs/${version}

# build up documentation index
python3 ./_scripts/update-index.py

git add docs/
git commit -m "${version} docs"
git push

# go back to wherever we started
git checkout -

# tag release and push tag
git tag "v${version}"
git push --tags

# go to GitHub to publish release notes
open "https://github.com/mongodb/swift-bson/releases/tag/v${version}"
