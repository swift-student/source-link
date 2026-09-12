SHELL := /bin/bash

XCODEBUILD = xcodebuild \
	-workspace SourceLink.xcworkspace \
	-configuration Debug \
	-destination 'platform=macOS' \
	-derivedDataPath .build/xcode
TEST_SIGNING = CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual

.PHONY: build check format format-check generate lint run test ui-test snapshot-test app-test

build: generate
	$(XCODEBUILD) -scheme SourceLink \
		CODE_SIGNING_ALLOWED=NO \
		build

check: test lint format-check build app-test

generate:
	cd app && xcodegen generate

format:
	swiftformat .
	swiftlint lint --fix --config .swiftlint.yml
	swiftformat .

format-check:
	swiftformat . --lint

lint:
	swiftlint lint --strict --config .swiftlint.yml

run: build
	open .build/xcode/Build/Products/Debug/source-link.app

test:
	swift test

snapshot-test: generate
	$(XCODEBUILD) -scheme SettingsSnapshots \
		$(TEST_SIGNING) \
		test

ui-test: generate
	$(XCODEBUILD) -scheme SourceLink \
		$(TEST_SIGNING) \
		test

# Explicit opt-in: review baseline changes before committing.
.PHONY: record-snapshots
record-snapshots:
	TEST_RUNNER_RECORD_SNAPSHOTS=1 $(MAKE) snapshot-test

app-test: generate
	$(XCODEBUILD) -scheme SourceLinkAppTests \
		$(TEST_SIGNING) \
		test
