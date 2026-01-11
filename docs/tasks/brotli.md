# Epic: Brotli Compression for Hugo Sites

## Overview

**Goal**: Provide automated Brotli compression for Hugo site outputs to reduce file sizes and improve page load performance.

**Value Proposition**:
- 15-25% better compression than gzip
- Supported by all modern browsers (Chrome, Firefox, Safari, Edge)
- Fast decompression
- Modern standard for web compression

**Success Metrics**:
- Rule successfully compresses all target file types
- Output maintains functional equivalence to source
- Integration test validates compression ratios
- Documentation with working example

**Target Effort**: 1 day (8 hours total)

---

## Story Breakdown

### Story 1: Core Brotli Rule (1 day)

**Objective**: Create `brotli_hugo_site` rule that processes Hugo site output and generates Brotli-compressed versions of specified file types.

**Deliverables**:
- `hugo/internal/hugo_site_brotli.bzl` implementation
- Export in `hugo/rules.bzl`
- Basic integration test

---

## Atomic Tasks

### Task 1.1: Create Basic Brotli Rule Structure (2h) - SMALL

**Scope**: Create `brotli_hugo_site` rule skeleton following `gzip_hugo_site` pattern with file discovery logic.

**Files** (3 files):
- `hugo/internal/hugo_site_brotli.bzl` (create) - New rule implementation
- `hugo/rules.bzl` (modify) - Add export for new rule
- `site_simple/BUILD.bazel` (modify) - Add example usage

**Context**:
- Study `hugo_site_gzip.bzl` as template (similar pattern)
- Understand HugoSiteInfo provider usage
- Review Bazel action creation patterns
- Understand directory tree artifact handling

**Implementation**:

```starlark
# hugo/internal/hugo_site_brotli.bzl
load("//hugo:internal/hugo_site_info.bzl", "HugoSiteInfo")

def _brotli_hugo_site_impl(ctx):
    """Creates brotli-compressed versions of files in a Hugo site."""
    site_info = ctx.attr.site[HugoSiteInfo]
    site_dir = site_info.output_dir

    # Output directory for compressed files
    output = ctx.actions.declare_directory(ctx.label.name)

    # Build file extensions pattern
    extensions = ctx.attr.extensions
    find_expr = " -o ".join(['-name "*.{}"'.format(ext) for ext in extensions])

    # Compression quality
    compression_quality = ctx.attr.compression_quality

    # Create the brotli script
    script_content = """#!/bin/bash
set -euo pipefail

SITE_DIR="{site_dir}"
OUTPUT_DIR="{output_dir}"

echo "Compressing files from $SITE_DIR to $OUTPUT_DIR with Brotli"

# Create output directory structure
mkdir -p "$OUTPUT_DIR"

# Find and compress matching files
cd "$SITE_DIR"
find . -type f \\( {find_expr} \\) | while read -r file; do
    # Create directory structure in output
    dirname="$(dirname "$file")"
    mkdir -p "$OUTPUT_DIR/$dirname"

    # Compress the file with brotli
    brotli -{compression_quality} -c "$file" > "$OUTPUT_DIR/$file.br"
    echo "Compressed: $file -> $file.br"
done

# Count results
TOTAL=$(find "$OUTPUT_DIR" -name "*.br" | wc -l)
echo "Created $TOTAL brotli-compressed files"
""".format(
        site_dir = site_dir.path,
        output_dir = output.path,
        find_expr = find_expr,
        compression_quality = compression_quality,
    )

    script = ctx.actions.declare_file(ctx.label.name + "_brotli.sh")
    ctx.actions.write(
        output = script,
        content = script_content,
        is_executable = True,
    )

    ctx.actions.run(
        inputs = [site_dir],
        outputs = [output],
        executable = script,
        mnemonic = "BrotliHugoSite",
        progress_message = "Compressing Hugo site files with Brotli",
    )

    return [
        DefaultInfo(files = depset([output])),
        OutputGroupInfo(
            brotli = depset([output]),
        ),
    ]

brotli_hugo_site = rule(
    doc = """
    Creates brotli-compressed versions of files from a Hugo site.

    This rule processes a hugo_site output and creates .br versions of files
    matching the specified extensions. This is useful for modern web serving
    with brotli_static or similar features.

    The output is a directory tree mirroring the site structure, containing
    only the .br files (e.g., styles.css becomes styles.css.br).

    Example:
        hugo_site(
            name = "site",
            config = "config.yaml",
            content = glob(["content/**"]),
        )

        brotli_hugo_site(
            name = "site_br",
            site = ":site",
            extensions = ["html", "css", "js", "xml", "json"],
            compression_quality = 11,
        )

        # Use with pkg_tar
        pkg_tar(
            name = "static_assets_br",
            srcs = [":site_br"],
            package_dir = "/usr/share/nginx/html",
        )
    """,
    implementation = _brotli_hugo_site_impl,
    attrs = {
        "site": attr.label(
            doc = "The hugo_site target to compress",
            providers = [HugoSiteInfo],
            mandatory = True,
        ),
        "extensions": attr.string_list(
            doc = "File extensions to compress (without the dot)",
            default = ["html", "css", "js", "xml", "json", "txt"],
        ),
        "compression_quality": attr.int(
            doc = "Brotli compression quality (0-11, where 11 is maximum compression)",
            default = 11,
        ),
    },
)
```

**Success Criteria**:
- Rule builds without errors
- Creates output directory with correct structure
- Accepts HugoSiteInfo provider input
- Returns DefaultInfo and OutputGroupInfo correctly
- Example in site_simple/BUILD.bazel builds successfully

**Testing**:
```bash
cd /home/tstapler/Programming/rules_hugo
bazel build //site_simple:site_simple_br
ls -la bazel-bin/site_simple/site_simple_br/
```

**Dependencies**: None (first task)

**Status**: Pending

---

### Task 1.2: Add BUILD File for Brotli Tool (1h) - MICRO

**Scope**: Create BUILD file in hugo/internal/ to export the brotli script (if needed).

**Files** (1 file):
- `hugo/internal/BUILD.bazel` (modify) - Add brotli tool if needed

**Context**:
- Brotli tool may need to be available in the build environment
- Check if brotli is available via package managers or needs to be built
- May need to add brotli as a dependency in MODULE.bazel

**Implementation**:

```python
# Add to MODULE.bazel if brotli needs to be installed
bazel_dep(name = "brotli", version = "...")  # If available
```

Or use system-installed brotli:

```bash
# Check if brotli is available
command -v brotli >/dev/null 2>&1 || {
    echo "brotli command not found. Install with: apt-get install brotli"
    exit 1
}
```

**Success Criteria**:
- Brotli tool is available during build
- Rule can execute brotli command
- Build completes without "command not found" errors

**Testing**:
```bash
bazel build //hugo/internal:brotli_test  # If created
```

**Dependencies**: Task 1.1 (requires rule to exist)

**Status**: Pending

---

### Task 1.3: Create Integration Test (2h) - SMALL

**Scope**: Create comprehensive integration test for brotli_hugo_site rule.

**Files** (3 files):
- `test_integration/brotli/BUILD.bazel` (create)
- `test_integration/brotli/test_brotli.sh` (create)
- `test_integration/brotli/config.yaml` (create)

**Context**:
- Follow existing test patterns in test_integration/
- Create simple Hugo site with sample HTML/CSS/JS
- Verify brotli compression produces smaller output
- Verify output is functionally valid

**Implementation**:

```yaml
# test_integration/brotli/config.yaml
baseURL: "https://example.com"
languageCode: "en-us"
title: "Brotli Test Site"
```

```python
# test_integration/brotli/BUILD.bazel
load("//hugo:rules.bzl", "hugo_site", "brotli_hugo_site")

hugo_site(
    name = "test_site",
    config = "config.yaml",
    content = glob(["content/**"]),
    static = glob(["static/**"]),
)

brotli_hugo_site(
    name = "test_site_br",
    site = ":test_site",
)

sh_test(
    name = "test_brotli",
    srcs = ["test_brotli.sh"],
    data = [
        ":test_site",
        ":test_site_br",
    ],
)
```

```bash
# test_integration/brotli/test_brotli.sh
#!/bin/bash
set -euo pipefail

# Get output directories
ORIGINAL="$1"
COMPRESSED="$2"

echo "Testing brotli compression..."

# Test 1: Compressed version exists
if [ ! -d "$COMPRESSED" ]; then
    echo "FAIL: Compressed directory does not exist"
    exit 1
fi

# Test 2: Compressed files should be smaller or equal
ORIGINAL_SIZE=$(du -sb "$ORIGINAL" | cut -f1)
COMPRESSED_SIZE=$(du -sb "$COMPRESSED" | cut -f1)

echo "Original size: $ORIGINAL_SIZE bytes"
echo "Compressed size: $COMPRESSED_SIZE bytes"

if [ "$COMPRESSED_SIZE" -gt "$ORIGINAL_SIZE" ]; then
    echo "FAIL: Compressed output is larger than original"
    exit 1
fi

# Test 3: Check file structure is maintained
ORIG_FILES=$(find "$ORIGINAL" -type f | wc -l)
COMP_FILES=$(find "$COMPRESSED" -name "*.br" | wc -l)

echo "Original files: $ORIG_FILES"
echo "Compressed files: $COMP_FILES"

if [ "$ORIG_FILES" -ne "$COMP_FILES" ]; then
    echo "WARN: File counts differ ($ORIG_FILES vs $COMP_FILES)"
fi

echo "PASS: All brotli tests passed"
exit 0
```

**Success Criteria**:
- Test builds and runs successfully
- Verifies compressed output is smaller
- Verifies output structure is maintained
- Verifies files are not corrupted

**Testing**:
```bash
bazel test //test_integration/brotli:test_brotli
```

**Dependencies**: Task 1.1, 1.2 (requires working rule and tool)

**Status**: Pending

---

### Task 1.4: Update Documentation (1h) - MICRO

**Scope**: Add comprehensive documentation for brotli_hugo_site rule.

**Files** (2 files):
- `docs/DOWNSTREAM_INTEGRATION.md` (modify) - Add brotli_hugo_site section
- `README.md` (modify) - Add brotli to features list

**Context**:
- Follow existing documentation patterns in DOWNSTREAM_INTEGRATION.md
- Provide clear usage examples
- Explain configuration options
- Highlight advantages over gzip

**Success Criteria**:
- Documentation is clear and accurate
- Examples are complete and buildable
- Benefits over gzip are clearly stated
- Follows existing documentation style

**Testing**: Manual review of documentation

**Dependencies**: Task 1.1 (requires rule to document)

**Status**: Pending

---

## Dependency Visualization

```
Story 1: Core Brotli Rule
├─ Task 1.1 (2h) Create Rule Structure
│   └─→ Task 1.2 (1h) Add BUILD File
│        └─→ Task 1.3 (2h) Integration Test
│             └─→ Task 1.4 (1h) Documentation
```

**Total Sequential Path**: 6 hours

## Context Preparation

Before starting Task 1.1, review:
1. `/home/tstapler/Programming/rules_hugo/hugo/internal/hugo_site_gzip.bzl` - Pattern to follow
2. `/home/tstapler/Programming/rules_hugo/hugo/internal/hugo_site_info.bzl` - Provider definition
3. `/home/tstapler/Programming/rules_hugo/hugo/rules.bzl` - Export pattern
4. Brotli compression documentation and quality levels

---

## Future Enhancements

After MVP is complete, consider:
1. **Brotli Static Support**: Add nginx brotli_static configuration examples
2. **Quality Optimization**: Research optimal quality levels for different file types
3. **Fallback Strategy**: Combine with gzip for maximum compatibility
4. **Performance Metrics**: Report compression ratios in build output

---

## Known Issues

None yet - this is a new feature.

---

## Progress Tracking

**Epic Progress**: 0/4 tasks completed (0%)

**Story 1 Progress**: 0/4 tasks completed (0%)

**Tasks**:
- Pending: Task 1.1, 1.2, 1.3, 1.4
- In Progress: None
- Completed: None

**Next Action**: Start with Task 1.1 - Create Basic Brotli Rule Structure</content>
<parameter name="filePath">docs/tasks/brotli.md