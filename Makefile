SHELL := /bin/bash

.PHONY: build check generate lint run test ui-test

build: generate
	xcodebuild \
		-workspace XedLink.xcworkspace \
		-scheme XedLink \
		-configuration Debug \
		-destination 'platform=macOS' \
		-derivedDataPath .build/xcode \
		CODE_SIGNING_ALLOWED=NO \
		build

check: test lint build

generate:
	cd app && xcodegen generate

lint:
	swiftlint lint --strict --config .swiftlint.yml

run: build
	open .build/xcode/Build/Products/Debug/source-link.app

test:
	swift test


ui-test: generate
	xcodebuild \
		-workspace XedLink.xcworkspace \
		-scheme XedLink \
		-configuration Debug \
		-destination 'platform=macOS' \
		-derivedDataPath .build/xcode \
		CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual \
		SOURCE_LINK_RECORD_SNAPSHOTS=$(SOURCE_LINK_RECORD_SNAPSHOTS) \
		$(RESULT_BUNDLE_ARGS) test

# Explicit opt-in: review baseline changes before committing.
.PHONY: record-snapshots
record-snapshots:
	python3 scripts/record-snapshots.py
