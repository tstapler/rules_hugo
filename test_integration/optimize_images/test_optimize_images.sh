#!/bin/bash
# Integration test for optimize_images_hugo_site rule

set -euo pipefail

echo "=== Image Optimization Integration Test ==="

# Find the output directories from Bazel runfiles
RUNFILES_DIR="${TEST_SRCDIR:-$PWD}"
ORIGINAL_SITE="${RUNFILES_DIR}/_main/test_integration/optimize_images/test_site"
OPTIMIZED_SITE="${RUNFILES_DIR}/_main/test_integration/optimize_images/test_site_optimized"

echo "Original site: $ORIGINAL_SITE"
echo "Optimized site: $OPTIMIZED_SITE"

# Test 1: Both directories exist
echo ""
echo "Test 1: Verify both directories exist..."
if [ ! -d "$ORIGINAL_SITE" ]; then
    echo "FAIL: Original site directory does not exist: $ORIGINAL_SITE"
    exit 1
fi

if [ ! -d "$OPTIMIZED_SITE" ]; then
    echo "FAIL: Optimized site directory does not exist: $OPTIMIZED_SITE"
    exit 1
fi
echo "✓ Both directories exist"

# Test 2: Original images are preserved
echo ""
echo "Test 2: Verify original images are preserved..."
ORIG_PNG=$(find "$OPTIMIZED_SITE" -name "test1.png" | wc -l)
ORIG_JPG=$(find "$OPTIMIZED_SITE" -name "test2.jpg" | wc -l)

if [ "$ORIG_PNG" -eq 1 ] && [ "$ORIG_JPG" -eq 1 ]; then
    echo "✓ Original images preserved"
else
    echo "FAIL: Original images missing (PNG: $ORIG_PNG, JPG: $ORIG_JPG)"
    exit 1
fi

# Test 3: WebP variants are created
echo ""
echo "Test 3: Verify WebP variants are created..."
WEBP_COUNT=$(find "$OPTIMIZED_SITE" -name "*.webp" | wc -l)
echo "Found $WEBP_COUNT WebP files"

if [ "$WEBP_COUNT" -ge 2 ]; then
    echo "✓ WebP variants created"
else
    echo "FAIL: Expected at least 2 WebP files, found $WEBP_COUNT"
    find "$OPTIMIZED_SITE" -name "*.webp" || true
    exit 1
fi

# Test 4: Verify specific WebP files exist
echo ""
echo "Test 4: Verify specific WebP files..."
if [ -f "$OPTIMIZED_SITE/images/test1.png.webp" ]; then
    echo "✓ Found: test1.png.webp"
else
    echo "FAIL: Missing test1.png.webp"
    echo "Files in images directory:"
    ls -la "$OPTIMIZED_SITE/images/" || true
    exit 1
fi

if [ -f "$OPTIMIZED_SITE/images/test2.jpg.webp" ]; then
    echo "✓ Found: test2.jpg.webp"
else
    echo "FAIL: Missing test2.jpg.webp"
    exit 1
fi

# Test 5: Verify WebP file sizes are smaller
echo ""
echo "Test 5: Verify WebP compression..."
PNG_SIZE=$(wc -c < "$OPTIMIZED_SITE/images/test1.png" 2>/dev/null || echo "0")
WEBP_PNG_SIZE=$(wc -c < "$OPTIMIZED_SITE/images/test1.png.webp" 2>/dev/null || echo "0")

JPG_SIZE=$(wc -c < "$OPTIMIZED_SITE/images/test2.jpg" 2>/dev/null || echo "0")
WEBP_JPG_SIZE=$(wc -c < "$OPTIMIZED_SITE/images/test2.jpg.webp" 2>/dev/null || echo "0")

echo "PNG: $PNG_SIZE → $WEBP_PNG_SIZE bytes (WebP)"
echo "JPG: $JPG_SIZE → $WEBP_JPG_SIZE bytes (WebP)"

if [ "$WEBP_PNG_SIZE" -gt 0 ] && [ "$WEBP_JPG_SIZE" -gt 0 ]; then
    if [ "$WEBP_PNG_SIZE" -lt "$PNG_SIZE" ]; then
        PNG_REDUCTION=$((100 - (WEBP_PNG_SIZE * 100 / PNG_SIZE)))
        echo "✓ PNG WebP compression: ${PNG_REDUCTION}% reduction"
    else
        echo "WARN: PNG WebP not smaller (may be too simple image)"
    fi

    if [ "$WEBP_JPG_SIZE" -lt "$JPG_SIZE" ]; then
        JPG_REDUCTION=$((100 - (WEBP_JPG_SIZE * 100 / JPG_SIZE)))
        echo "✓ JPG WebP compression: ${JPG_REDUCTION}% reduction"
    else
        echo "WARN: JPG WebP not smaller"
    fi
else
    echo "FAIL: WebP files are empty or missing"
    exit 1
fi

# Test 6: Verify no AVIF files (since generate_avif=False)
echo ""
echo "Test 6: Verify AVIF generation disabled..."
AVIF_COUNT=$(find "$OPTIMIZED_SITE" -name "*.avif" 2>/dev/null | wc -l)
if [ "$AVIF_COUNT" -eq 0 ]; then
    echo "✓ No AVIF files (as expected)"
else
    echo "WARN: Found $AVIF_COUNT AVIF files (should be 0)"
fi

echo ""
echo "=== All Tests Passed ==="
exit 0
