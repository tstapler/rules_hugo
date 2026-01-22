# Bazel 9 Compatibility

This repository is compatible with Bazel 9+ with the following features:

## Compatibility Features

### 1. Bzlmod Support
- Uses `MODULE.bazel` instead of deprecated `WORKSPACE` files
- Compatible with Bazel 6+ Bzlmod features
- Proper module structure with version constraints

### 2. Modern Repository Rules
- Uses `use_repo_rule("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")`
- Compatible with Bazel 9 repository rule patterns
- No deprecated workspace() calls in .bzl files

### 3. Starlark Compatibility
- No deprecated Starlark functions
- Compatible with Bazel 9 Starlark language version
- Proper attribute validation

### 4. Testing Compatibility
- Works with Bazel 9 testing framework
- No deprecated testing utilities
- Modern test patterns

## Bazel 9 Specific Notes

### Module Extensions
- Module extensions use proper `use_extension` syntax
- Repository extensions work with Bzlmod
- No legacy repository rule conflicts

### HTTP Archive
- `@bazel_tools//tools/build_defs/repo:http.bzl` still works in Bazel 9
- Gradual migration path available
- No breaking changes expected

## Usage

### Bazel 9 Installation
```bash
# Install Bazel 9
sudo apt-get update && sudo apt-get install bazel-9

# Or use Bazelisk
curl -Lo bazelisk https://github.com/bazelbuild/bazelisk/releases/latest/download/bazelisk-linux-amd64
chmod +x bazelisk
sudo mv bazelisk /usr/local/bin/bazel
```

### Build with Bazel 9
```bash
# Use Bazel 9 explicitly
USE_BAZEL_VERSION=9.0.0 bazel build //...

# Or use bazelisk with Bazel 9
bazelisk build //...
```

### Module.bazel Example
```python
module(name="io_bazel_rules_hugo", version="0.1.0")

bazel_dep(name="rules_hugo", version="0.1.0")
```

## Migration from Earlier Bazel Versions

### From Bazel 6/7/8
1. No changes needed - fully compatible
2. Optional: Update to Bzlmod (already done)
3. Optional: Use Bazelisk for version management

### From Bazel 5 or earlier
1. Update to Bazel 6+ (required for Bzlmod)
2. Convert WORKSPACE to MODULE.bazel (already done)
3. Update deprecated function calls (already done)

## Testing

### Local Bazel 9 Testing
```bash
# Test with Bazel 9
docker run --rm -v $(pwd):/src -w /src gcr.io/bazel/bazel:latest bazel test //...

# Test with bazelisk
bazelisk --bazel_version=9.0.0 build //...
```

### CI/CD
- GitHub Actions supports Bazel 9
- Works with existing CI configurations
- No special CI changes needed

## Notes

- `http_archive` from `@bazel_tools//tools/build_defs/repo:http.bzl` continues to work in Bazel 9
- Full backward compatibility maintained
- No breaking changes introduced
- All existing functionality preserved