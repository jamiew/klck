# Klck — metronome + tuner for macOS
# Requires: Swift 6+ toolchain (Xcode or Command Line Tools). No full Xcode needed.
#
# Every target is quiet by default: errors, warnings, failures and one result
# line. Exit codes are real, so `make check && ...` is safe in scripts.

# Apple's make is 3.81, which ignores .SHELLFLAGS, so recipes that pipe set
# pipefail themselves.
SHELL := /bin/bash

# MAKEFLAGS may carry -j from the shell. `check` must build before it tests,
# and two SwiftPM processes on one .build just wait on each other's lock.
.NOTPARALLEL:

APP      := Klck.app
CONFIG   ?= release
SNAPSHOT ?= build/snapshot.png
SIZE     ?= 620x880

.DEFAULT_GOAL := build

.PHONY: help build app run run-console stop logs snapshot test check release clean rebuild version ios-project

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

build: ## Build and assemble Klck.app (CONFIG=release|debug)
	@./build_app.sh $(CONFIG)

app: build

test: ## Run the test suite; prints failures and a one-line summary
	@swift build --build-tests --quiet
	@set -o pipefail; swift test --skip-build 2>&1 \
		| awk '/error:/ { print } /Executed [0-9]+ tests/ { summary = $$0 } END { sub(/^[ \t]+/, "", summary); print summary }'

check: build test ## Build the app and run tests (the pre-commit gate)

snapshot: build ## Render the main window to $(SNAPSHOT) without opening a window
	@mkdir -p $(dir $(SNAPSHOT))
	@./$(APP)/Contents/MacOS/Klck --snapshot $(SNAPSHOT) --size $(SIZE)

run: build stop ## Build, quit any running copy, and launch the app (opens a window)
	@open $(APP)

run-console: build stop ## Like run, but in the foreground with log output here
	./$(APP)/Contents/MacOS/Klck

stop: ## Quit a running Klck
	@pkill -x Klck 2>/dev/null && sleep 0.5 || true

logs: ## Stream the running app's logs (Ctrl-C to stop)
	@log stream --style compact --predicate 'process == "Klck"'

release: clean build ## Clean, then produce a fresh Klck.app

rebuild: clean build

ios-project: ## Generate Klck.xcodeproj for the iOS app (needs Xcode + xcodegen)
	@command -v xcodegen >/dev/null || { echo "xcodegen not found — run: brew install xcodegen"; exit 1; }
	xcodegen generate
	@echo "Generated Klck.xcodeproj — open it in Xcode to build/run on iOS."

version: ## Print the Swift toolchain version
	@swift --version

clean: ## Remove build artifacts and the app bundle
	@swift package clean
	@rm -rf .build build $(APP)
