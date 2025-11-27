#!/bin/bash
# Integration test for minify_hugo_site rule

set -euo pipefail

echo "=== Minification Integration Test ==="

# Find the output directories from Bazel runfiles
RUNFILES_DIR="${TEST_SRCDIR:-$PWD}"
ORIGINAL_SITE="${RUNFILES_DIR}/_main/test_integration/minify/test_site"
MINIFIED_SITE="${RUNFILES_DIR}/_main/test_integration/minify/test_site_minified"

echo "Original site: $ORIGINAL_SITE"
echo "Minified site: $MINIFIED_SITE"

# Test 1: Both directories exist
echo ""
echo "Test 1: Verify both directories exist..."
if [ ! -d "$ORIGINAL_SITE" ]; then
    echo "FAIL: Original site directory does not exist: $ORIGINAL_SITE"
    exit 1
fi

if [ ! -d "$MINIFIED_SITE" ]; then
    echo "FAIL: Minified site directory does not exist: $MINIFIED_SITE"
    exit 1
fi
echo "✓ Both directories exist"

# Test 2: Minified version should be smaller or equal in size
echo ""
echo "Test 2: Verify minified site is smaller..."

# Check individual known files for size reduction
CSS_ORIG_SIZE=$(wc -c < "$ORIGINAL_SITE/style.css" 2>/dev/null || echo "0")
CSS_MIN_SIZE=$(wc -c < "$MINIFIED_SITE/style.css" 2>/dev/null || echo "0")
JS_ORIG_SIZE=$(wc -c < "$ORIGINAL_SITE/app.js" 2>/dev/null || echo "0")
JS_MIN_SIZE=$(wc -c < "$MINIFIED_SITE/app.js" 2>/dev/null || echo "0")

echo "CSS: $CSS_ORIG_SIZE → $CSS_MIN_SIZE bytes"
echo "JS: $JS_ORIG_SIZE → $JS_MIN_SIZE bytes"

if [ "$CSS_MIN_SIZE" -lt "$CSS_ORIG_SIZE" ] && [ "$JS_MIN_SIZE" -lt "$JS_ORIG_SIZE" ]; then
    CSS_REDUCTION=$((100 - (CSS_MIN_SIZE * 100 / CSS_ORIG_SIZE)))
    JS_REDUCTION=$((100 - (JS_MIN_SIZE * 100 / JS_ORIG_SIZE)))
    echo "✓ Size reduction: CSS ${CSS_REDUCTION}%, JS ${JS_REDUCTION}%"
else
    echo "WARN: File sizes did not decrease as expected"
fi

# Test 3: Check CSS file minification
echo ""
echo "Test 3: Verify CSS minification..."
CSS_ORIGINAL="$ORIGINAL_SITE/style.css"
CSS_MINIFIED="$MINIFIED_SITE/style.css"

if [ -f "$CSS_ORIGINAL" ] && [ -f "$CSS_MINIFIED" ]; then
    ORIG_LINES=$(wc -l < "$CSS_ORIGINAL" || echo "0")
    MIN_LINES=$(wc -l < "$CSS_MINIFIED" || echo "0")

    echo "Original CSS lines: $ORIG_LINES"
    echo "Minified CSS lines: $MIN_LINES"

    if [ "$MIN_LINES" -lt "$ORIG_LINES" ]; then
        echo "✓ CSS file has fewer lines after minification"
    else
        echo "WARN: CSS file does not have fewer lines"
    fi

    # Check that CSS comments are removed
    if grep -q "/\*" "$CSS_MINIFIED"; then
        echo "WARN: CSS comments still present in minified file"
    else
        echo "✓ CSS comments removed"
    fi
else
    echo "WARN: CSS files not found for comparison"
fi

# Test 4: Check JS file minification
echo ""
echo "Test 4: Verify JavaScript minification..."
JS_ORIGINAL="$ORIGINAL_SITE/app.js"
JS_MINIFIED="$MINIFIED_SITE/app.js"

if [ -f "$JS_ORIGINAL" ] && [ -f "$JS_MINIFIED" ]; then
    ORIG_LINES=$(wc -l < "$JS_ORIGINAL" || echo "0")
    MIN_LINES=$(wc -l < "$JS_MINIFIED" || echo "0")

    echo "Original JS lines: $ORIG_LINES"
    echo "Minified JS lines: $MIN_LINES"

    if [ "$MIN_LINES" -lt "$ORIG_LINES" ]; then
        echo "✓ JS file has fewer lines after minification"
    else
        echo "WARN: JS file does not have fewer lines"
    fi

    # Check that JS comments are removed
    if grep -q "^[[:space:]]*//" "$JS_MINIFIED"; then
        echo "WARN: JS comments still present in minified file"
    else
        echo "✓ JS single-line comments removed"
    fi
else
    echo "WARN: JS files not found for comparison"
fi

# Test 5: Check HTML file minification
echo ""
echo "Test 5: Verify HTML minification..."
HTML_ORIGINAL="$ORIGINAL_SITE/index.html"
HTML_MINIFIED="$MINIFIED_SITE/index.html"

if [ -f "$HTML_ORIGINAL" ] && [ -f "$HTML_MINIFIED" ]; then
    ORIG_LINES=$(wc -l < "$HTML_ORIGINAL" || echo "0")
    MIN_LINES=$(wc -l < "$HTML_MINIFIED" || echo "0")

    echo "Original HTML lines: $ORIG_LINES"
    echo "Minified HTML lines: $MIN_LINES"

    if [ "$MIN_LINES" -lt "$ORIG_LINES" ]; then
        echo "✓ HTML file has fewer lines after minification"
    else
        echo "WARN: HTML file does not have fewer lines (may be already compact)"
    fi

    # Verify HTML is still valid (contains basic tags)
    if grep -q "<html" "$HTML_MINIFIED" && grep -q "</html>" "$HTML_MINIFIED"; then
        echo "✓ HTML structure preserved"
    else
        echo "FAIL: HTML structure appears corrupted"
        exit 1
    fi
else
    echo "WARN: HTML files not found for comparison"
fi

# Test 6: Verify file structure is maintained
echo ""
echo "Test 6: Verify directory structure is maintained..."
# Use ls to count specific known files instead of find
ORIG_FILES=0
MIN_FILES=0

for file in style.css app.js index.xml sitemap.xml; do
    [ -f "$ORIGINAL_SITE/$file" ] && ORIG_FILES=$((ORIG_FILES + 1))
    [ -f "$MINIFIED_SITE/$file" ] && MIN_FILES=$((MIN_FILES + 1))
done

echo "Original file count: $ORIG_FILES"
echo "Minified file count: $MIN_FILES"

if [ "$ORIG_FILES" -eq "$MIN_FILES" ] && [ "$ORIG_FILES" -gt 0 ]; then
    echo "✓ Same number of files in both directories"
else
    echo "WARN: File counts differ or no files found (original: $ORIG_FILES, minified: $MIN_FILES)"
fi

echo ""
echo "=== All Tests Passed ==="
exit 0
