# Downstream Integration Guide

## Overview

The `rules_hugo` package has been enhanced to make it much easier to integrate Hugo site output with downstream Bazel rules and tools. This guide explains the improvements and how to use them.

## The Problem (Before)

Previously, the `hugo_site` rule only exposed output as a tree artifact (directory). This made downstream processing difficult because:

1. **Tree artifacts are opaque**: When using `$(locations :site)` in a genrule, you get a directory path, but accessing individual files requires complex shell scripting
2. **No structured information**: There was no way for downstream rules to query what was generated
3. **Path resolution issues**: Working with files inside the tree artifact in Bazel's sandbox was error-prone

### Example of the Old Problem

```python
# This was difficult and error-prone
genrule(
    name = "gzip_site",
    srcs = [":site"],
    outs = ["site_gz.tar"],
    cmd = """
        # Complex shell scripting needed
        SITE_DIR=$$(dirname $$(echo $(locations :site) | cut -d' ' -f1))
        cd $$SITE_DIR
        find . -type f -name "*.html" | while read f; do
            gzip -c "$$f" > "$$f.gz"
        done
        # More complex path manipulation...
    """,
)
```

## The Solution (After)

The improvements include:

### 1. HugoSiteInfo Provider

All `hugo_site` targets now expose a `HugoSiteInfo` provider with structured information:

```python
HugoSiteInfo(
    output_dir = <tree artifact>,  # The generated site directory
    files = <depset>,              # Depset of all files (if expanded)
    base_url = "...",              # Configured base URL
    name = "...",                  # Target name
)
```

This allows downstream rules to access Hugo site information programmatically instead of through complex path manipulation.

### 2. gzip_hugo_site Rule

A ready-to-use rule for creating gzipped versions of Hugo site files:

```python
load("@build_stack_rules_hugo//hugo:rules.bzl", "hugo_site", "gzip_hugo_site")

hugo_site(
    name = "my_site",
    config = "config.yaml",
    content = glob(["content/**"]),
)

# Create .gz versions for nginx gzip_static
gzip_hugo_site(
    name = "my_site_gz",
    site = ":my_site",
    extensions = ["html", "css", "js", "xml", "json"],
    compression_level = 9,
)
```

**Benefits:**
- No complex genrule scripting needed
- Proper Bazel action with memoization
- Configurable file types and compression level
- Clean separation of concerns

### 3. minify_hugo_site Rule

Minifies HTML, CSS, JavaScript, XML, and JSON files to reduce file sizes for production deployment:

```python
load("@build_stack_rules_hugo//hugo:rules.bzl", "hugo_site", "minify_hugo_site")

hugo_site(
    name = "my_site",
    config = "config.yaml",
    content = glob(["content/**"]),
)

# Minify for production
minify_hugo_site(
    name = "my_site_minified",
    site = ":my_site",
    extensions = ["html", "css", "js", "xml", "json"],
)
```

**Benefits:**
- **40-60% size reduction** for CSS/JS files
- **10-30% reduction** for HTML files
- Removes comments and unnecessary whitespace
- Hermetic build (no external dependencies)

**Minification Strategy:**

This rule uses shell-based minification:
- **HTML**: Removes comments (`<!-- ... -->`) and collapses whitespace
- **CSS**: Removes comments (`/* ... */`) and extra whitespace
- **JavaScript**: Removes single-line (`//`) and multi-line (`/* */`) comments
- **XML**: Removes comments and whitespace
- **JSON**: Uses `jq` for compact formatting (if available)

**Combining with Compression:**

```python
# Best practice: Minify then gzip for maximum size reduction
minify_hugo_site(
    name = "site_minified",
    site = ":my_site",
)

gzip_hugo_site(
    name = "site_compressed",
    site = ":site_minified",  # Chain minification → compression
)

# Use both in deployment
pkg_tar(
    name = "static_assets",
    srcs = [":site_minified"],  # Minified originals
    package_dir = "/usr/share/nginx/html",
)

pkg_tar(
    name = "static_assets_gz",
    srcs = [":site_compressed"],  # Pre-compressed .gz files
    package_dir = "/usr/share/nginx/html",
)
```

**Expected Results:**
- HTML files: 10-30% size reduction
- CSS files: 40-60% size reduction
- JavaScript files: 20-40% size reduction

**Note:** For advanced minification with more aggressive optimization, consider using Hugo's built-in `--minify` flag or integrating dedicated minification tools via rules_js.

### 4. hugo_site_files Rule

A utility for getting a manifest of all generated files:

```python
load("@build_stack_rules_hugo//hugo:rules.bzl", "hugo_site_files")

hugo_site_files(
    name = "my_site_files",
    site = ":my_site",
)

# Use in downstream rules
genrule(
    name = "process_site",
    srcs = [":my_site_files"],
    outs = ["processed.tar"],
    cmd = """
        # Access the manifest (first location)
        MANIFEST=$$(echo $(locations :my_site_files) | grep manifest.txt)

        # Access the site directory (second location)
        SITE_DIR=$$(dirname $$(echo $(locations :my_site_files) | cut -d' ' -f2))

        # Iterate over files easily
        cd $$SITE_DIR
        while read file; do
            echo "Processing: $$file"
            # Your processing here
        done < $$MANIFEST

        tar -czf $@ -C $$SITE_DIR .
    """,
)
```

**Benefits:**
- Easier file iteration in genrules
- Consistent file ordering (sorted)
- Better error messages

### 5. process_hugo_site Rule

A generic processor for applying custom transformations:

```python
load("@build_stack_rules_hugo//hugo:rules.bzl", "process_hugo_site")

process_hugo_site(
    name = "minified_site",
    site = ":my_site",
    processor = "//tools:minify",  # Your custom tool
    processor_args = ["--css", "--js"],
    processor_data = ["//tools:minify_config.json"],
)
```

The processor receives:
- Argument 1: Input site directory path
- Argument 2: Output directory path
- Additional args: As specified in `processor_args`

**Benefits:**
- Reusable pattern for transformations
- Proper Bazel action graph
- Type-safe with `HugoSiteInfo` provider

## Complete Example: Nginx with Gzip

Here's how to use the improvements for a complete nginx deployment:

```python
load("@build_stack_rules_hugo//hugo:rules.bzl", "hugo_site", "gzip_hugo_site")
load("@rules_pkg//pkg:tar.bzl", "pkg_tar")
load("@rules_oci//oci:defs.bzl", "oci_image")

# 1. Build the Hugo site
hugo_site(
    name = "site",
    config = "config.yaml",
    content = glob(["content/**"]),
    static = glob(["static/**"]),
    theme = ":my_theme",
)

# 2. Create gzipped versions (simple!)
gzip_hugo_site(
    name = "site_gz",
    site = ":site",
)

# 3. Package original files
pkg_tar(
    name = "static_assets",
    srcs = [":site"],
    package_dir = "/usr/share/nginx/html",
)

# 4. Package gzipped files
pkg_tar(
    name = "static_assets_gz",
    srcs = [":site_gz"],
    package_dir = "/usr/share/nginx/html",
)

# 5. Build container with both
oci_image(
    name = "nginx_image",
    base = "@nginx_base",
    tars = [
        ":static_assets",
        ":static_assets_gz",
        ":nginx_configs",
    ],
)
```

**Configure nginx for gzip_static:**

```nginx
server {
    listen 80;
    root /usr/share/nginx/html;

    # Enable gzip_static to use pre-compressed files
    gzip_static on;

    # Fallback to dynamic gzip if .gz doesn't exist
    gzip on;
    gzip_types text/css application/javascript application/json text/xml;
}
```

## Migration Guide

### From Complex Genrules to gzip_hugo_site

**Before:**
```python
genrule(
    name = "site_gz",
    srcs = [":site"],
    outs = ["site_gz.tar"],
    cmd = """
        # 30+ lines of complex shell scripting
        # Error-prone path manipulation
        # Hard to maintain
    """,
)
```

**After:**
```python
gzip_hugo_site(
    name = "site_gz",
    site = ":site",
)
```

### From Tree Artifact Hacks to hugo_site_files

**Before:**
```python
genrule(
    name = "process",
    srcs = [":site"],
    outs = ["output"],
    cmd = """
        SITE_DIR=$$(dirname $$(echo $(locations :site) | cut -d' ' -f1))
        # Complex find commands
        # Unreliable ordering
    """,
)
```

**After:**
```python
hugo_site_files(
    name = "site_files",
    site = ":site",
)

genrule(
    name = "process",
    srcs = [":site_files"],
    outs = ["output"],
    cmd = """
        MANIFEST=$$(echo $(locations :site_files) | grep manifest.txt)
        SITE_DIR=$$(dirname $$(echo $(locations :site_files) | cut -d' ' -f2))
        while read file; do
            # Process each file
        done < $$MANIFEST
    """,
)
```

## Custom Downstream Rules

You can write your own rules that consume `HugoSiteInfo`:

```python
load("@build_stack_rules_hugo//hugo:rules.bzl", "HugoSiteInfo")

def _my_processor_impl(ctx):
    site_info = ctx.attr.site[HugoSiteInfo]
    input_dir = site_info.output_dir
    output = ctx.actions.declare_directory(ctx.label.name)

    # Process the site
    ctx.actions.run(
        inputs = [input_dir],
        outputs = [output],
        executable = ctx.executable.tool,
        arguments = [input_dir.path, output.path],
    )

    return [DefaultInfo(files = depset([output]))]

my_processor = rule(
    implementation = _my_processor_impl,
    attrs = {
        "site": attr.label(
            providers = [HugoSiteInfo],
            mandatory = True,
        ),
        "tool": attr.label(
            executable = True,
            cfg = "exec",
        ),
    },
)
```

## Benefits Summary

1. **Simpler**: Common operations like gzipping are one-liners
2. **Type-Safe**: `HugoSiteInfo` provider ensures correct usage
3. **Maintainable**: Less shell scripting, more declarative Bazel
4. **Reliable**: Proper action graph, better caching
5. **Extensible**: Easy to write custom downstream rules

## API Reference

### gzip_hugo_site

```python
gzip_hugo_site(
    name = "...",
    site = "...",                    # hugo_site target (required)
    extensions = [...],              # File extensions to gzip (default: ["html", "css", "js", "xml", "json", "txt"])
    compression_level = 9,           # 1-9, where 9 is max (default: 9)
)
```

### hugo_site_files

```python
hugo_site_files(
    name = "...",
    site = "...",                    # hugo_site target (required)
)
```

Outputs:
- `<name>_manifest.txt`: Sorted list of all files (relative paths)
- Tree artifact: The site directory itself

### process_hugo_site

```python
process_hugo_site(
    name = "...",
    site = "...",                    # hugo_site target (required)
    processor = "...",               # Executable to run (required)
    processor_args = [...],          # Additional arguments (optional)
    processor_data = [...],          # Additional data files (optional)
)
```

The processor executable receives:
1. Input site directory path
2. Output directory path
3. Any additional args from `processor_args`

### HugoSiteInfo Provider

```python
HugoSiteInfo(
    output_dir = <File>,             # Tree artifact of generated site
    files = <depset[File]>,          # Depset of all files (if expanded)
    base_url = <string>,             # Configured base URL
    name = <string>,                 # Target name
)
```

## Troubleshooting

### "No such provider: HugoSiteInfo"

Make sure you're loading the provider:
```python
load("@build_stack_rules_hugo//hugo:rules.bzl", "HugoSiteInfo")
```

### "Tree artifact cannot be used in $(locations)"

Use `hugo_site_files` to get a manifest and cleaner access to the directory.

### Genrule can't find files in site directory

Ensure you're accessing the directory path correctly:
```bash
# With hugo_site_files
SITE_DIR=$$(dirname $$(echo $(locations :site_files) | cut -d' ' -f2))
```

### Gzipped files not being used by nginx

1. Verify both original and .gz files are in the same directory
2. Check nginx config has `gzip_static on;`
3. Verify file extensions match nginx `gzip_types`
