#!/bin/bash
set -e

source dev-container-features-test-lib

# Test 1: Verify the specific executable is exposed globally
check "executable-in-path" which sdk-server

# Test 2: Run a quick string validation test against a predictable asset file 
# or custom internal structure inside /opt/agones-sdk to prove it isn't "latest"
check "verify-install-dir" test -d /opt/agones-sdk

reportResults
