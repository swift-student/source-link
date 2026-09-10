SHELL := /bin/bash

.PHONY: build check generate lint run test

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

