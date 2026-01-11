# Epic: Critical CSS Extraction for Hugo Sites

## Overview

**Goal**: Provide automated critical CSS extraction and inlining for Hugo site outputs to improve Core Web Vitals by eliminating render-blocking CSS.

**Value Proposition**:
- Instant above-fold rendering (improves FCP/LCP)
- Eliminates render-blocking CSS resources
- Lazy-loads remaining CSS for optimal performance
- Significant Core Web Vitals improvement

**Success Metrics**:
- Rule successfully extracts and inlines critical CSS
- HTML files load faster with above-fold content
- Integration test validates critical CSS extraction
- Documentation with working example

**Target Effort**: 1-2 weeks (40-80 hours total)

---

## Story Breakdown

### Story 1: Core Critical CSS Rule (1-2 weeks)

**Objective**: Create `critical_css_hugo_site` rule that processes Hugo site output and extracts/inlines critical CSS.

**Deliverables**:
- `hugo/internal/hugo_site_critical_css.bzl` implementation
- Node.js processor script using Beasties library
- Basic integration test

---

## Atomic Tasks

### Task 1.1: Create Critical CSS Rule Structure (4h) - LARGE

**Scope**: Create `critical_css_hugo_site` rule skeleton with Node.js integration for critical CSS processing.

**Files** (5 files):
- `hugo/internal/hugo_site_critical_css.bzl` (create) - New rule implementation
- `hugo/internal/tools/critical_css/process.js` (create) - Node.js processor script
- `hugo/internal/tools/critical_css/BUILD.bazel` (create) - Export processor script
- `hugo/rules.bzl` (modify) - Add export for new rule
- `site_simple/BUILD.bazel` (modify) - Add example usage

**Context**:
- Study existing rules for pattern consistency
- Understand HugoSiteInfo provider usage
- Research critical CSS extraction libraries (Beasties)
- Review Node.js integration in Bazel builds
- Understand HTML processing and CSS extraction

**Implementation**:

```starlark
# hugo/internal/hugo_site_critical_css.bzl
load("//hugo/internal:hugo_site_info.bzl", "HugoSiteInfo")

def _critical_css_hugo_site_impl(ctx):
    """Extracts critical CSS and inlines it in HTML files."""
    site_info = ctx.attr.site[HugoSiteInfo]
    site_dir = site_info.output_dir

    # Output directory for site with critical CSS
    output = ctx.actions.declare_directory(ctx.label.name)

    # Get the Node.js processor script
    processor_script = ctx.file._processor

    # Create wrapper script that invokes the processor
    script_content = """#!/bin/bash
set -euo pipefail

SITE_DIR="{site_dir}"
OUTPUT_DIR="{output_dir}"
PROCESSOR="{processor}"

echo "Extracting critical CSS from Hugo site"

# Check if node is available
if ! command -v node &> /dev/null; then
    echo "ERROR: Node.js is required but not found in PATH"
    echo "Please install Node.js 18+ from https://nodejs.org/"
    exit 1
fi

# Check Node.js version
NODE_VERSION=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 18 ]; then
    echo "ERROR: Node.js 18+ is required (found v$NODE_VERSION)"
    exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Run the Node.js processor
node "$PROCESSOR" "$SITE_DIR" "$OUTPUT_DIR"

echo "Critical CSS extraction complete"
""".format(
        site_dir = site_dir.path,
        output_dir = output.path,
        processor = processor_script.path,
    )

    script = ctx.actions.declare_file(ctx.label.name + "_critical.sh")
    ctx.actions.write(
        output = script,
        content = script_content,
        is_executable = True,
    )

    ctx.actions.run(
        inputs = [site_dir, processor_script],
        outputs = [output],
        executable = script,
        mnemonic = "CriticalCSSHugoSite",
        progress_message = "Extracting critical CSS from Hugo site",
    )

    return [
        DefaultInfo(files = depset([output])),
        OutputGroupInfo(
            critical = depset([output]),
        ),
    ]

critical_css_hugo_site = rule(
    doc = """
    Extracts and inlines critical CSS in a Hugo site.

    This rule processes HTML files from a hugo_site output and:
    - Extracts critical (above-the-fold) CSS using Beasties
    - Inlines it directly in the HTML <head>
    - Lazy-loads the remaining CSS
    - Compresses the critical CSS

    This significantly improves First Contentful Paint (FCP) and Largest
    Contentful Paint (LCP) metrics by eliminating render-blocking CSS.

    **Requirements:**
    - Node.js 18+ must be installed and available in PATH
    - This is a temporary limitation; future versions will be fully hermetic

    Example:
        hugo_site(
            name = "site",
            config = "config.yaml",
            content = glob(["content/**"]),
            static = glob(["static/**"]),
        )

        critical_css_hugo_site(
            name = "site_critical",
            site = ":site",
        )
    """,
    implementation = _critical_css_hugo_site_impl,
    attrs = {
        "site": attr.label(
            doc = "The hugo_site target to process",
            providers = [HugoSiteInfo],
            mandatory = True,
        ),
        "_processor": attr.label(
            default = "//hugo/internal/tools/critical_css:process.js",
            allow_single_file = True,
        ),
    },
)
```

**Success Criteria**:
- Rule builds without errors
- Creates output directory with correct structure
- Accepts HugoSiteInfo provider input
- Returns DefaultInfo and OutputGroupInfo correctly
- Node.js integration works correctly

**Testing**:
```bash
cd /home/tstapler/Programming/rules_hugo
bazel build //site_simple:site_critical
ls -la bazel-bin/site_simple/site_critical/
```

**Dependencies**: None (first task)

**Status**: Completed

---

### Task 1.2: Implement Node.js Processor Script (4h) - LARGE

**Scope**: Create Node.js script using Beasties library for critical CSS extraction and inlining.

**Files** (2 files):
- `hugo/internal/tools/critical_css/process.js` (create) - Main processor script
- `package.json` (modify) - Add beasties dependency

**Context**:
- Research Beasties library for critical CSS extraction
- Understand HTML processing and CSS manipulation
- Implement file copying and directory traversal
- Handle errors and edge cases

**Implementation**:

```javascript
#!/usr/bin/env node
/**
 * Critical CSS processor for Hugo sites
 * Extracts and inlines critical CSS using Beasties
 */

const fs = require('fs');
const path = require('path');
const Beasties = require('beasties');

// Parse command line arguments
const args = process.argv.slice(2);
if (args.length < 2) {
  console.error('Usage: process.js <input_dir> <output_dir>');
  process.exit(1);
}

const inputDir = args[0];
const outputDir = args[1];

// Create output directory
fs.mkdirSync(outputDir, { recursive: true });

// Configure Beasties
const beasties = new Beasties({
  path: inputDir,
  reduceInlineStyles: true,
  preload: 'swap',  // Use font-display: swap for better performance
  compress: true,   // Compress the critical CSS
  logLevel: 'info',
});

// Recursively find all HTML files
function findHTMLFiles(dir, fileList = []) {
  const files = fs.readdirSync(dir);

  files.forEach(file => {
    const filePath = path.join(dir, file);
    const stat = fs.statSync(filePath);

    if (stat.isDirectory()) {
      findHTMLFiles(filePath, fileList);
    } else if (file.endsWith('.html')) {
      fileList.push(filePath);
    }
  });

  return fileList;
}

// Copy directory recursively (excluding HTML files initially)
function copyDirectory(src, dest) {
  const files = fs.readdirSync(src);

  files.forEach(file => {
    const srcPath = path.join(src, file);
    const destPath = path.join(dest, file);
    const stat = fs.statSync(srcPath);

    if (stat.isDirectory()) {
      fs.mkdirSync(destPath, { recursive: true });
      copyDirectory(srcPath, destPath);
    } else if (!file.endsWith('.html')) {
      fs.copyFileSync(srcPath, destPath);
    }
  });
}

async function processHTMLFiles() {
  console.log(`Processing HTML files from ${inputDir} to ${outputDir}`);

  // Copy all non-HTML files first
  copyDirectory(inputDir, outputDir);

  // Find all HTML files
  const htmlFiles = findHTMLFiles(inputDir);
  console.log(`Found ${htmlFiles.length} HTML files to process`);

  let processed = 0;
  let failed = 0;

  for (const htmlFile of htmlFiles) {
    try {
      const html = fs.readFileSync(htmlFile, 'utf8');
      const relativePath = path.relative(inputDir, htmlFile);
      const outputPath = path.join(outputDir, relativePath);

      console.log(`Processing: ${relativePath}`);

      // Process with Beasties
      const result = await beasties.process(html);

      // Ensure output directory exists
      fs.mkdirSync(path.dirname(outputPath), { recursive: true });

      // Write processed HTML
      fs.writeFileSync(outputPath, result);
      processed++;

    } catch (error) {
      console.error(`Error processing ${htmlFile}:`, error.message);
      failed++;
    }
  }

  console.log(`\nProcessed ${processed} HTML files`);
  if (failed > 0) {
    console.error(`Failed to process ${failed} files`);
    process.exit(1);
  }
}

// Run the processor
processHTMLFiles().catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});
```

**Success Criteria**:
- Script processes HTML files correctly
- Critical CSS is extracted and inlined
- Remaining CSS is lazy-loaded
- Error handling works for edge cases

**Testing**:
```bash
cd /home/tstapler/Programming/rules_hugo
node hugo/internal/tools/critical_css/process.js test_input_dir test_output_dir
```

**Dependencies**: Task 1.1 (requires rule structure)

**Status**: Completed

---

### Task 1.3: Create Integration Test (3h) - MEDIUM

**Scope**: Create comprehensive integration test for critical_css_hugo_site rule.

**Files** (4 files):
- `test_integration/critical_css/BUILD.bazel` (create)
- `test_integration/critical_css/test_critical_css.sh` (create)
- `test_integration/critical_css/config.yaml` (create)
- `test_integration/critical_css/content/_index.md` (create)
- `test_integration/critical_css/static/css/` (create with test CSS)

**Context**:
- Follow existing test patterns in test_integration/
- Create simple Hugo site with CSS and HTML
- Verify critical CSS extraction and inlining
- Verify output maintains functionality

**Implementation**:

```yaml
# test_integration/critical_css/config.yaml
baseURL: "https://example.com"
languageCode: "en-us"
title: "Critical CSS Test Site"
```

```python
# test_integration/critical_css/BUILD.bazel
load("//hugo:rules.bzl", "hugo_site", "critical_css_hugo_site")

hugo_site(
    name = "test_site",
    config = "config.yaml",
    content = glob(["content/**"]),
    static = glob(["static/**"]),
)

critical_css_hugo_site(
    name = "test_site_critical",
    site = ":test_site",
)
```

**Success Criteria**:
- Test builds and runs successfully
- Verifies critical CSS is inlined in HTML
- Verifies remaining CSS is lazy-loaded
- Verifies output structure is maintained

**Testing**:
```bash
bazel build //test_integration/critical_css:test_site_critical
```

**Dependencies**: Task 1.1, 1.2 (requires working rule and processor)

**Status**: In Progress

---

### Task 1.4: Update Documentation (1h) - MICRO

**Scope**: Add comprehensive documentation for critical_css_hugo_site rule.

**Files** (2 files):
- `docs/DOWNSTREAM_INTEGRATION.md` (modify) - Add critical_css_hugo_site section
- `README.md` (modify) - Add critical CSS to features list

**Context**:
- Follow existing documentation patterns in DOWNSTREAM_INTEGRATION.md
- Provide clear usage examples
- Explain Core Web Vitals benefits
- Note Node.js requirement and future hermetic plans

**Success Criteria**:
- Documentation is clear and accurate
- Examples are complete and buildable
- Performance benefits are clearly stated
- Follows existing documentation style

**Testing**: Manual review of documentation

**Dependencies**: Task 1.1 (requires rule to document)

**Status**: Pending

---

## Dependency Visualization

```
Story 1: Core Critical CSS Rule
├─ Task 1.1 (4h) Create Rule Structure
│   └─→ Task 1.2 (4h) Implement Node.js Processor
│        └─→ Task 1.3 (3h) Integration Test
│             └─→ Task 1.4 (1h) Documentation
```

**Total Sequential Path**: 12 hours

## Context Preparation

Before starting Task 1.1, review:
1. `/home/tstapler/Programming/rules_hugo/hugo/internal/hugo_site_info.bzl` - Provider definition
2. `/home/tstapler/Programming/rules_hugo/hugo/rules.bzl` - Export pattern
3. Beasties library documentation for critical CSS extraction
4. Core Web Vitals and render-blocking CSS concepts

---

## Known Issues

**Performance Issue**: Current implementation has performance problems causing timeouts during processing. The Node.js script may be taking too long to process HTML files or encountering infinite loops.

**Node.js Dependency**: Requires system-installed Node.js 18+, not hermetic. Future versions should bundle Node.js runtime.

**Error Handling**: Limited error handling for malformed HTML or CSS.

---

## Progress Tracking

**Epic Progress**: 2/4 tasks completed (50%)

**Story 1 Progress**: 2/4 tasks completed (50%)

**Tasks**:
- Completed: Task 1.1, 1.2
- In Progress: Task 1.3 (Integration test - blocked by timeout issue)
- Pending: Task 1.4 (Documentation)

**Next Action**: Debug and fix the timeout issue in Task 1.3 integration test</content>
<parameter name="filePath">docs/tasks/critical-css.md