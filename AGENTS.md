# Agent Operating Instructions for rules_hugo

This document provides operating instructions for coding agents working in the rules_hugo Bazel repository. It covers build/lint/test commands, code style guidelines, and development workflow.

## Build, Lint, and Test Commands

### Build Commands

```bash
# Build a specific target
bazel build //path/to:target

# Build all targets in a package
bazel build //path/to:all

# Build with verbose output
bazel build //path/to:target -v

# Clean build cache
bazel clean

# Build and show dependency graph
bazel query 'deps(//path/to:target)' --output graph
```

### Test Commands

```bash
# Run all tests in workspace
bazel test //...

# Run tests in specific package
bazel test //path/to:all

# Run single test target
bazel test //test_integration/minify:test_minify

# Run tests with verbose output
bazel test //path/to:target -v

# Run tests and show output even on success
bazel test //path/to:target --test_output=all

# Run flaky tests multiple times
bazel test //path/to:target --flaky_test_attempts=3

# Debug failing test
bazel test //path/to:target --test_output=errors --test_summary=detailed
```

### Integration Test Commands

```bash
# Run integration test (shell script wrapper)
bazel test //test_integration/minify:test_minify

# Build integration test target without running
bazel build //test_integration/minify:test_minify

# Debug integration test script
bazel run //test_integration/minify:test_minify -- --verbose
```

### Lint and Code Quality

```bash
# Build to check Starlark syntax (primary linting)
bazel build //hugo/...

# Query for unused dependencies
bazel query 'buildfiles(//...)' | xargs -n1 bazel query "deps($0)" --output label_kind | grep -E "(source file|generated file)" | sort | uniq -c | sort -nr

# Check for BUILD file issues
bazel run @bazel_tools//tools/build_defs/pkg:build_tar --help 2>/dev/null || echo "No explicit linter configured"
```

### Development Server

```bash
# Start Hugo development server
bazel run //site_simple:site_serve

# Serve complex site
bazel run //site_complex:serve
```

## Code Style Guidelines

### Language and File Organization

**Starlark (.bzl files):**
- Use Starlark (Bazel's Python-like language) for all rule definitions
- File extension: `.bzl` for rule libraries, `.bzl` for BUILD files
- One rule per file for complex rules, multiple simple rules allowed

**Shell Scripts (.sh files):**
- Use Bash for all shell scripts
- File extension: `.sh`
- Must be executable (`chmod +x`)
- Include `#!/bin/bash` shebang

### Import Organization

```python
# 1. Load statements first (alphabetically sorted)
load("//hugo:internal/hugo_site_info.bzl", "HugoSiteInfo")
load("//hugo:rules.bzl", "hugo_site", "minify_hugo_site")

# 2. Standard library imports (if any)
# None in this codebase

# 3. Local imports
# None in this codebase
```

### Naming Conventions

**Variables and Functions:**
- `snake_case` for all variables, function names, and attributes
- Example: `site_info`, `output_dir`, `find_expr`

**Rules and Macros:**
- `snake_case` for rule names and macro names
- Example: `minify_hugo_site`, `gzip_hugo_site`

**Constants:**
- `UPPER_SNAKE_CASE` for constants
- Example: `DEFAULT_EXTENSIONS = ["html", "css", "js"]`

**Files:**
- `snake_case` for .bzl files: `hugo_site_minify.bzl`
- `snake_case` for BUILD files: `BUILD.bazel`

### Code Formatting

**Indentation:**
- 4 spaces (no tabs)
- Consistent across all files

**Line Length:**
- Maximum 100 characters
- Break long lines logically
- Use parentheses for line continuation in function calls

**Spacing:**
```python
# Correct
def function_name(arg1, arg2):
    if condition:
        do_something()

# Incorrect
def function_name(arg1,arg2):
    if condition:
        do_something()
```

**String Formatting:**
```python
# Use .format() for complex strings
script_content = """script""".format(
    var1=value1,
    var2=value2,
)

# Use f-strings for simple cases
message = f"Processing {file_count} files"
```

### Documentation Standards

**Rule Documentation:**
```python
rule_name = rule(
    doc = """
    Brief description of what the rule does.

    More detailed explanation with examples.

    Example:
        rule_name(
            name = "example",
            attr = "value",
        )
    """,
    implementation = _rule_name_impl,
    attrs = {
        "attr": attr.string(
            doc = "Description of the attribute",
            default = "value",
        ),
    },
)
```

**Function Documentation:**
```python
def function_name(ctx):
    """Brief description of function purpose.

    Args:
        ctx: The rule context.

    Returns:
        List of providers.
    """
    # Implementation
```

### Type Annotations and Validation

**Starlark Types:**
- Dynamic typing, but document expected types in docstrings
- Use descriptive variable names that imply type
- Validate inputs in rule implementations

```python
def _rule_impl(ctx):
    # Validate required attributes
    if not ctx.attr.site:
        fail("site attribute is required")

    # Type hints through naming
    site_info = ctx.attr.site[HugoSiteInfo]  # Provider type
    extensions = ctx.attr.extensions         # string_list
    output_dir = ctx.actions.declare_directory(ctx.label.name)  # File
```

### Error Handling

**Rule Validation:**
```python
def _rule_impl(ctx):
    # Fail fast on invalid inputs
    if ctx.attr.compression_level < 1 or ctx.attr.compression_level > 9:
        fail("compression_level must be between 1 and 9, got: {}".format(
            ctx.attr.compression_level))

    # Handle optional attributes
    extensions = ctx.attr.extensions or ["html", "css", "js"]
```

**Shell Script Error Handling:**
```bash
#!/bin/bash
set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Handle errors gracefully
if ! command_exists; then
    echo "Error: command not found" >&2
    exit 1
fi
```

### Attribute Definitions

**Consistent Attribute Patterns:**
```python
attrs = {
    "site": attr.label(
        doc = "The hugo_site target to process",
        providers = [HugoSiteInfo],
        mandatory = True,
    ),
    "extensions": attr.string_list(
        doc = "File extensions to process (without dot)",
        default = ["html", "css", "js", "xml", "json"],
    ),
    "compression_level": attr.int(
        doc = "Compression level (1-9)",
        default = 9,
        values = [1, 2, 3, 4, 5, 6, 7, 8, 9],
    ),
}
```

### Testing Guidelines

**Unit Tests:**
- Use `sh_test` for shell-based tests
- Include test data as `data` attribute
- Test both success and failure cases

**Integration Tests:**
- Mirror production structure in `test_integration/`
- Test end-to-end functionality
- Include comprehensive validation scripts

**Test File Organization:**
```
test_integration/
  feature_name/
    BUILD.bazel          # Test targets
    test_feature.sh      # Test script
    content/            # Test data
    config.yaml         # Test config
```

### Commit and Version Control

**Commit Messages:**
```
type(scope): description

- Use conventional commits
- Types: feat, fix, docs, style, refactor, test, chore
- Scope: rule name or component (e.g., minify, gzip, site)
- Keep first line under 72 characters
```

**Branching:**
- `main` for stable releases
- `feature/*` for new features
- `fix/*` for bug fixes

### Performance Considerations

**Rule Performance:**
- Minimize file operations in rules
- Use `depset` for large file collections
- Prefer declarative actions over complex scripts

**Build Optimization:**
- Use appropriate `OutputGroupInfo` for selective outputs
- Leverage Bazel's caching and incremental builds
- Keep rule implementations focused and simple

## Development Workflow

### Adding New Rules

1. Create `.bzl` file in `hugo/internal/`
2. Implement rule with proper validation
3. Add comprehensive documentation
4. Export in `hugo/rules.bzl`
5. Add example usage in test BUILD files
6. Create integration tests

### Debugging Bazel Issues

```bash
# Show build execution details
bazel build //target --explain=file.txt

# Debug rule implementation
bazel build //target --experimental_action_listener=//tools:debug

# Query dependency graph
bazel query 'allpaths(//source, //target)'
```

### Common Patterns

**Directory Tree Outputs:**
```python
output = ctx.actions.declare_directory(ctx.label.name)
# Use for rules that produce multiple files
```

**Script Generation:**
```python
script = ctx.actions.declare_file(ctx.label.name + "_script.sh")
ctx.actions.write(output=script, content=script_content, is_executable=True)
ctx.actions.run(executable=script, inputs=[...], outputs=[...])
```

**Provider Pattern:**
```python
def _rule_impl(ctx):
    return [
        DefaultInfo(files=depset([output])),
        OutputGroupInfo(group_name=depset([output])),
    ]
```

This guide ensures consistent, maintainable code across the rules_hugo codebase. Follow these guidelines for all new contributions.