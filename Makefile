SHELL := /bin/bash

.PHONY: build check format format-check generate lint run test ui-test snapshot-test

build: generate
	xcodebuild \
		-workspace SourceLink.xcworkspace \
		-scheme SourceLink \
		-configuration Debug \
		-destination 'platform=macOS' \
		-derivedDataPath .build/xcode \
		CODE_SIGNING_ALLOWED=NO \
		build

check: test lint format-check build

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
	xcodebuild \
		-workspace SourceLink.xcworkspace \
		-scheme SettingsSnapshots \
		-configuration Debug \
		-destination 'platform=macOS' \
		-derivedDataPath .build/xcode \
		CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual \
		test

ui-test: generate
	xcodebuild \
		-workspace SourceLink.xcworkspace \
		-scheme SourceLink \
		-configuration Debug \
		-destination 'platform=macOS' \
		-derivedDataPath .build/xcode \
		CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual \
		test

# Explicit opt-in: review baseline changes before committing.
.PHONY: record-snapshots
record-snapshots:
	TEST_RUNNER_RECORD_SNAPSHOTS=1 $(MAKE) snapshot-test
