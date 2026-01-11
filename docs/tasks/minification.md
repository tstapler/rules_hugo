# Epic: Asset Minification for Hugo Sites

## Overview

**Goal**: Provide automated HTML/CSS/JS/XML/JSON minification for Hugo site outputs to reduce file sizes and improve page load performance.

**Value Proposition**:
- 40-60% size reduction for CSS/JS files
- 10-30% reduction for HTML files
- Simple integration following existing gzip_hugo_site pattern
- Universal need for production deployments

**Success Metrics**:
- Rule successfully minifies all target file types
- Output maintains functional equivalence to source
- Integration test validates size reduction
- Documentation with working example

**Target Effort**: 1.5-2 days (12-16 hours total)

---

## Story Breakdown

### Story 1: Core Minification Rule (1-1.5 days)

**Objective**: Create `minify_hugo_site` rule that processes Hugo site output and generates minified versions of specified file types.

**Deliverables**:
- `hugo/internal/hugo_site_minify.bzl` implementation
- Export in `hugo/rules.bzl`
- Basic integration test

---

## Atomic Tasks

### Task 1.1: Create Basic Minification Rule Structure (2h) - SMALL

**Scope**: Create `minify_hugo_site` rule skeleton following `gzip_hugo_site` pattern with file discovery logic.

**Files** (3 files):
- `hugo/internal/hugo_site_minify.bzl` (create) - New rule implementation
- `hugo/rules.bzl` (modify) - Add export for new rule
- `site_simple/BUILD.bazel` (modify) - Add example usage

**Context**:
- Study `hugo_site_gzip.bzl` as template (similar pattern)
- Understand HugoSiteInfo provider usage
- Review Bazel action creation patterns
- Understand directory tree artifact handling

**Implementation**:

```starlark
# hugo/internal/hugo_site_minify.bzl
load("//hugo:internal/hugo_site_info.bzl", "HugoSiteInfo")

def _minify_hugo_site_impl(ctx):
    """Minifies compressible text files in a Hugo site."""
    site_info = ctx.attr.site[HugoSiteInfo]
    site_dir = site_info.output_dir

    # Output directory for minified files
    output = ctx.actions.declare_directory(ctx.label.name)

    # Build file extensions pattern for find command
    extensions = ctx.attr.extensions
    find_expr = " -o ".join(['-name "*.{}"'.format(ext) for ext in extensions])

    # Create minification script (placeholder - will add tool integration in Task 1.2)
    script_content = """#!/bin/bash
set -euo pipefail

SITE_DIR="{site_dir}"
OUTPUT_DIR="{output_dir}"

echo "Minifying files from $SITE_DIR to $OUTPUT_DIR"

# Create output directory structure mirroring input
mkdir -p "$OUTPUT_DIR"

# Copy entire directory structure first
cp -r "$SITE_DIR/." "$OUTPUT_DIR/"

# Find matching files (minification logic in next task)
cd "$SITE_DIR"
find . -type f \\( {find_expr} \\) | while read -r file; do
    echo "Would minify: $file"
done

echo "Minification complete"
""".format(
        site_dir = site_dir.path,
        output_dir = output.path,
        find_expr = find_expr,
    )

    script = ctx.actions.declare_file(ctx.label.name + "_minify.sh")
    ctx.actions.write(
        output = script,
        content = script_content,
        is_executable = True,
    )

    ctx.actions.run(
        inputs = [site_dir],
        outputs = [output],
        executable = script,
        mnemonic = "MinifyHugoSite",
        progress_message = "Minifying Hugo site files",
    )

    return [
        DefaultInfo(files = depset([output])),
        OutputGroupInfo(
            minified = depset([output]),
        ),
    ]

minify_hugo_site = rule(
    doc = """
    Minifies text files from a Hugo site to reduce file sizes.

    This rule processes a hugo_site output and creates minified versions
    of HTML, CSS, JS, XML, and JSON files. The output is a complete
    directory tree with minified files replacing the originals.

    Example:
        hugo_site(
            name = "site",
            config = "config.yaml",
            content = glob(["content/**"]),
        )

        minify_hugo_site(
            name = "site_minified",
            site = ":site",
        )
    """,
    implementation = _minify_hugo_site_impl,
    attrs = {
        "site": attr.label(
            doc = "The hugo_site target to minify",
            providers = [HugoSiteInfo],
            mandatory = True,
        ),
        "extensions": attr.string_list(
            doc = "File extensions to minify (without the dot)",
            default = ["html", "css", "js", "xml", "json"],
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
bazel build //site_simple:site_minified
ls -la bazel-bin/site_simple/site_minified/
```

**Dependencies**: None (first task)

**Status**: Pending

---

### Task 1.2: Integrate Minification Tools (3h) - MEDIUM

**Scope**: Add actual minification logic using available command-line tools (html-minifier, terser for JS, csso for CSS, or alternatives).

**Files** (2 files):
- `hugo/internal/hugo_site_minify.bzl` (modify) - Add tool execution
- `hugo/internal/hugo_site_minify.sh` (create) - External script for complex logic

**Context**:
- Research available minification tools that work from command line
- Options:
  - `terser` for JS (requires Node.js)
  - `html-minifier` for HTML (requires Node.js)
  - `csso-cli` for CSS (requires Node.js)
  - Python alternatives: `htmlmin`, `csscompressor`
  - Or use simple sed/awk for basic minification
- Decision: Start with simple approach (remove comments, whitespace) using shell tools for hermetic build
- Can add npm-based tools later via rules_js if needed

**Implementation Strategy**:

Create external shell script for minification logic to keep bzl file clean:

```bash
# hugo/internal/hugo_site_minify.sh
#!/bin/bash
set -euo pipefail

SITE_DIR="$1"
OUTPUT_DIR="$2"
shift 2
EXTENSIONS=("$@")

echo "Minifying files from $SITE_DIR to $OUTPUT_DIR"

# Copy entire directory structure
cp -r "$SITE_DIR/." "$OUTPUT_DIR/"

# Simple minification functions using sed
minify_html() {
    local file="$1"
    # Remove HTML comments, collapse whitespace
    sed -i -e 's/<!--.*-->//g' \
           -e 's/^[[:space:]]*//g' \
           -e 's/[[:space:]]*$//g' \
           -e '/^$/d' "$file"
}

minify_css() {
    local file="$1"
    # Remove CSS comments and extra whitespace
    sed -i -e 's|/\*.*\*/||g' \
           -e 's/^[[:space:]]*//g' \
           -e 's/[[:space:]]*$//g' \
           -e '/^$/d' "$file"
}

minify_js() {
    local file="$1"
    # Remove single-line comments and extra whitespace (basic)
    sed -i -e 's|//.*$||g' \
           -e 's/^[[:space:]]*//g' \
           -e 's/[[:space:]]*$//g' \
           -e '/^$/d' "$file"
}

minify_xml() {
    local file="$1"
    # Remove XML comments and extra whitespace
    sed -i -e 's/<!--.*-->//g' \
           -e 's/^[[:space:]]*//g' \
           -e 's/[[:space:]]*$//g' \
           -e '/^$/d' "$file"
}

minify_json() {
    local file="$1"
    # Remove whitespace from JSON (simple approach)
    if command -v jq >/dev/null 2>&1; then
        jq -c . "$file" > "$file.tmp" && mv "$file.tmp" "$file"
    else
        # Fallback: basic whitespace removal
        sed -i -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g' "$file"
    fi
}

# Process each file type
cd "$OUTPUT_DIR"

for ext in "${EXTENSIONS[@]}"; do
    echo "Processing .$ext files..."

    find . -type f -name "*.$ext" | while read -r file; do
        case "$ext" in
            html|htm)
                minify_html "$file"
                ;;
            css)
                minify_css "$file"
                ;;
            js)
                minify_js "$file"
                ;;
            xml)
                minify_xml "$file"
                ;;
            json)
                minify_json "$file"
                ;;
        esac
        echo "Minified: $file"
    done
done

# Report results
TOTAL=$(find . -type f \( -name "*.html" -o -name "*.css" -o -name "*.js" -o -name "*.xml" -o -name "*.json" \) | wc -l)
echo "Minified $TOTAL files"
```

Update bzl file to use external script:

```starlark
def _minify_hugo_site_impl(ctx):
    """Minifies compressible text files in a Hugo site."""
    site_info = ctx.attr.site[HugoSiteInfo]
    site_dir = site_info.output_dir

    output = ctx.actions.declare_directory(ctx.label.name)

    # Use external script for minification logic
    script = ctx.file._minify_script

    # Build arguments
    args = ctx.actions.args()
    args.add(site_dir.path)
    args.add(output.path)
    args.add_all(ctx.attr.extensions)

    ctx.actions.run(
        inputs = [site_dir],
        outputs = [output],
        executable = script,
        arguments = [args],
        mnemonic = "MinifyHugoSite",
        progress_message = "Minifying Hugo site files",
    )

    return [
        DefaultInfo(files = depset([output])),
        OutputGroupInfo(
            minified = depset([output]),
        ),
    ]

minify_hugo_site = rule(
    # ... (same doc as before)
    implementation = _minify_hugo_site_impl,
    attrs = {
        "site": attr.label(
            doc = "The hugo_site target to minify",
            providers = [HugoSiteInfo],
            mandatory = True,
        ),
        "extensions": attr.string_list(
            doc = "File extensions to minify (without the dot)",
            default = ["html", "css", "js", "xml", "json"],
        ),
        "_minify_script": attr.label(
            default = "//hugo/internal:hugo_site_minify.sh",
            allow_single_file = True,
            executable = True,
            cfg = "exec",
        ),
    },
)
```

**Success Criteria**:
- HTML files have comments removed and whitespace collapsed
- CSS files have comments removed and whitespace reduced
- JS files have basic comment removal
- XML/JSON files processed appropriately
- Files remain functionally equivalent (no broken output)
- Build completes successfully

**Testing**:
```bash
# Build minified site
bazel build //site_simple:site_minified

# Compare file sizes
du -sh bazel-bin/site_simple/site/
du -sh bazel-bin/site_simple/site_minified/

# Verify a sample file is minified
cat bazel-bin/site_simple/site/index.html | wc -l
cat bazel-bin/site_simple/site_minified/index.html | wc -l
```

**Dependencies**: Task 1.1 (requires rule structure)

**Status**: Pending

---

### Task 1.3: Add BUILD File for Internal Script (1h) - MICRO

**Scope**: Create BUILD file in hugo/internal/ to export the minification script.

**Files** (1 file):
- `hugo/internal/BUILD.bazel` (create or modify)

**Context**:
- Need to make hugo_site_minify.sh available as a label
- Follow Bazel conventions for executable scripts
- May need to export other internal files if not already done

**Implementation**:

```python
# hugo/internal/BUILD.bazel
exports_files([
    "hugo_site_minify.sh",
])

sh_binary(
    name = "minify_script",
    srcs = ["hugo_site_minify.sh"],
    visibility = ["//visibility:public"],
)
```

**Success Criteria**:
- Script is accessible via `//hugo/internal:hugo_site_minify.sh` label
- Rule can reference script in `_minify_script` attribute
- Build completes without errors

**Testing**:
```bash
bazel build //hugo/internal:minify_script
```

**Dependencies**: Task 1.2 (requires script to exist)

**Status**: Pending

---

### Task 1.4: Create Integration Test (2h) - SMALL

**Scope**: Create comprehensive integration test for minify_hugo_site rule.

**Files** (3 files):
- `test_integration/minify/BUILD.bazel` (create)
- `test_integration/minify/test_minify.sh` (create)
- `test_integration/minify/config.yaml` (create)

**Context**:
- Follow existing test patterns in test_integration/
- Create simple Hugo site with sample HTML/CSS/JS
- Verify minification produces smaller output
- Verify output is functionally valid

**Implementation**:

```yaml
# test_integration/minify/config.yaml
baseURL: "https://example.com"
languageCode: "en-us"
title: "Minify Test Site"
```

```python
# test_integration/minify/BUILD.bazel
load("//hugo:rules.bzl", "hugo_site", "minify_hugo_site")

hugo_site(
    name = "test_site",
    config = "config.yaml",
    content = glob(["content/**"]),
    static = glob(["static/**"]),
    theme = "//test_integration/minify/themes/test_theme",
)

minify_hugo_site(
    name = "test_site_minified",
    site = ":test_site",
)

sh_test(
    name = "test_minify",
    srcs = ["test_minify.sh"],
    data = [
        ":test_site",
        ":test_site_minified",
    ],
)
```

```bash
#!/bin/bash
# test_integration/minify/test_minify.sh
set -euo pipefail

# Get output directories
ORIGINAL="$1"
MINIFIED="$2"

echo "Testing minification..."

# Test 1: Minified version exists
if [ ! -d "$MINIFIED" ]; then
    echo "FAIL: Minified directory does not exist"
    exit 1
fi

# Test 2: Minified files should be smaller or equal
ORIGINAL_SIZE=$(du -sb "$ORIGINAL" | cut -f1)
MINIFIED_SIZE=$(du -sb "$MINIFIED" | cut -f1)

echo "Original size: $ORIGINAL_SIZE bytes"
echo "Minified size: $MINIFIED_SIZE bytes"

if [ "$MINIFIED_SIZE" -gt "$ORIGINAL_SIZE" ]; then
    echo "FAIL: Minified output is larger than original"
    exit 1
fi

# Test 3: HTML files should have fewer lines (whitespace removed)
if [ -f "$ORIGINAL/index.html" ]; then
    ORIG_LINES=$(wc -l < "$ORIGINAL/index.html")
    MIN_LINES=$(wc -l < "$MINIFIED/index.html")

    echo "Original lines: $ORIG_LINES"
    echo "Minified lines: $MIN_LINES"

    if [ "$MIN_LINES" -ge "$ORIG_LINES" ]; then
        echo "WARN: Minified HTML does not have fewer lines"
    fi
fi

# Test 4: Files should be valid (basic check)
if [ -f "$MINIFIED/index.html" ]; then
    if ! grep -q "<html" "$MINIFIED/index.html"; then
        echo "FAIL: Minified HTML appears corrupted"
        exit 1
    fi
fi

echo "PASS: All minification tests passed"
exit 0
```

**Success Criteria**:
- Test builds and runs successfully
- Verifies minified output is smaller
- Verifies output structure is maintained
- Verifies files are not corrupted

**Testing**:
```bash
bazel test //test_integration/minify:test_minify
```

**Dependencies**: Task 1.2, 1.3 (requires working rule)

**Status**: Pending

---

### Task 1.5: Update Documentation (1h) - MICRO

**Scope**: Add comprehensive documentation for minify_hugo_site rule.

**Files** (2 files):
- `docs/DOWNSTREAM_INTEGRATION.md` (modify) - Add minify_hugo_site section
- `README.md` (modify) - Add minification to features list

**Context**:
- Follow existing documentation patterns in DOWNSTREAM_INTEGRATION.md
- Provide clear usage examples
- Explain configuration options
- Note limitations of basic minification approach

**Implementation**:

Add to DOWNSTREAM_INTEGRATION.md:

```markdown
### minify_hugo_site

Minifies HTML, CSS, JavaScript, XML, and JSON files from a Hugo site to reduce file sizes for production deployment.

**Usage:**

```starlark
load("//hugo:rules.bzl", "hugo_site", "minify_hugo_site")

hugo_site(
    name = "site",
    config = "config.yaml",
    content = glob(["content/**"]),
)

minify_hugo_site(
    name = "site_minified",
    site = ":site",
    extensions = ["html", "css", "js", "xml", "json"],
)
```

**Attributes:**

- `site` (required): The hugo_site target to minify
- `extensions` (optional): List of file extensions to minify (default: ["html", "css", "js", "xml", "json"])

**Output:**

The rule produces a directory tree with minified versions of all matching files. Original directory structure is preserved.

**Minification Strategy:**

This rule uses basic shell-based minification:
- HTML: Removes comments and collapses whitespace
- CSS: Removes comments and extra whitespace
- JavaScript: Removes single-line comments and whitespace (basic)
- XML: Removes comments and whitespace
- JSON: Uses jq for compact formatting (if available)

**Note:** For advanced minification with more aggressive optimization, consider using Hugo's built-in `--minify` flag or integrating dedicated minification tools via rules_js.

**Combining with other rules:**

```starlark
# Minify then gzip
minify_hugo_site(
    name = "site_minified",
    site = ":site",
)

gzip_hugo_site(
    name = "site_compressed",
    site = ":site_minified",
)
```

**Expected Results:**

- HTML files: 10-30% size reduction
- CSS files: 40-60% size reduction
- JavaScript files: 20-40% size reduction (basic minification)
```

**Success Criteria**:
- Documentation is clear and accurate
- Examples are complete and buildable
- Limitations are clearly stated
- Follows existing documentation style

**Testing**: Manual review of documentation

**Dependencies**: Task 1.2 (requires rule to document)

**Status**: Pending

---

## Dependency Visualization

```
Story 1: Core Minification Rule
├─ Task 1.1 (2h) Create Rule Structure
│   └─→ Task 1.2 (3h) Integrate Minification Tools
│        └─→ Task 1.3 (1h) Add BUILD File
│             └─→ Task 1.4 (2h) Integration Test
│                  └─→ Task 1.5 (1h) Documentation

Total Sequential Path: 9 hours
Parallel Opportunities: Tasks 1.4 and 1.5 can run in parallel after 1.3
```

---

## Context Preparation

Before starting Task 1.1, review:
1. `/home/tstapler/Programming/rules_hugo/hugo/internal/hugo_site_gzip.bzl` - Pattern to follow
2. `/home/tstapler/Programming/rules_hugo/hugo/internal/hugo_site_info.bzl` - Provider definition
3. `/home/tstapler/Programming/rules_hugo/hugo/rules.bzl` - Export pattern
4. Bazel documentation on actions and tree artifacts

---

## Future Enhancements

After MVP is complete, consider:
1. **Advanced Minification**: Integrate terser, html-minifier via rules_js
2. **Configurable Minifier**: Allow user to specify minification tool
3. **Selective Minification**: Per-file-type enable/disable flags
4. **Minification Metrics**: Report size savings in build output
5. **Source Maps**: Generate source maps for debugging minified code

---

## Known Issues

None yet - this is a new feature.

---

## Progress Tracking

**Epic Progress**: 0/5 tasks completed (0%)

**Story 1 Progress**: 0/5 tasks completed (0%)

**Tasks**:
- Pending: Task 1.1, 1.2, 1.3, 1.4, 1.5
- In Progress: None
- Completed: None

**Next Action**: Start with Task 1.1 - Create Basic Minification Rule Structure
