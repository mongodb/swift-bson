#!/bin/bash

# usage: ./etc/generate-docs.sh [new version string]

# exit if any command fails
set -e

if ! command -v jazzy > /dev/null; then
  gem install jazzy || { echo "ERROR: Failed to locate or install jazzy; please install yourself with 'gem install jazzy' (you may need to use sudo)"; exit 1; }
fi

version=${1}

# Ensure version is non-empty
[ ! -z "${version}" ] || { echo "ERROR: Missing version string"; exit 1; }

jazzy \
--github-file-prefix https://github.com/mongodb/swift-bson/tree/v${version} \
--module-version "${version}" \
--output "docs-temp/SwiftBSON" \
--config .jazzy.yml

# switch to docs branch to commit and push
git stash
git checkout gh-pages

rm -rf docs/*
cp -r docs-temp/* docs/
rm -rf docs-temp

git add docs/

echo '<html><head><meta http-equiv="refresh" content="0; url=BSON/index.html" /></head></html>' > docs/index.html
git add docs/index.html

git commit -m "${version} docs"
git push

# go back to wherever we started
git checkout -
