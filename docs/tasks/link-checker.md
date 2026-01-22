# Epic: Link Checker for Hugo Sites

## Overview

**Goal**: Provide automated link checking for Hugo site outputs to catch broken links pre-deployment and ensure content quality.

**Value Proposition**:
- Catch broken internal and external links before deployment
- Improve user experience by avoiding 404 errors
- Automated validation of content integrity
- CI/CD integration to prevent broken links from reaching production

**Success Metrics**:
- Rule successfully scans all HTML files for broken links
- Identifies internal and external link issues
- Integration test validates broken link detection
- Documentation with working example

**Target Effort**: 1 week (20-40 hours total)

---

## Story Breakdown

### Story 1: Core Link Checker Rule (1 week)

**Objective**: Create `link_checker_hugo_site` rule that processes Hugo site output and validates all links.

**Deliverables**:
- `hugo/internal/hugo_site_link_checker.bzl` implementation
- Python/Node.js processor script for link validation
- Basic integration test

---

## Atomic Tasks

### Task 1.1: Create Link Checker Rule Structure (4h) - LARGE

**Scope**: Create `link_checker_hugo_site` rule skeleton with link validation processor integration.

**Files** (5 files):
- `hugo/internal/hugo_site_link_checker.bzl` (create) - New rule implementation
- `hugo/internal/tools/link_checker/check.py` (create) - Python processor script
- `hugo/internal/tools/link_checker/BUILD.bazel` (create) - Export processor script
- `hugo/rules.bzl` (modify) - Add export for new rule
- `site_simple/BUILD.bazel` (modify) - Add example usage

**Context**:
- Study existing rules for pattern consistency
- Understand HugoSiteInfo provider usage
- Research link checking libraries and approaches
- Review HTTP client libraries for external link validation
- Understand HTML parsing and link extraction

**Implementation**:

```starlark
# hugo/internal/hugo_site_link_checker.bzl
load("//hugo/internal:hugo_site_info.bzl", "HugoSiteInfo")

def _link_checker_hugo_site_impl(ctx):
    """Checks all links in a Hugo site for broken references."""
    site_info = ctx.attr.site[HugoSiteInfo]
    site_dir = site_info.output_dir

    # Output directory for link check results
    output = ctx.actions.declare_file(ctx.label.name + "_report.txt")

    # Get the link checker processor script
    processor_script = ctx.file._processor

    # Create wrapper script that invokes the processor
    script_content = """#!/bin/bash
set -euo pipefail

SITE_DIR="{site_dir}"
OUTPUT_REPORT="{output_report}"
PROCESSOR="{processor}"

echo "Checking links in Hugo site"

# Check if python3 is available
if ! command -v python3 &> /dev/null; then
    echo "ERROR: Python 3 is required but not found in PATH"
    exit 1
fi

# Run the Python processor
python3 "$PROCESSOR" "$SITE_DIR" "$OUTPUT_REPORT"

echo "Link checking complete"
""".format(
        site_dir = site_dir.path,
        output_report = output.path,
        processor = processor_script.path,
    )

    script = ctx.actions.declare_file(ctx.label.name + "_check.sh")
    ctx.actions.write(
        output = script,
        content = script_content,
        is_executable = True,
    )

    ctx.actions.run(
        inputs = [site_dir, processor_script],
        outputs = [output],
        executable = script,
        mnemonic = "LinkCheckerHugoSite",
        progress_message = "Checking links in Hugo site",
    )

    return [
        DefaultInfo(files = depset([output])),
        OutputGroupInfo(
            report = depset([output]),
        ),
    ]

link_checker_hugo_site = rule(
    doc = """
    Checks all links in a Hugo site for broken references.

    This rule processes HTML files from a hugo_site output and:
    - Extracts all internal and external links
    - Validates internal links reference existing files
    - Checks external links for accessibility (optional)
    - Generates a detailed report of all issues found

    This helps prevent broken links from reaching production and improves
    user experience by catching issues early.

    **Requirements:**
    - Python 3 must be installed and available in PATH
    - Internet access for external link validation (optional)

    Example:
        hugo_site(
            name = "site",
            config = "config.yaml",
            content = glob(["content/**"]),
            static = glob(["static/**"]),
        )

        link_checker_hugo_site(
            name = "site_links_checked",
            site = ":site",
            check_external = True,
        )
    """,
    implementation = _link_checker_hugo_site_impl,
    attrs = {
        "site": attr.label(
            doc = "The hugo_site target to check",
            providers = [HugoSiteInfo],
            mandatory = True,
        ),
        "check_external": attr.bool(
            doc = "Whether to check external links (requires internet)",
            default = False,
        ),
        "timeout": attr.int(
            doc = "Timeout in seconds for external link checks",
            default = 30,
        ),
        "_processor": attr.label(
            default = "//hugo/internal/tools/link_checker:check.py",
            allow_single_file = True,
        ),
    },
)
```

**Success Criteria**:
- Rule builds without errors
- Creates output report file
- Accepts HugoSiteInfo provider input
- Returns DefaultInfo and OutputGroupInfo correctly
- Python integration works correctly

**Testing**:
```bash
cd /home/tstapler/Programming/rules_hugo
bazel build //site_simple:site_links_checked
cat bazel-bin/site_simple/site_links_checked_report.txt
```

**Dependencies**: None (first task)

**Status**: ⏳ Pending

---

### Task 1.2: Implement Link Checker Processor Script (4h) - LARGE

**Scope**: Create Python script for comprehensive link validation and reporting.

**Files** (2 files):
- `hugo/internal/tools/link_checker/check.py` (create) - Main processor script
- `hugo/internal/tools/link_checker/requirements.txt` (create) - Python dependencies

**Context**:
- Research HTML parsing libraries (BeautifulSoup, lxml)
- Implement HTTP client for external link validation
- Create comprehensive link extraction logic
- Handle various link types (internal, external, anchors, emails)

**Implementation**:

```python
#!/usr/bin/env python3
"""
Link checker for Hugo sites
Validates internal and external links in HTML files
"""

import os
import re
import sys
import argparse
import urllib.request
import urllib.error
import urllib.parse
from pathlib import Path
from typing import List, Tuple, Dict, Set
from dataclasses import dataclass
import time

try:
    from bs4 import BeautifulSoup
    import requests
except ImportError as e:
    print(f"ERROR: Missing required dependencies: {e}")
    print("Install with: pip install beautifulsoup4 requests")
    sys.exit(1)

@dataclass
class LinkIssue:
    """Represents a link validation issue"""
    file_path: str
    line_number: int
    link_type: str  # 'internal', 'external', 'anchor', 'email'
    url: str
    issue: str
    context: str = ""

class LinkChecker:
    def __init__(self, site_dir: str, check_external: bool = False, timeout: int = 30):
        self.site_dir = Path(site_dir)
        self.check_external = check_external
        self.timeout = timeout
        self.issues: List[LinkIssue] = []
        self.checked_urls: Dict[str, bool] = {}  # URL cache
        
    def check_site(self) -> List[LinkIssue]:
        """Check all links in the site"""
        print(f"Checking links in site: {self.site_dir}")
        
        # Find all HTML files
        html_files = list(self.site_dir.rglob("*.html"))
        print(f"Found {len(html_files)} HTML files")
        
        for html_file in html_files:
            self.check_file(html_file)
        
        return self.issues
    
    def check_file(self, html_file: Path):
        """Check links in a single HTML file"""
        try:
            with open(html_file, 'r', encoding='utf-8') as f:
                content = f.read()
            
            soup = BeautifulSoup(content, 'html.parser')
            
            # Check all links
            for tag in soup.find_all(['a', 'link', 'img', 'script', 'source']):
                href = tag.get('href') or tag.get('src')
                if href:
                    self.check_link(href, html_file, tag.name)
            
        except Exception as e:
            self.issues.append(LinkIssue(
                file_path=str(html_file),
                line_number=1,
                link_type='parse_error',
                url='',
                issue=f'Failed to parse file: {e}'
            ))
    
    def check_link(self, url: str, source_file: Path, tag_name: str):
        """Check a single link"""
        # Skip special URLs
        if url.startswith(('mailto:', 'tel:', 'javascript:', '#')):
            if url.startswith('#'):
                self.check_anchor(url, source_file, tag_name)
            return
        
        # Determine link type
        if url.startswith(('http://', 'https://')):
            link_type = 'external'
            if self.check_external:
                self.check_external_link(url, source_file, tag_name)
        else:
            link_type = 'internal'
            self.check_internal_link(url, source_file, tag_name)
    
    def check_internal_link(self, url: str, source_file: Path, tag_name: str):
        """Check an internal link"""
        # Remove fragment
        url_without_fragment = url.split('#')[0]
        
        # Resolve relative path
        if url_without_fragment.startswith('/'):
            target_path = self.site_dir / url_without_fragment.lstrip('/')
        else:
            target_path = source_file.parent / url_without_fragment
        
        # Normalize path
        target_path = target_path.resolve()
        
        # Check if file exists
        if not target_path.exists():
            # Try adding .html extension
            html_path = target_path.with_suffix('.html')
            if html_path.exists():
                return  # Valid with .html extension
            
            self.issues.append(LinkIssue(
                file_path=str(source_file),
                line_number=self.find_line_number(source_file, url),
                link_type='internal',
                url=url,
                issue=f'File not found: {target_path}'
            ))
    
    def check_external_link(self, url: str, source_file: Path, tag_name: str):
        """Check an external link"""
        if url in self.checked_urls:
            # Already checked
            if not self.checked_urls[url]:
                self.issues.append(LinkIssue(
                    file_path=str(source_file),
                    line_number=self.find_line_number(source_file, url),
                    link_type='external',
                    url=url,
                    issue='Previously failed URL'
                ))
            return
        
        try:
            # Make HEAD request first
            response = requests.head(url, timeout=self.timeout, allow_redirects=True)
            
            if response.status_code >= 400:
                # Try GET request as fallback
                response = requests.get(url, timeout=self.timeout, allow_redirects=True)
            
            if response.status_code >= 400:
                self.issues.append(LinkIssue(
                    file_path=str(source_file),
                    line_number=self.find_line_number(source_file, url),
                    link_type='external',
                    url=url,
                    issue=f'HTTP {response.status_code}: {response.reason}'
                ))
                self.checked_urls[url] = False
            else:
                self.checked_urls[url] = True
                
        except requests.exceptions.RequestException as e:
            self.issues.append(LinkIssue(
                file_path=str(source_file),
                line_number=self.find_line_number(source_file, url),
                link_type='external',
                url=url,
                issue=f'Request failed: {e}'
            ))
            self.checked_urls[url] = False
    
    def check_anchor(self, url: str, source_file: Path, tag_name: str):
        """Check an anchor link"""
        if url == '#':
            return  # Empty anchor is valid
        
        anchor = url[1:]  # Remove '#'
        
        try:
            with open(source_file, 'r', encoding='utf-8') as f:
                content = f.read()
            
            soup = BeautifulSoup(content, 'html.parser')
            
            # Look for id or name attributes
            if soup.find(id=anchor) or soup.find(attrs={'name': anchor}):
                return  # Found anchor
            
            self.issues.append(LinkIssue(
                file_path=str(source_file),
                line_number=self.find_line_number(source_file, url),
                link_type='anchor',
                url=url,
                issue=f'Anchor not found: {anchor}'
            ))
            
        except Exception as e:
            self.issues.append(LinkIssue(
                file_path=str(source_file),
                line_number=1,
                link_type='anchor',
                url=url,
                issue=f'Failed to check anchor: {e}'
            ))
    
    def find_line_number(self, file_path: Path, search_text: str) -> int:
        """Find line number of text in file"""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                for i, line in enumerate(f, 1):
                    if search_text in line:
                        return i
        except Exception:
            pass
        return 0
    
    def generate_report(self, output_file: Path):
        """Generate link check report"""
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write("Link Check Report\n")
            f.write("=================\n\n")
            
            if not self.issues:
                f.write("✅ No link issues found!\n")
            else:
                f.write(f"❌ Found {len(self.issues)} link issues:\n\n")
                
                # Group by file
                issues_by_file = {}
                for issue in self.issues:
                    file_path = issue.file_path
                    if file_path not in issues_by_file:
                        issues_by_file[file_path] = []
                    issues_by_file[file_path].append(issue)
                
                for file_path, file_issues in issues_by_file.items():
                    f.write(f"📄 {file_path}\n")
                    for issue in file_issues:
                        line_info = f":{issue.line_number}" if issue.line_number > 0 else ""
                        f.write(f"   {line_info} [{issue.link_type.upper()}] {issue.url}")
                        f.write(f" - {issue.issue}\n")
                    f.write("\n")
            
            f.write(f"\nSummary:\n")
            f.write(f"- Files checked: {len(list(self.site_dir.rglob('*.html')))}\n")
            f.write(f"- Issues found: {len(self.issues)}\n")
            
            if self.check_external:
                f.write(f"- External URLs checked: {len(self.checked_urls)}\n")

def main():
    parser = argparse.ArgumentParser(description='Check links in Hugo site')
    parser.add_argument('site_dir', help='Path to Hugo site directory')
    parser.add_argument('output_report', help='Path to output report file')
    parser.add_argument('--check-external', action='store_true', 
                       help='Check external links (requires internet)')
    parser.add_argument('--timeout', type=int, default=30,
                       help='Timeout for external link checks')
    
    args = parser.parse_args()
    
    checker = LinkChecker(
        site_dir=args.site_dir,
        check_external=args.check_external,
        timeout=args.timeout
    )
    
    issues = checker.check_site()
    checker.generate_report(Path(args.output_report))
    
    # Exit with error code if issues found
    if issues:
        print(f"❌ Found {len(issues)} link issues")
        sys.exit(1)
    else:
        print("✅ All links are valid")
        sys.exit(0)

if __name__ == '__main__':
    main()
```

**Success Criteria**:
- Script processes HTML files correctly
- Validates internal links against existing files
- Checks external links when enabled
- Generates comprehensive report with line numbers
- Handles edge cases gracefully

**Testing**:
```bash
cd /home/tstapler/Programming/rules_hugo
python3 hugo/internal/tools/link_checker/check.py test_site test_report.txt --check-external
```

**Dependencies**: Task 1.1 (requires rule structure)

**Status**: ⏳ Pending

---

### Task 1.3: Create Integration Test (3h) - MEDIUM

**Scope**: Create comprehensive integration test for link_checker_hugo_site rule.

**Files** (4 files):
- `test_integration/link_checker/BUILD.bazel` (create)
- `test_integration/link_checker/test_link_checker.sh` (create)
- `test_integration/link_checker/config.yaml` (create)
- `test_integration/link_checker/content/_index.md` (create) - with broken links
- `test_integration/link_checker/content/valid-page.md` (create)
- `test_integration/link_checker/content/broken-page.md` (create)

**Context**:
- Follow existing test patterns in test_integration/
- Create Hugo site with various link types (valid and broken)
- Verify internal and external link detection
- Verify report generation

**Implementation**:

```yaml
# test_integration/link_checker/config.yaml
baseURL: "https://example.com"
languageCode: "en-us"
title: "Link Checker Test Site"
```

```python
# test_integration/link_checker/BUILD.bazel
load("//hugo:rules.bzl", "hugo_site", "link_checker_hugo_site")

hugo_site(
    name = "test_site",
    config = "config.yaml",
    content = glob(["content/**"]),
    static = glob(["static/**"]),
)

link_checker_hugo_site(
    name = "test_site_links_checked",
    site = ":test_site",
    check_external = False,  # Disable external for CI reliability
)

sh_test(
    name = "test_link_checker",
    srcs = ["test_link_checker.sh"],
    data = [
        ":test_site",
        ":test_site_links_checked",
    ],
)
```

**Success Criteria**:
- Test builds and runs successfully
- Detects broken internal links
- Detects broken anchor links
- Generates valid report with line numbers
- Validates correct links pass checking

**Testing**:
```bash
bazel test //test_integration/link_checker:test_link_checker
```

**Dependencies**: Task 1.1, 1.2 (requires working rule and processor)

**Status**: ⏳ Pending

---

### Task 1.4: Update Documentation (1h) - MICRO

**Scope**: Add comprehensive documentation for link_checker_hugo_site rule.

**Files** (2 files):
- `docs/DOWNSTREAM_INTEGRATION.md` (modify) - Add link_checker_hugo_site section
- `README.md` (modify) - Add link checker to features list

**Context**:
- Follow existing documentation patterns in DOWNSTREAM_INTEGRATION.md
- Provide clear usage examples
- Explain different link types supported
- Note external link checking considerations

**Success Criteria**:
- Documentation is clear and accurate
- Examples are complete and buildable
- Link types and error handling are explained
- Follows existing documentation style

**Testing**: Manual review of documentation

**Dependencies**: Task 1.1 (requires rule to document)

**Status**: ⏳ Pending

---

## Dependency Visualization

```
Story 1: Core Link Checker Rule
├─ Task 1.1 (4h) Create Rule Structure
│   └─→ Task 1.2 (4h) Implement Python Processor
│        └─→ Task 1.3 (3h) Integration Test
│             └─→ Task 1.4 (1h) Documentation
```

**Total Sequential Path**: 12 hours

## Context Preparation

Before starting Task 1.1, review:
1. `/home/tstapler/Programming/rules_hugo/hugo/internal/hugo_site_info.bzl` - Provider definition
2. `/home/tstapler/Programming/rules_hugo/hugo/rules.bzl` - Export pattern
3. HTML parsing and link extraction techniques
4. HTTP client libraries for external validation

---

## Future Enhancements

After MVP is complete, consider:
1. **Parallel Checking**: Concurrent external link validation
2. **Link Exclusions**: Configure URLs to ignore (e.g., external domains)
3. **Caching**: Persist external link results between runs
4. **Custom Validators**: Plugin system for custom link types
5. **Performance Metrics**: Report check duration and statistics

---

## Known Issues

None yet - this is a new feature.

---

## Progress Tracking

**Epic Progress**: 0/4 tasks completed (0%)

**Story 1 Progress**: 0/4 tasks completed (0%)

**Tasks**:
- Completed: None
- In Progress: None
- Pending: Task 1.1, 1.2, 1.3, 1.4

**Next Action**: Start Task 1.1 - Create Link Checker Rule Structure