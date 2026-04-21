# Makefile for navidrome-sync
# Provides targets for running iOS unit tests headlessly in CI.
#
# Prerequisites:
#   - macOS with Xcode 16+ installed
#   - iOS 18.2 Simulator runtime present (xcrun simctl list runtimes)
#
# Usage:
#   make test-ios              # Run all unit tests (no live server)
#   make test-ios-live         # Run all tests including live smoke tests
#   make test-ios-coverage     # Run with code coverage, export report
#   make test-go               # Run Go backend unit tests

# ── Configuration ──────────────────────────────────────────────────────────────

SCHEME          := navidrome-ios
XCODE_PROJECT   := /Users/tdarco/Documents/Projects/navidrome/navidrome-ios/navidrome-ios.xcodeproj
DESTINATION     := platform=iOS Simulator,OS=18.2,name=iPhone 16
RESULT_BUNDLE   := $(CURDIR)/build/test.xcresult
COVERAGE_DIR    := $(CURDIR)/build/coverage

# Live server test environment (override on command line or in CI)
NAVIDROME_TEST_URL    ?=
NAVIDROME_SERVER_URL  ?=
NAVIDROME_TEST_USER   ?=
NAVIDROME_TEST_PASS   ?=

# ── iOS Tests ──────────────────────────────────────────────────────────────────

.PHONY: test-ios
## Run all iOS unit tests (skips live server smoke tests).
test-ios:
	@echo "==> Running iOS unit tests (scheme: $(SCHEME), iOS 18.2 / iPhone 16)"
	set -o pipefail && xcodebuild test \
		-project "$(XCODE_PROJECT)" \
		-scheme "$(SCHEME)" \
		-destination "$(DESTINATION)" \
		-only-testing:navidrome-iosTests \
		-resultBundlePath "$(RESULT_BUNDLE)" \
		| xcpretty || (echo "Tests FAILED"; exit 1)
	@echo "==> Tests PASSED"

.PHONY: test-ios-live
## Run all iOS tests including live server smoke tests.
## Requires NAVIDROME_TEST_URL to be set (e.g. http://localhost:8080).
test-ios-live:
	@if [ -z "$(NAVIDROME_TEST_URL)" ]; then \
		echo "ERROR: NAVIDROME_TEST_URL is not set. Start the server with ./dev.sh first."; \
		exit 1; \
	fi
	@echo "==> Running iOS tests (including live smoke tests against $(NAVIDROME_TEST_URL))"
	set -o pipefail && NAVIDROME_TEST_URL="$(NAVIDROME_TEST_URL)" \
		NAVIDROME_SERVER_URL="$(NAVIDROME_SERVER_URL)" \
		NAVIDROME_TEST_USER="$(NAVIDROME_TEST_USER)" \
		NAVIDROME_TEST_PASS="$(NAVIDROME_TEST_PASS)" \
		xcodebuild test \
		-project "$(XCODE_PROJECT)" \
		-scheme "$(SCHEME)" \
		-destination "$(DESTINATION)" \
		-only-testing:navidrome-iosTests \
		-resultBundlePath "$(RESULT_BUNDLE)" \
		-testenv NAVIDROME_TEST_URL="$(NAVIDROME_TEST_URL)" \
		-testenv NAVIDROME_SERVER_URL="$(NAVIDROME_SERVER_URL)" \
		-testenv NAVIDROME_TEST_USER="$(NAVIDROME_TEST_USER)" \
		-testenv NAVIDROME_TEST_PASS="$(NAVIDROME_TEST_PASS)" \
		| xcpretty || (echo "Tests FAILED"; exit 1)
	@echo "==> Live tests PASSED"

.PHONY: test-ios-coverage
## Run tests with code coverage and export an lcov report.
## Coverage report is written to build/coverage/
test-ios-coverage:
	@echo "==> Running iOS tests with coverage"
	@mkdir -p "$(COVERAGE_DIR)"
	set -o pipefail && xcodebuild test \
		-project "$(XCODE_PROJECT)" \
		-scheme "$(SCHEME)" \
		-destination "$(DESTINATION)" \
		-only-testing:navidrome-iosTests \
		-resultBundlePath "$(RESULT_BUNDLE)" \
		-enableCodeCoverage YES \
		| xcpretty || (echo "Tests FAILED"; exit 1)
	@echo "==> Exporting coverage report"
	xcrun xccov view --report --json "$(RESULT_BUNDLE)" > "$(COVERAGE_DIR)/coverage.json"
	@echo "==> Coverage report: $(COVERAGE_DIR)/coverage.json"
	@$(MAKE) _coverage-check

.PHONY: _coverage-check
## Internal: warn if coverage of tested files falls below threshold.
_coverage-check:
	@python3 -c "\
import json, sys; \
data = json.load(open('$(COVERAGE_DIR)/coverage.json')); \
targets = [t for t in data.get('targets', []) if 'navidrome-ios' in t.get('name','') and 'Tests' not in t.get('name','')]; \
if not targets: sys.exit(0); \
cov = targets[0].get('lineCoverage', 0) * 100; \
print(f'Coverage: {cov:.1f}%'); \
sys.exit(0) if cov >= 60 else print(f'WARNING: Coverage {cov:.1f}% is below 60% threshold') \
"

# ── Go Tests ───────────────────────────────────────────────────────────────────

.PHONY: test-go
## Run Go backend unit tests.
test-go:
	@echo "==> Running Go tests"
	go test ./... -timeout 30s -race
	@echo "==> Go tests PASSED"

# ── Utilities ──────────────────────────────────────────────────────────────────

.PHONY: clean
## Remove build artifacts.
clean:
	rm -rf "$(CURDIR)/build"

.PHONY: check-simulator
## Verify the required iOS 18.2 simulator is available.
check-simulator:
	@xcrun simctl list runtimes | grep -q "iOS 18.2" \
		|| (echo "ERROR: iOS 18.2 simulator runtime not found. Install via Xcode → Platforms." && exit 1)
	@echo "iOS 18.2 runtime found"

.PHONY: help
## Show this help.
help:
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/## //' | \
	awk 'prev && /^[a-z]/ { printf "  %-24s %s\n", $$0, prev } /^## / { prev=$$0; next } { prev="" }' \
	|| true
	@echo ""
	@echo "Targets:"
	@grep -E '^\.PHONY: ' $(MAKEFILE_LIST) | sed 's/\.PHONY: /  /' | grep -v '^  _'
