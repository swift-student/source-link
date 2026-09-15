SHELL := /bin/bash

XCODEBUILD = xcodebuild \
	-workspace SourceLink.xcworkspace \
	-configuration Debug \
	-destination 'platform=macOS' \
	-derivedDataPath .build/xcode
TEST_SIGNING = CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual

.PHONY: build check format format-check generate lint release run test ui-test snapshot-test app-test

build: generate
	$(XCODEBUILD) -scheme SourceLink \
		CODE_SIGNING_ALLOWED=NO \
		build

check: test lint format-check build app-test

# Local universal app archive and cask. Public releases need Developer ID signing and notarization.
release: generate
	xcodebuild \
		-workspace SourceLink.xcworkspace \
		-scheme SourceLink \
		-configuration Release \
		-destination 'generic/platform=macOS' \
		-derivedDataPath .build/xcode \
		ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO \
		CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual \
		build
	bash scripts/prepare-homebrew.sh .build/xcode/Build/Products/Release/source-link.app .build/release

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
	swift test --package-path Packages/SourceLinkPackage

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
