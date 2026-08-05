SIMULATOR ?= iPhone 17
PLATFORM_IOS = iOS Simulator,id=$(call udid_for,$(SIMULATOR))

default: test

test: test-package test-examples

test-package:
	xcodebuild test \
		-workspace FrameLayout.xcworkspace \
		-scheme FrameLayout \
		-destination platform="$(PLATFORM_IOS)"

test-examples:
	xcodebuild test \
		-workspace FrameLayout.xcworkspace \
		-scheme CellSystem \
		-destination platform="$(PLATFORM_IOS)"

build-package:
	xcodebuild build \
		-scheme FrameLayout \
		-destination "generic/platform=iOS Simulator"

.PHONY: default test test-package test-examples build-package

define udid_for
$(shell xcrun simctl list --json devices available | jq -r '[.devices[][] | select(.name == "$(1)")] | last.udid')
endef
