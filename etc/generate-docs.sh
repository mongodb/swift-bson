#!/bin/bash

# usage: ./etc/generate-docs.sh [new version string]

# exit if any command fails
set -e

if ! command -v jazzy > /dev/null; then
  gem install jazzy || { echo "ERROR: Failed to locate or install jazzy; please install yourself with 'gem install jazzy' (you may need to use sudo)"; exit 1; }
fi

if ! command -v sourcekitten > /dev/null; then
  echo "ERROR: Failed to locate SourceKitten; please install yourself and/or add to your \$PATH"; exit 1
fi

version=${1}

# Ensure version is non-empty
[ ! -z "${version}" ] || { echo "ERROR: Missing version string"; exit 1; }

jazzy_args=(--clean
            --github-file-prefix https://github.com/mongodb/swift-bson/tree/v${version} 
            --module-version "${version}")

sourcekitten doc --spm --module-name SwiftBSON > swift-bson-docs.json
args=("${jazzy_args[@]}"  --output "docs-temp/SwiftBSON" --module "SwiftBSON" --config ".jazzy.yml" 
        --sourcekitten-sourcefile swift-bson-docs.json
        --root-url "https://mongodb.github.io/swift-bson/docs/SwiftBSON/")
jazzy "${args[@]}"

echo '<html><head><meta http-equiv="refresh" content="0; url=SwiftBSON/index.html" /></head></html>' > docs-temp/index.html

rm swift-bson-docs.json
