#!/bin/bash
set -e

# Import the standard devcontainer test libraries for clean formatting
source dev-container-features-test-lib

# Test 1: Verify the symlink exists and maps to /usr/local/bin
check "executable-in-path" which sdk-server

# Test 2: Verify it can execute and report help details / version indicators
# (Adjust flags based on the exact CLI footprint of the sdk-server)
check "sdk-server-version" sdk-server --help

# Generate the test report summary
reportResults
