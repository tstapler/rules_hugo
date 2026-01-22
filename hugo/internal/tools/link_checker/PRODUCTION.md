# Hugo Link Checker - Production Setup Guide

This guide explains how to properly set up the Hugo link checker for production use, including Python dependency management.

## Quick Start

The link checker is CI-friendly by default and will work for internal link checking without any additional setup:

```python
load("@build_stack_rules_hugo//hugo:rules.bzl", "hugo_site", "link_checker_hugo_site")

hugo_site(
    name = "my_site",
    config = "config.yaml",
    content = glob(["content/**"]),
    static = glob(["static/**"]),
)

# CI-friendly - only checks internal links
link_checker_hugo_site(
    name = "my_site_links_checked",
    site = ":my_site",
    check_external = False,  # Default, no network dependency
)
```

## Python Dependencies

The link checker requires two Python packages:
- `beautifulsoup4>=4.9.0` - HTML parsing
- `requests>=2.25.0` - HTTP requests (for external links)

### Option 1: Manual Installation (Recommended for CI)

Install dependencies manually in your environment:

```bash
pip install beautifulsoup4 requests
```

Or using the requirements file:

```bash
pip install -r hugo/internal/tools/link_checker/requirements.txt
```

### Option 2: Virtual Environment

For isolated environments:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r hugo/internal/tools/link_checker/requirements.txt
```

### Option 3: System Package Manager

Some systems provide these packages:

```bash
# Ubuntu/Debian
sudo apt-get install python3-bs4 python3-requests

# macOS with Homebrew
brew install python3
pip3 install beautifulsoup4 requests
```

## CI/CD Integration

### GitHub Actions

```yaml
name: Check Links
on: [push, pull_request]

jobs:
  link-check:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Install Bazel
      uses: bazelbuild/setup-bazelisk@v2
    
    - name: Install Python dependencies
      run: pip install beautifulsoup4 requests
    
    - name: Check links
      run: bazel build //path/to:site_links_checked
    
    - name: Upload link report
      uses: actions/upload-artifact@v3
      if: always()
      with:
        name: link-report
        path: bazel-bin/**/*_report.txt
```

### Jenkins

```groovy
pipeline {
    agent any
    
    stages {
        stage('Setup') {
            steps {
                sh 'pip install beautifulsoup4 requests'
            }
        }
        
        stage('Build Site') {
            steps {
                sh 'bazel build //path/to:my_site'
            }
        }
        
        stage('Check Links') {
            steps {
                sh 'bazel build //path/to:my_site_links_checked'
            }
            
            post {
                always {
                    archiveArtifacts artifacts: 'bazel-bin/**/*_report.txt', allowEmptyArchive: true
                }
            }
        }
    }
}
```

## External Link Checking

External link checking is **disabled by default** for CI safety. To enable it:

```python
link_checker_hugo_site(
    name = "my_site_full_check",
    site = ":my_site",
    check_external = True,   # Requires internet access
    timeout = 30,            # Timeout per request in seconds
)
```

### External Link Considerations

1. **Network Access**: Ensure your CI environment has internet access
2. **Time**: External checking significantly increases execution time
3. **Reliability**: External sites may be temporarily down
4. **Rate Limiting**: Some sites may block automated requests

### Recommendations

- **CI/PR Checks**: Use `check_external = False` (default)
- **Nightly Builds**: Use `check_external = True` for comprehensive checks
- **Local Development**: Enable external links when debugging issues

## Error Handling

The link checker provides graceful error handling:

### Missing Python Dependencies

If Python packages are missing, the rule will fail with clear instructions:

```
ERROR: Python 3 is required but not found in PATH
To install Python dependencies, use:
  pip install -r hugo/internal/tools/link_checker/requirements.txt
```

### Configuration Errors

Exit code 2 indicates configuration or setup issues.

### Link Issues Found

Exit code 1 indicates links were found broken but the tool worked correctly. Reports are still generated.

## Report Format

The link checker generates detailed Markdown reports:

- **File-by-file breakdown** of issues
- **Line numbers** for easy location
- **URL and context** for each issue
- **Issue type** (internal, external, anchor)
- **Human-readable error descriptions**

Example:
```
## index.html

### Line 15 - INTERNAL

**URL:** `missing-page.html`

**Issue:** Target file not found

**Context:** `<a href="missing-page.html">Broken Link</a>`
```

## Performance Tuning

### Timeout Configuration

```python
link_checker_hugo_site(
    name = "my_site_links",
    site = ":my_site",
    check_external = True,
    timeout = 5,    # 5 seconds per request (default: 30)
)
```

### Large Sites

For sites with many pages:
- Consider splitting checks by section
- Use longer timeouts for reliable external checking
- Run external checks in separate pipelines

## Troubleshooting

### Common Issues

1. **"No HTML files found"**
   - Check that the Hugo site built successfully
   - Verify the site output directory contains HTML files

2. **"Permission denied"**
   - Ensure the script has execute permissions
   - Check file system permissions for output directories

3. **"Network timeout"**
   - Increase timeout value
   - Check network connectivity
   - Consider disabling external links in CI

4. **"ModuleNotFoundError"**
   - Install Python dependencies
   - Check Python version compatibility

### Debug Mode

Run the link checker directly for debugging:

```bash
# Direct execution with verbose output
python3 hugo/internal/tools/link_checker/check.py public/ report.txt

# Check external links
python3 hugo/internal/tools/link_checker/check.py public/ report.txt --check-external

# Custom timeout
python3 hugo/internal/tools/link_checker/check.py public/ report.txt --timeout 5
```

## Best Practices

1. **Always run link checker in CI** with external checking disabled
2. **Enable external links** in scheduled builds or pre-release checks
3. **Archive link reports** as build artifacts for analysis
4. **Monitor link checker performance** for large sites
5. **Configure appropriate timeouts** based on your external link profile
6. **Use proper error handling** to distinguish between tool failures and actual link issues

## Integration Examples

### Makefile Integration

```makefile
.PHONY: check-links check-links-full

check-links:
	bazel build //site:site_links_checked

check-links-full:
	bazel build //site:site_links_full

report:
	@echo "Link Report:"
	@cat bazel-bin/**/*_report.txt | head -50
```

### Docker Integration

```dockerfile
FROM python:3.11-slim

# Install dependencies
RUN pip install beautifulsoup4 requests

# Install Bazel
COPY . /app
WORKDIR /app
RUN bazel build //site:site_links_checked

CMD ["cat", "bazel-bin/**/*_report.txt"]
```