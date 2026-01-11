#!/bin/bash
# Integration test for purgecss_hugo_site rule

set -euo pipefail

echo "=== PurgeCSS Integration Test ==="

# Find the output directories from Bazel runfiles
RUNFILES_DIR="${TEST_SRCDIR:-$PWD}"
ORIGINAL_SITE="${RUNFILES_DIR}/_main/test_integration/purgecss/test_site"
PURGED_SITE="${RUNFILES_DIR}/_main/test_integration/purgecss/test_site_purged"

echo "Original site: $ORIGINAL_SITE"
echo "Purged site: $PURGED_SITE"

# Test 1: Both directories exist
echo ""
echo "Test 1: Verify both directories exist..."
if [ ! -d "$ORIGINAL_SITE" ]; then
    echo "FAIL: Original site directory does not exist: $ORIGINAL_SITE"
    exit 1
fi

if [ ! -d "$PURGED_SITE" ]; then
    echo "FAIL: Purged site directory does not exist: $PURGED_SITE"
    exit 1
fi
echo "✓ Both directories exist"

# Test 2: Verify CSS file exists in purged output
echo ""
echo "Test 2: Verify CSS file exists in purged output..."
if [ ! -f "$PURGED_SITE/test.css" ]; then
    echo "FAIL: Purged CSS file does not exist: $PURGED_SITE/test.css"
    exit 1
fi
echo "✓ Purged CSS file exists"

# Test 3: Verify CSS file is smaller after purging
echo ""
echo "Test 3: Verify CSS file is smaller after purging..."
if [ -f "$ORIGINAL_SITE/test.css" ] && [ -f "$PURGED_SITE/test.css" ]; then
    ORIG_SIZE=$(wc -c < "$ORIGINAL_SITE/test.css")
    PURGED_SIZE=$(wc -c < "$PURGED_SITE/test.css")

    echo "Original CSS: $ORIG_SIZE bytes"
    echo "Purged CSS: $PURGED_SIZE bytes"

    if [ "$PURGED_SIZE" -ge "$ORIG_SIZE" ]; then
        echo "FAIL: Purged CSS is not smaller than original"
        exit 1
    fi

    REDUCTION=$((100 - (PURGED_SIZE * 100 / ORIG_SIZE)))
    echo "✓ CSS reduced by ${REDUCTION}%"
else
    echo "WARN: Could not compare CSS file sizes"
fi

# Test 4: Verify used classes are preserved
echo ""
echo "Test 4: Verify used classes are preserved..."
if ! grep -q ".hero" "$PURGED_SITE/test.css"; then
    echo "FAIL: Used class .hero was removed"
    exit 1
fi

if ! grep -q ".title" "$PURGED_SITE/test.css"; then
    echo "FAIL: Used class .title was removed"
    exit 1
fi

if ! grep -q ".btn-primary" "$PURGED_SITE/test.css"; then
    echo "FAIL: Used class .btn-primary was removed"
    exit 1
fi
echo "✓ Used CSS classes preserved"

# Test 5: Verify unused classes are removed
echo ""
echo "Test 5: Verify unused classes are removed..."
if grep -q ".unused-class" "$PURGED_SITE/test.css"; then
    echo "FAIL: Unused class .unused-class was not removed"
    exit 1
fi

if grep -q ".another-unused" "$PURGED_SITE/test.css"; then
    echo "FAIL: Unused class .another-unused was not removed"
    exit 1
fi
echo "✓ Unused CSS classes removed"

# Test 6: Verify keyframes are preserved (since keyframes=True)
echo ""
echo "Test 6: Verify keyframes are preserved..."
if ! grep -q "@keyframes slideIn" "$PURGED_SITE/test.css"; then
    echo "FAIL: Keyframes were removed despite keyframes=True"
    exit 1
fi
echo "✓ Keyframes preserved as configured"

# Test 7: Verify HTML files are copied unchanged
echo ""
echo "Test 7: Verify HTML files are copied unchanged..."
if [ -f "$ORIGINAL_SITE/index.html" ] && [ -f "$PURGED_SITE/index.html" ]; then
    ORIG_HTML_SIZE=$(wc -c < "$ORIGINAL_SITE/index.html")
    PURGED_HTML_SIZE=$(wc -c < "$PURGED_SITE/index.html")

    if [ "$ORIG_HTML_SIZE" -ne "$PURGED_HTML_SIZE" ]; then
        echo "FAIL: HTML file size changed (should be unchanged)"
        exit 1
    fi
    echo "✓ HTML files copied unchanged"
else
    echo "WARN: Could not verify HTML file integrity"
fi

echo ""
echo "=== All PurgeCSS Tests Passed ==="
exit 0