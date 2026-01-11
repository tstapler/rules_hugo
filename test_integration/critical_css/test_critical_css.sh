#!/bin/bash
# Integration test for critical_css_hugo_site rule

set -euo pipefail

echo "=== Critical CSS Integration Test ==="

# Find the output directories from Bazel runfiles
RUNFILES_DIR="${TEST_SRCDIR:-$PWD}"
ORIGINAL_SITE="${RUNFILES_DIR}/_main/test_integration/critical_css/test_site"
CRITICAL_SITE="${RUNFILES_DIR}/_main/test_integration/critical_css/test_site_critical"

echo "Original site: $ORIGINAL_SITE"
echo "Critical site: $CRITICAL_SITE"

# Test 1: Both directories exist
echo ""
echo "Test 1: Verify both directories exist..."
if [ ! -d "$ORIGINAL_SITE" ]; then
    echo "FAIL: Original site directory does not exist: $ORIGINAL_SITE"
    exit 1
fi

if [ ! -d "$CRITICAL_SITE" ]; then
    echo "FAIL: Critical site directory does not exist: $CRITICAL_SITE"
    exit 1
fi
echo "✓ Both directories exist"

# Test 2: Verify HTML file exists in critical output
echo ""
echo "Test 2: Verify HTML file exists in critical output..."
if [ ! -f "$CRITICAL_SITE/index.html" ]; then
    echo "FAIL: Critical HTML file does not exist: $CRITICAL_SITE/index.html"
    exit 1
fi
echo "✓ Critical HTML file exists"

# Test 3: Verify critical CSS is inlined
echo ""
echo "Test 3: Verify critical CSS is inlined..."
if ! grep -q "<style>" "$CRITICAL_SITE/index.html"; then
    echo "FAIL: No inline styles found in critical HTML"
    exit 1
fi

if ! grep -q "rel=\"preload\"" "$CRITICAL_SITE/index.html"; then
    echo "FAIL: No preload link found for remaining CSS"
    exit 1
fi
echo "✓ Critical CSS is inlined and remaining CSS is preloaded"

# Test 4: Verify noscript fallback exists
echo ""
echo "Test 4: Verify noscript fallback exists..."
if ! grep -q "<noscript>" "$CRITICAL_SITE/index.html"; then
    echo "FAIL: No noscript fallback found"
    exit 1
fi
echo "✓ Noscript fallback exists"

# Test 5: Verify CSS file still exists
echo ""
echo "Test 5: Verify CSS file still exists..."
if [ ! -f "$CRITICAL_SITE/css/styles.css" ]; then
    echo "FAIL: CSS file missing from critical output"
    exit 1
fi
echo "✓ CSS file preserved"

echo ""
echo "=== All Critical CSS Tests Passed ==="
exit 0