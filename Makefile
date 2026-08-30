SIMULATOR ?= iPhone 17
# The declared minimum. Conformances the compiler accepts can be missing at runtime there, so a suite
# green on the latest simulator says nothing about the floor.
MINIMUM_SIMULATOR ?= iPhone 15
PLATFORM_IOS = iOS Simulator,id=$(call udid_for,$(SIMULATOR))
PLATFORM_IOS_MINIMUM = iOS Simulator,id=$(call udid_for,$(MINIMUM_SIMULATOR))

default: test

test: test-package test-examples test-minimum

test-package:
	xcodebuild test \
		-workspace FrameLayout.xcworkspace \
		-scheme FrameLayout \
		-destination platform="$(PLATFORM_IOS)"

test-examples:
	xcodebuild test \
		-workspace FrameLayout.xcworkspace \
		-scheme Playgrounds \
		-destination platform="$(PLATFORM_IOS)"

test-minimum:
	xcodebuild test \
		-workspace FrameLayout.xcworkspace \
		-scheme FrameLayout \
		-destination platform="$(PLATFORM_IOS_MINIMUM)"

build-package:
	xcodebuild build \
		-scheme FrameLayout \
		-destination "generic/platform=iOS Simulator"

.PHONY: default test test-package test-examples test-minimum build-package

define udid_for
$(shell xcrun simctl list --json devices available | jq -r '[.devices[][] | select(.name == "$(1)")] | last.udid')
endef
