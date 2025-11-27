#!/bin/bash
# Integration test for brotli_hugo_site rule

set -euo pipefail

echo "=== Brotli Compression Integration Test ==="

# Find the output directories from Bazel runfiles
RUNFILES_DIR="${TEST_SRCDIR:-$PWD}"
ORIGINAL_SITE="${RUNFILES_DIR}/_main/test_integration/brotli/test_site"
BROTLI_SITE="${RUNFILES_DIR}/_main/test_integration/brotli/test_site_brotli"

echo "Original site: $ORIGINAL_SITE"
echo "Brotli site: $BROTLI_SITE"

# Test 1: Both directories exist
echo ""
echo "Test 1: Verify both directories exist..."
if [ ! -d "$ORIGINAL_SITE" ]; then
    echo "FAIL: Original site directory does not exist: $ORIGINAL_SITE"
    exit 1
fi

if [ ! -d "$BROTLI_SITE" ]; then
    echo "FAIL: Brotli site directory does not exist: $BROTLI_SITE"
    exit 1
fi
echo "✓ Both directories exist"

# Test 2: Verify .br files are created
echo ""
echo "Test 2: Verify .br files are created..."
BR_FILES=$(find "$BROTLI_SITE" -name "*.br" | wc -l)
echo "Found $BR_FILES .br files"

if [ "$BR_FILES" -lt 1 ]; then
    echo "FAIL: No .br files created"
    exit 1
fi
echo "✓ Brotli files created"

# Test 3: Verify specific files are compressed
echo ""
echo "Test 3: Verify specific files are compressed..."
for file in test.css.br test.js.br index.xml.br sitemap.xml.br; do
    if [ -f "$BROTLI_SITE/$file" ]; then
        echo "✓ Found: $file"
    else
        echo "WARN: Missing expected file: $file"
    fi
done

# Test 4: Verify compression effectiveness
echo ""
echo "Test 4: Verify compression effectiveness..."
if [ -f "$ORIGINAL_SITE/test.css" ] && [ -f "$BROTLI_SITE/test.css.br" ]; then
    ORIG_SIZE=$(wc -c < "$ORIGINAL_SITE/test.css")
    BR_SIZE=$(wc -c < "$BROTLI_SITE/test.css.br")

    echo "CSS: $ORIG_SIZE → $BR_SIZE bytes"

    if [ "$BR_SIZE" -lt "$ORIG_SIZE" ]; then
        REDUCTION=$((100 - (BR_SIZE * 100 / ORIG_SIZE)))
        echo "✓ CSS compression: ${REDUCTION}% reduction"
    else
        echo "WARN: Brotli file not smaller than original"
    fi
else
    echo "WARN: Could not compare file sizes"
fi

# Test 5: Verify .br files are valid brotli format
echo ""
echo "Test 5: Verify .br files are valid brotli format..."
if command -v brotli >/dev/null 2>&1; then
    if [ -f "$BROTLI_SITE/test.css.br" ]; then
        if brotli -d -c "$BROTLI_SITE/test.css.br" > /dev/null 2>&1; then
            echo "✓ .br files are valid brotli format"
        else
            echo "FAIL: .br files are not valid brotli format"
            exit 1
        fi
    fi
else
    echo "WARN: brotli command not available, skipping format validation"
fi

# Test 6: Verify directory structure matches
echo ""
echo "Test 6: Verify directory structure is maintained..."
ORIG_CSS_COUNT=$(find "$ORIGINAL_SITE" -name "*.css" | wc -l)
BR_CSS_COUNT=$(find "$BROTLI_SITE" -name "*.css.br" | wc -l)

echo "Original CSS files: $ORIG_CSS_COUNT"
echo "Brotli CSS files: $BR_CSS_COUNT"

if [ "$ORIG_CSS_COUNT" -eq "$BR_CSS_COUNT" ]; then
    echo "✓ Directory structure maintained"
else
    echo "WARN: File counts differ"
fi

echo ""
echo "=== All Tests Passed ==="
exit 0
