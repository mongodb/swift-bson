# if provided, FILTER is used as the --filter argument to `swift test`.
ifdef FILTER
	FILTERARG = --filter $(FILTER)
else
	FILTERARG =
endif

# if no value provided assume sourcery is in the user's PATH
SOURCERY ?= sourcery

define check_for_gem
	gem list $(1) -i > /dev/null || gem install $(1) || { echo "ERROR: Failed to locate or install the ruby gem $(1); please install yourself with 'gem install $(1)' (you may need to use sudo)"; exit 1; }
endef

all:
	swift build

# project generates the .xcodeproj, and then modifies it to add
# spec .json files to the project
project:
	swift package generate-xcodeproj
	@$(call check_for_gem,xcodeproj)
	ruby etc/add_json_files.rb

test:
	swift test --enable-test-discovery -v $(FILTERARG)

test-pretty:
	@$(call check_for_gem,xcpretty)
	set -o pipefail && swift test --enable-test-discovery $(FILTERARG) 2>&1 | xcpretty

lint:
	@swiftformat .
	@swiftlint autocorrect
	@swiftlint lint --strict --quiet

# MacOS only
coverage:
	swift test --enable-code-coverage
	xcrun llvm-cov export -format="lcov" .build/debug/swift-bsonPackageTests.xctest/Contents/MacOS/swift-bsonPackageTests -instr-profile .build/debug/codecov/default.profdata > info.lcov

install_hook:
	@cp etc/pre-commit.sh .git/hooks/pre-commit
	@chmod +x .git/hooks/pre-commit

clean:
	rm -rf Packages
	rm -rf .build
	rm -rf swift-bson.xcodeproj
	rm Package.resolved
