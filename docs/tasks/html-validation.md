# Epic: HTML Validation for Hugo Sites

## Overview

**Goal**: Provide automated HTML validation for Hugo site outputs to ensure HTML5 compliance and catch markup errors pre-deployment.

**Value Proposition**:
- Ensure HTML5 compliance and web standards adherence
- Catch markup errors that could affect rendering or SEO
- Automated validation as part of CI/CD pipeline
- Early detection of template or content issues

**Success Metrics**:
- Rule successfully validates all HTML files against HTML5 schema
- Identifies markup errors, accessibility issues, and best practice violations
- Integration test validates error detection and reporting
- Documentation with working example

**Target Effort**: 3 days (15-24 hours total)

---

## Story Breakdown

### Story 1: Core HTML Validation Rule (3 days)

**Objective**: Create `html_validator_hugo_site` rule that processes Hugo site output and validates HTML markup.

**Deliverables**:
- `hugo/internal/hugo_site_html_validator.bzl` implementation
- Python/Node.js processor script using HTML validation libraries
- Basic integration test

---

## Atomic Tasks

### Task 1.1: Create HTML Validator Rule Structure (3h) - MEDIUM

**Scope**: Create `html_validator_hugo_site` rule skeleton with HTML validation processor integration.

**Files** (5 files):
- `hugo/internal/hugo_site_html_validator.bzl` (create) - New rule implementation
- `hugo/internal/tools/html_validator/validate.py` (create) - Python processor script
- `hugo/internal/tools/html_validator/BUILD.bazel` (create) - Export processor script
- `hugo/rules.bzl` (modify) - Add export for new rule
- `site_simple/BUILD.bazel` (modify) - Add example usage

**Context**:
- Study existing rules for pattern consistency
- Understand HugoSiteInfo provider usage
- Research HTML validation libraries (html5lib, lxml, vnu.jar)
- Review HTML5 validation standards and best practices
- Understand error reporting and severity levels

**Implementation**:

```starlark
# hugo/internal/hugo_site_html_validator.bzl
load("//hugo/internal:hugo_site_info.bzl", "HugoSiteInfo")

def _html_validator_hugo_site_impl(ctx):
    """Validates HTML markup in a Hugo site for HTML5 compliance."""
    site_info = ctx.attr.site[HugoSiteInfo]
    site_dir = site_info.output_dir

    # Output directory for validation results
    output_report = ctx.actions.declare_file(ctx.label.name + "_report.txt")
    output_json = ctx.actions.declare_file(ctx.label.name + "_results.json")

    # Get the HTML validator processor script
    processor_script = ctx.file._processor

    # Create wrapper script that invokes the processor
    script_content = """#!/bin/bash
set -euo pipefail

SITE_DIR="{site_dir}"
OUTPUT_REPORT="{output_report}"
OUTPUT_JSON="{output_json}"
PROCESSOR="{processor}"

echo "Validating HTML in Hugo site"

# Check if python3 is available
if ! command -v python3 &> /dev/null; then
    echo "ERROR: Python 3 is required but not found in PATH"
    exit 1
fi

# Run the Python processor
python3 "$PROCESSOR" "$SITE_DIR" "$OUTPUT_REPORT" "$OUTPUT_JSON"

echo "HTML validation complete"
""".format(
        site_dir = site_dir.path,
        output_report = output_report.path,
        output_json = output_json.path,
        processor = processor_script.path,
    )

    script = ctx.actions.declare_file(ctx.label.name + "_validate.sh")
    ctx.actions.write(
        output = script,
        content = script_content,
        is_executable = True,
    )

    ctx.actions.run(
        inputs = [site_dir, processor_script],
        outputs = [output_report, output_json],
        executable = script,
        mnemonic = "HTMLValidatorHugoSite",
        progress_message = "Validating HTML in Hugo site",
    )

    return [
        DefaultInfo(files = depset([output_report, output_json])),
        OutputGroupInfo(
            report = depset([output_report]),
            results = depset([output_json]),
        ),
    ]

html_validator_hugo_site = rule(
    doc = """
    Validates HTML markup in a Hugo site for HTML5 compliance.

    This rule processes HTML files from a hugo_site output and:
    - Validates against HTML5 schema and web standards
    - Detects markup errors and structural issues
    - Reports accessibility violations and best practice issues
    - Generates detailed reports with line numbers and suggestions

    This helps ensure high-quality HTML markup that renders correctly
    across browsers and meets web standards.

    **Requirements:**
    - Python 3 must be installed and available in PATH

    Example:
        hugo_site(
            name = "site",
            config = "config.yaml",
            content = glob(["content/**"]),
            static = glob(["static/**"]),
        )

        html_validator_hugo_site(
            name = "site_validated",
            site = ":site",
            strict_mode = False,
            check_accessibility = True,
        )
    """,
    implementation = _html_validator_hugo_site_impl,
    attrs = {
        "site": attr.label(
            doc = "The hugo_site target to validate",
            providers = [HugoSiteInfo],
            mandatory = True,
        ),
        "strict_mode": attr.bool(
            doc = "Enable strict validation (fail on warnings)",
            default = False,
        ),
        "check_accessibility": attr.bool(
            doc = "Include accessibility checks",
            default = True,
        ),
        "ignore_patterns": attr.string_list(
            doc = "URL patterns to ignore during validation",
            default = [],
        ),
        "_processor": attr.label(
            default = "//hugo/internal/tools/html_validator:validate.py",
            allow_single_file = True,
        ),
    },
)
```

**Success Criteria**:
- Rule builds without errors
- Creates output report and JSON files
- Accepts HugoSiteInfo provider input
- Returns DefaultInfo and OutputGroupInfo correctly
- Python integration works correctly

**Testing**:
```bash
cd /home/tstapler/Programming/rules_hugo
bazel build //site_simple:site_validated
cat bazel-bin/site_simple/site_validated_report.txt
```

**Dependencies**: None (first task)

**Status**: ⏳ Pending

---

### Task 1.2: Implement HTML Validator Processor Script (4h) - LARGE

**Scope**: Create Python script for comprehensive HTML validation using industry-standard libraries.

**Files** (2 files):
- `hugo/internal/tools/html_validator/validate.py` (create) - Main processor script
- `hugo/internal/tools/html_validator/requirements.txt` (create) - Python dependencies

**Context**:
- Research HTML validation libraries (html5lib, lxml, vnu.jar)
- Implement validation against HTML5 schema
- Create comprehensive error categorization
- Handle various HTML standards and best practices

**Implementation**:

```python
#!/usr/bin/env python3
"""
HTML validator for Hugo sites
Validates HTML markup for HTML5 compliance and web standards
"""

import os
import sys
import json
import argparse
from pathlib import Path
from typing import List, Dict, Any, Optional
from dataclasses import dataclass, asdict
import re

try:
    from html5lib import parse, treebuilders
    from html5lib.constants import namespaces
    import lxml.etree as etree
except ImportError as e:
    print(f"ERROR: Missing required dependencies: {e}")
    print("Install with: pip install html5lib lxml")
    sys.exit(1)

@dataclass
class ValidationError:
    """Represents an HTML validation error"""
    file_path: str
    line_number: int
    column_number: int
    error_type: str  # 'error', 'warning', 'info'
    message: str
    context: str = ""
    suggestion: str = ""

@dataclass
class ValidationResults:
    """Container for validation results"""
    total_files: int
    total_errors: int
    total_warnings: int
    total_info: int
    errors: List[ValidationError]
    files_processed: List[str]
    validation_time: float

class HTMLValidator:
    def __init__(self, strict_mode: bool = False, check_accessibility: bool = True, 
                 ignore_patterns: List[str] = None):
        self.strict_mode = strict_mode
        self.check_accessibility = check_accessibility
        self.ignore_patterns = ignore_patterns or []
        self.results: List[ValidationError] = []
        self.files_processed: List[str] = []
        
        # HTML5 doctype and basic structure checks
        self.required_elements = [
            {'tag': '!DOCTYPE', 'pattern': r'<!DOCTYPE\s+html>', 'message': 'Missing or invalid DOCTYPE'},
            {'tag': 'html', 'attributes': {'lang': 'required'}, 'message': 'Missing lang attribute on html element'},
            {'tag': 'head', 'required': True, 'message': 'Missing head element'},
            {'tag': 'title', 'required': True, 'message': 'Missing title element in head'},
            {'tag': 'meta', 'attributes': {'charset': 'utf-8'}, 'message': 'Missing charset meta tag'},
            {'tag': 'meta', 'attributes': {'name': 'viewport', 'content': 'width=device-width, initial-scale=1'}, 
             'message': 'Missing viewport meta tag for responsive design'},
        ]
        
        # Accessibility checks
        self.accessibility_checks = [
            {'tag': 'img', 'attribute': 'alt', 'message': 'Missing alt attribute on img element'},
            {'tag': 'a', 'attribute': 'aria-label', 'condition': lambda attrs: not attrs.get('href') or attrs.get('href') == '#',
             'message': 'Link without meaningful href should have aria-label'},
            {'tag': 'button', 'attribute': 'type', 'message': 'Button should have type attribute'},
            {'tag': 'input', 'attribute': 'aria-label', 'condition': lambda attrs: attrs.get('type') not in ['hidden', 'submit'],
             'message': 'Input should have aria-label or associated label'},
        ]
    
    def should_ignore_file(self, file_path: Path) -> bool:
        """Check if file should be ignored based on patterns"""
        file_str = str(file_path)
        for pattern in self.ignore_patterns:
            if re.search(pattern, file_str):
                return True
        return False
    
    def validate_site(self, site_dir: Path) -> ValidationResults:
        """Validate all HTML files in the site"""
        import time
        start_time = time.time()
        
        print(f"Validating HTML in site: {site_dir}")
        
        # Find all HTML files
        html_files = [f for f in site_dir.rglob("*.html") if not self.should_ignore_file(f)]
        print(f"Found {len(html_files)} HTML files to validate")
        
        for html_file in html_files:
            self.validate_file(html_file)
        
        validation_time = time.time() - start_time
        
        # Count errors by type
        total_errors = len([e for e in self.results if e.error_type == 'error'])
        total_warnings = len([e for e in self.results if e.error_type == 'warning'])
        total_info = len([e for e in self.results if e.error_type == 'info'])
        
        return ValidationResults(
            total_files=len(html_files),
            total_errors=total_errors,
            total_warnings=total_warnings,
            total_info=total_info,
            errors=self.results,
            files_processed=self.files_processed,
            validation_time=validation_time
        )
    
    def validate_file(self, html_file: Path):
        """Validate a single HTML file"""
        try:
            with open(html_file, 'r', encoding='utf-8') as f:
                content = f.read()
            
            print(f"Validating: {html_file.relative_to(html_file.parent.parent)}")
            self.files_processed.append(str(html_file))
            
            # Basic structure validation
            self.validate_basic_structure(content, html_file)
            
            # Parse with html5lib for more detailed validation
            try:
                document = parse(content, treebuilder="lxml")
                self.validate_html5_compliance(document, html_file)
                
                if self.check_accessibility:
                    self.validate_accessibility(document, html_file)
                    
            except Exception as e:
                self.add_error(
                    file_path=str(html_file),
                    line_number=1,
                    column_number=1,
                    error_type='error',
                    message=f'HTML parsing failed: {e}',
                    context='File parsing'
                )
            
        except Exception as e:
            self.add_error(
                file_path=str(html_file),
                line_number=1,
                column_number=1,
                error_type='error',
                message=f'Failed to read file: {e}',
                context='File reading'
            )
    
    def validate_basic_structure(self, content: str, html_file: Path):
        """Validate basic HTML structure requirements"""
        lines = content.split('\n')
        
        for check in self.required_elements:
            found = False
            line_num = 1
            col_num = 1
            
            if check['tag'] == '!DOCTYPE':
                # Check DOCTYPE at beginning
                if not re.search(check['pattern'], content, re.IGNORECASE | re.MULTILINE):
                    self.add_error(
                        file_path=str(html_file),
                        line_number=1,
                        column_number=1,
                        error_type='error',
                        message=check['message'],
                        context='Document structure'
                    )
            else:
                # Check for required elements
                for i, line in enumerate(lines):
                    match = re.search(f'<{check["tag"]}', line, re.IGNORECASE)
                    if match:
                        found = True
                        line_num = i + 1
                        col_num = match.start() + 1
                        
                        # Check required attributes
                        if 'attributes' in check:
                            tag_content = self.extract_tag_content(line)
                            for attr, requirement in check['attributes'].items():
                                if requirement == 'required' and attr not in tag_content:
                                    self.add_error(
                                        file_path=str(html_file),
                                        line_number=line_num,
                                        column_number=col_num,
                                        error_type='error',
                                        message=f'{check["message"]} (missing {attr})',
                                        context=f'<{check["tag"]}> element'
                                    )
                        break
                
                if check.get('required', False) and not found:
                    self.add_error(
                        file_path=str(html_file),
                        line_number=1,
                        column_number=1,
                        error_type='error',
                        message=check['message'],
                        context='Document structure'
                    )
    
    def validate_html5_compliance(self, document, html_file: Path):
        """Validate HTML5 compliance using html5lib"""
        try:
            # Get the root element
            root = document
            
            # Check for deprecated elements and attributes
            deprecated_elements = ['font', 'center', 'marquee', 'blink', 'frame', 'frameset']
            deprecated_attrs = ['align', 'bgcolor', 'border', 'cellpadding', 'cellspacing']
            
            for elem in root.iter():
                if elem.tag in deprecated_elements:
                    self.add_error(
                        file_path=str(html_file),
                        line_number=getattr(elem, 'sourceline', 1),
                        column_number=getattr(elem, 'sourcepos', 1),
                        error_type='warning',
                        message=f'Deprecated HTML element: <{elem.tag}>',
                        context=f'<{elem.tag}>',
                        suggestion='Use modern CSS alternatives'
                    )
                
                if hasattr(elem, 'attrib'):
                    for attr in deprecated_attrs:
                        if attr in elem.attrib:
                            self.add_error(
                                file_path=str(html_file),
                                line_number=getattr(elem, 'sourceline', 1),
                                column_number=getattr(elem, 'sourcepos', 1),
                                error_type='warning',
                                message=f'Deprecated attribute: {attr} on <{elem.tag}>',
                                context=f'<{elem.tag} {attr}="...">',
                                suggestion='Use CSS instead'
                            )
        
        except Exception as e:
            self.add_error(
                file_path=str(html_file),
                line_number=1,
                column_number=1,
                error_type='warning',
                message=f'HTML5 compliance check failed: {e}',
                context='Validation'
            )
    
    def validate_accessibility(self, document, html_file: Path):
        """Validate accessibility requirements"""
        try:
            for elem in document.iter():
                if not hasattr(elem, 'tag') or not hasattr(elem, 'attrib'):
                    continue
                    
                tag = elem.tag
                attrs = dict(elem.attrib) if hasattr(elem, 'attrib') else {}
                
                for check in self.accessibility_checks:
                    if check['tag'] == tag:
                        should_check = True
                        
                        # Check condition if provided
                        if 'condition' in check:
                            should_check = check['condition'](attrs)
                        
                        if should_check and check['attribute'] not in attrs:
                            error_type = 'error' if self.strict_mode else 'warning'
                            self.add_error(
                                file_path=str(html_file),
                                line_number=getattr(elem, 'sourceline', 1),
                                column_number=getattr(elem, 'sourcepos', 1),
                                error_type=error_type,
                                message=check['message'],
                                context=f'<{tag}> element',
                                suggestion=f'Add {check["attribute"]} attribute'
                            )
        
        except Exception as e:
            self.add_error(
                file_path=str(html_file),
                line_number=1,
                column_number=1,
                error_type='warning',
                message=f'Accessibility check failed: {e}',
                context='Validation'
            )
    
    def extract_tag_content(self, line: str) -> str:
        """Extract tag content including attributes from a line"""
        # Simple regex to get tag content
        match = re.search(r'<(\w+)([^>]*?)>', line)
        if match:
            return match.group(2)
        return ''
    
    def add_error(self, file_path: str, line_number: int, column_number: int, 
                  error_type: str, message: str, context: str = "", suggestion: str = ""):
        """Add a validation error"""
        error = ValidationError(
            file_path=file_path,
            line_number=line_number,
            column_number=column_number,
            error_type=error_type,
            message=message,
            context=context,
            suggestion=suggestion
        )
        self.results.append(error)
    
    def generate_report(self, results: ValidationResults, output_file: Path):
        """Generate text validation report"""
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write("HTML Validation Report\n")
            f.write("======================\n\n")
            
            f.write(f"Validation Summary:\n")
            f.write(f"- Files processed: {results.total_files}\n")
            f.write(f"- Errors: {results.total_errors}\n")
            f.write(f"- Warnings: {results.total_warnings}\n")
            f.write(f"- Info: {results.total_info}\n")
            f.write(f"- Validation time: {results.validation_time:.2f}s\n\n")
            
            if not results.errors:
                f.write("✅ No validation issues found!\n")
            else:
                # Group by file
                errors_by_file = {}
                for error in results.errors:
                    file_path = error.file_path
                    if file_path not in errors_by_file:
                        errors_by_file[file_path] = []
                    errors_by_file[file_path].append(error)
                
                for file_path, file_errors in errors_by_file.items():
                    f.write(f"📄 {file_path}\n")
                    for error in file_errors:
                        location = f"{error.line_number}:{error.column_number}" if error.line_number > 0 else "1:1"
                        icon = "❌" if error.error_type == 'error' else "⚠️" if error.error_type == 'warning' else "ℹ️"
                        f.write(f"   {location} {icon} [{error.error_type.upper()}] {error.message}")
                        if error.context:
                            f.write(f" (Context: {error.context})")
                        if error.suggestion:
                            f.write(f"\n       💡 Suggestion: {error.suggestion}")
                        f.write("\n")
                    f.write("\n")
    
    def generate_json_report(self, results: ValidationResults, output_file: Path):
        """Generate JSON validation report"""
        with open(output_file, 'w', encoding='utf-8') as f:
            report_data = {
                'summary': {
                    'total_files': results.total_files,
                    'total_errors': results.total_errors,
                    'total_warnings': results.total_warnings,
                    'total_info': results.total_info,
                    'validation_time': results.validation_time
                },
                'files_processed': results.files_processed,
                'errors': [asdict(error) for error in results.errors]
            }
            json.dump(report_data, f, indent=2, ensure_ascii=False)

def main():
    parser = argparse.ArgumentParser(description='Validate HTML in Hugo site')
    parser.add_argument('site_dir', help='Path to Hugo site directory')
    parser.add_argument('output_report', help='Path to output text report file')
    parser.add_argument('output_json', help='Path to output JSON report file')
    parser.add_argument('--strict', action='store_true', help='Enable strict mode (fail on warnings)')
    parser.add_argument('--no-accessibility', action='store_true', help='Disable accessibility checks')
    parser.add_argument('--ignore', action='append', help='URL patterns to ignore')
    
    args = parser.parse_args()
    
    validator = HTMLValidator(
        strict_mode=args.strict,
        check_accessibility=not args.no_accessibility,
        ignore_patterns=args.ignore or []
    )
    
    results = validator.validate_site(Path(args.site_dir))
    validator.generate_report(results, Path(args.output_report))
    validator.generate_json_report(results, Path(args.output_json))
    
    # Exit with error code if errors found
    if results.total_errors > 0 or (validator.strict_mode and results.total_warnings > 0):
        print(f"❌ Found {results.total_errors} errors and {results.total_warnings} warnings")
        sys.exit(1)
    else:
        print("✅ HTML validation passed")
        sys.exit(0)

if __name__ == '__main__':
    main()
```

**Success Criteria**:
- Script validates HTML files against HTML5 standards
- Detects structural errors and missing required elements
- Identifies deprecated elements and attributes
- Generates detailed reports with line numbers
- Supports accessibility checks

**Testing**:
```bash
cd /home/tstapler/Programming/rules_hugo
python3 hugo/internal/tools/html_validator/validate.py test_site report.txt results.json
```

**Dependencies**: Task 1.1 (requires rule structure)

**Status**: ⏳ Pending

---

### Task 1.3: Create Integration Test (3h) - MEDIUM

**Scope**: Create comprehensive integration test for html_validator_hugo_site rule.

**Files** (4 files):
- `test_integration/html_validation/BUILD.bazel` (create)
- `test_integration/html_validation/test_html_validation.sh` (create)
- `test_integration/html_validation/config.yaml` (create)
- `test_integration/html_validation/content/_index.md` (create) - with HTML errors
- `test_integration/html_validation/content/valid-page.md` (create)
- `test_integration/html_validation/content/invalid-page.md` (create)

**Context**:
- Follow existing test patterns in test_integration/
- Create Hugo site with various HTML issues (missing DOCTYPE, deprecated elements, etc.)
- Verify error detection and reporting
- Test strict vs non-strict modes

**Implementation**:

```yaml
# test_integration/html_validation/config.yaml
baseURL: "https://example.com"
languageCode: "en-us"
title: "HTML Validation Test Site"
```

```python
# test_integration/html_validation/BUILD.bazel
load("//hugo:rules.bzl", "hugo_site", "html_validator_hugo_site")

hugo_site(
    name = "test_site",
    config = "config.yaml",
    content = glob(["content/**"]),
    static = glob(["static/**"]),
)

html_validator_hugo_site(
    name = "test_site_validated",
    site = ":test_site",
    strict_mode = False,
    check_accessibility = True,
)

sh_test(
    name = "test_html_validation",
    srcs = ["test_html_validation.sh"],
    data = [
        ":test_site",
        ":test_site_validated",
    ],
)
```

**Success Criteria**:
- Test builds and runs successfully
- Detects HTML structural errors
- Identifies deprecated elements and attributes
- Generates valid reports with line numbers
- Validates correct HTML passes validation

**Testing**:
```bash
bazel test //test_integration/html_validation:test_html_validation
```

**Dependencies**: Task 1.1, 1.2 (requires working rule and processor)

**Status**: ⏳ Pending

---

### Task 1.4: Update Documentation (1h) - MICRO

**Scope**: Add comprehensive documentation for html_validator_hugo_site rule.

**Files** (2 files):
- `docs/DOWNSTREAM_INTEGRATION.md` (modify) - Add html_validator_hugo_site section
- `README.md` (modify) - Add HTML validation to features list

**Context**:
- Follow existing documentation patterns in DOWNSTREAM_INTEGRATION.md
- Provide clear usage examples
- Explain validation types and error levels
- Note accessibility features

**Success Criteria**:
- Documentation is clear and accurate
- Examples are complete and buildable
- Validation features are explained
- Follows existing documentation style

**Testing**: Manual review of documentation

**Dependencies**: Task 1.1 (requires rule to document)

**Status**: ⏳ Pending

---

## Dependency Visualization

```
Story 1: Core HTML Validation Rule
├─ Task 1.1 (3h) Create Rule Structure
│   └─→ Task 1.2 (4h) Implement Python Processor
│        └─→ Task 1.3 (3h) Integration Test
│             └─→ Task 1.4 (1h) Documentation
```

**Total Sequential Path**: 11 hours

## Context Preparation

Before starting Task 1.1, review:
1. `/home/tstapler/Programming/rules_hugo/hugo/internal/hugo_site_info.bzl` - Provider definition
2. `/home/tstapler/Programming/rules_hugo/hugo/rules.bzl` - Export pattern
3. HTML5 validation standards and best practices
4. Accessibility guidelines and validation techniques

---

## Future Enhancements

After MVP is complete, consider:
1. **Schema Validation**: Validate against specific HTML schemas
2. **Performance Metrics**: Report validation time and complexity
3. **Custom Rules**: Plugin system for custom validation rules
4. **HTML Tidy Integration**: Use HTML Tidy for additional checks
5. **Continuous Integration**: GitHub Actions integration with PR checks

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

**Next Action**: Start Task 1.1 - Create HTML Validator Rule Structure