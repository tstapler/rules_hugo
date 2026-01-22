# Epic: Accessibility Checker for Hugo Sites

## Overview

**Goal**: Provide automated accessibility testing for Hugo site outputs to ensure WCAG compliance and identify accessibility barriers.

**Value Proposition**:
- Ensure WCAG 2.1 AA compliance for accessibility standards
- Identify accessibility barriers before they affect users
- Automated validation as part of CI/CD pipeline
- Support for inclusive design and legal compliance

**Success Metrics**:
- Rule successfully tests all HTML files for WCAG compliance
- Identifies accessibility violations and provides remediation suggestions
- Integration test validates violation detection and reporting
- Documentation with working example

**Target Effort**: 1 week (20-40 hours total)

---

## Story Breakdown

### Story 1: Core Accessibility Checker Rule (1 week)

**Objective**: Create `accessibility_checker_hugo_site` rule that processes Hugo site output and validates accessibility compliance.

**Deliverables**:
- `hugo/internal/hugo_site_accessibility_checker.bzl` implementation
- Python/Node.js processor script using accessibility testing libraries
- Basic integration test

---

## Atomic Tasks

### Task 1.1: Create Accessibility Checker Rule Structure (4h) - LARGE

**Scope**: Create `accessibility_checker_hugo_site` rule skeleton with accessibility testing processor integration.

**Files** (5 files):
- `hugo/internal/hugo_site_accessibility_checker.bzl` (create) - New rule implementation
- `hugo/internal/tools/accessibility_checker/check.py` (create) - Python processor script
- `hugo/internal/tools/accessibility_checker/BUILD.bazel` (create) - Export processor script
- `hugo/rules.bzl` (modify) - Add export for new rule
- `site_simple/BUILD.bazel` (modify) - Add example usage

**Context**:
- Study existing rules for pattern consistency
- Understand HugoSiteInfo provider usage
- Research accessibility testing libraries (axe-core, pa11y, accessibility-inspector)
- Review WCAG 2.1 guidelines and success criteria
- Understand accessibility violation categories and severity levels

**Implementation**:

```starlark
# hugo/internal/hugo_site_accessibility_checker.bzl
load("//hugo/internal:hugo_site_info.bzl", "HugoSiteInfo")

def _accessibility_checker_hugo_site_impl(ctx):
    """Tests accessibility compliance in a Hugo site for WCAG standards."""
    site_info = ctx.attr.site[HugoSiteInfo]
    site_dir = site_info.output_dir

    # Output directory for accessibility test results
    output_report = ctx.actions.declare_file(ctx.label.name + "_report.txt")
    output_json = ctx.actions.declare_file(ctx.label.name + "_results.json")
    output_sarif = ctx.actions.declare_file(ctx.label.name + "_sarif.json")

    # Get the accessibility checker processor script
    processor_script = ctx.file._processor

    # Create wrapper script that invokes the processor
    script_content = """#!/bin/bash
set -euo pipefail

SITE_DIR="{site_dir}"
OUTPUT_REPORT="{output_report}"
OUTPUT_JSON="{output_json}"
OUTPUT_SARIF="{output_sarif}"
PROCESSOR="{processor}"
WCAG_LEVEL="{wcag_level}"
BROWSER_ENGINE="{browser_engine}"

echo "Testing accessibility in Hugo site"

# Check if node is available (for axe-core)
if ! command -v node &> /dev/null; then
    echo "ERROR: Node.js is required but not found in PATH"
    exit 1
fi

# Check Node.js version
NODE_VERSION=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 18 ]; then
    echo "ERROR: Node.js 18+ is required (found v$NODE_VERSION)"
    exit 1
fi

# Run the processor
node "$PROCESSOR" "$SITE_DIR" "$OUTPUT_REPORT" "$OUTPUT_JSON" "$OUTPUT_SARIF" --wcag-level "$WCAG_LEVEL" --browser "$BROWSER_ENGINE"

echo "Accessibility testing complete"
""".format(
        site_dir = site_dir.path,
        output_report = output_report.path,
        output_json = output_json.path,
        output_sarif = output_sarif.path,
        processor = processor_script.path,
        wcag_level = ctx.attr.wcag_level,
        browser_engine = ctx.attr.browser_engine,
    )

    script = ctx.actions.declare_file(ctx.label.name + "_a11y_test.sh")
    ctx.actions.write(
        output = script,
        content = script_content,
        is_executable = True,
    )

    ctx.actions.run(
        inputs = [site_dir, processor_script],
        outputs = [output_report, output_json, output_sarif],
        executable = script,
        mnemonic = "AccessibilityCheckerHugoSite",
        progress_message = "Testing accessibility in Hugo site",
    )

    return [
        DefaultInfo(files = depset([output_report, output_json, output_sarif])),
        OutputGroupInfo(
            report = depset([output_report]),
            results = depset([output_json]),
            sarif = depset([output_sarif]),
        ),
    ]

accessibility_checker_hugo_site = rule(
    doc = """
    Tests accessibility compliance in a Hugo site for WCAG standards.

    This rule processes HTML files from a hugo_site output and:
    - Tests against WCAG 2.1 guidelines (AA level by default)
    - Identifies accessibility violations and their severity
    - Provides remediation suggestions and best practices
    - Generates reports in multiple formats (text, JSON, SARIF)

    This helps ensure web accessibility compliance and inclusive design
    for users with disabilities.

    **Requirements:**
    - Node.js 18+ must be installed and available in PATH
    - Automated browser engine (Puppeteer/Playwright support)

    Example:
        hugo_site(
            name = "site",
            config = "config.yaml",
            content = glob(["content/**"]),
            static = glob(["static/**"]),
        )

        accessibility_checker_hugo_site(
            name = "site_a11y_tested",
            site = ":site",
            wcag_level = "AA",
            browser_engine = "chromium",
        )
    """,
    implementation = _accessibility_checker_hugo_site_impl,
    attrs = {
        "site": attr.label(
            doc = "The hugo_site target to test",
            providers = [HugoSiteInfo],
            mandatory = True,
        ),
        "wcag_level": attr.string(
            doc = "WCAG compliance level (A, AA, or AAA)",
            default = "AA",
            values = ["A", "AA", "AAA"],
        ),
        "browser_engine": attr.string(
            doc = "Browser engine for testing (chromium, firefox, webkit)",
            default = "chromium",
            values = ["chromium", "firefox", "webkit"],
        ),
        "include_best_practices": attr.bool(
            doc = "Include accessibility best practices beyond WCAG",
            default = True,
        ),
        "_processor": attr.label(
            default = "//hugo/internal/tools/accessibility_checker:check.js",
            allow_single_file = True,
        ),
    },
)
```

**Success Criteria**:
- Rule builds without errors
- Creates output report, JSON, and SARIF files
- Accepts HugoSiteInfo provider input
- Returns DefaultInfo and OutputGroupInfo correctly
- Node.js integration works correctly

**Testing**:
```bash
cd /home/tstapler/Programming/rules_hugo
bazel build //site_simple:site_a11y_tested
cat bazel-bin/site_simple/site_a11y_tested_report.txt
```

**Dependencies**: None (first task)

**Status**: ⏳ Pending

---

### Task 1.2: Implement Accessibility Checker Processor Script (4h) - LARGE

**Scope**: Create Node.js script for comprehensive accessibility testing using axe-core.

**Files** (2 files):
- `hugo/internal/tools/accessibility_checker/check.js` (create) - Main processor script
- `hugo/internal/tools/accessibility_checker/package.json` (create) - Node.js dependencies

**Context**:
- Research axe-core library for accessibility testing
- Implement automated browser testing with Puppeteer
- Create comprehensive WCAG violation detection
- Handle various accessibility categories and severity levels

**Implementation**:

```javascript
#!/usr/bin/env node
/**
 * Accessibility checker for Hugo sites
 * Tests HTML files for WCAG compliance using axe-core
 */

const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');
const AxeBuilder = require('@axe-core/cli');
const chalk = require('chalk');

// Parse command line arguments
const args = process.argv.slice(2);
if (args.length < 4) {
  console.error('Usage: check.js <input_dir> <output_report> <output_json> <output_sarif> [options]');
  process.exit(1);
}

const inputDir = args[0];
const outputReport = args[1];
const outputJson = args[2];
const outputSarif = args[3];
const wcagLevel = args.includes('--wcag-level') ? args[args.indexOf('--wcag-level') + 1] : 'AA';
const browserEngine = args.includes('--browser') ? args[args.indexOf('--browser') + 1] : 'chromium';
const includeBestPractices = args.includes('--best-practices');

class AccessibilityChecker {
  constructor(wcagLevel, browserEngine, includeBestPractices) {
    this.wcagLevel = wcagLevel;
    this.browserEngine = browserEngine;
    this.includeBestPractices = includeBestPractices;
    this.results = [];
    this.filesProcessed = [];
  }

  async checkSite() {
    console.log(`Testing accessibility for site: ${inputDir}`);
    console.log(`WCAG Level: ${this.wcagLevel}`);
    console.log(`Browser Engine: ${this.browserEngine}`);

    // Find all HTML files
    const htmlFiles = this.findHTMLFiles(inputDir);
    console.log(`Found ${htmlFiles.length} HTML files to test`);

    let totalViolations = 0;
    let totalPasses = 0;
    let totalIncomplete = 0;

    for (const htmlFile of htmlFiles) {
      try {
        console.log(`Testing: ${path.relative(inputDir, htmlFile)}`);
        
        const result = await this.checkFile(htmlFile);
        
        totalViolations += result.violations.length;
        totalPasses += result.passes.length;
        totalIncomplete += result.incomplete.length;
        
        this.results.push({
          file: htmlFile,
          relativePath: path.relative(inputDir, htmlFile),
          ...result
        });
        
        this.filesProcessed.push(htmlFile);
        
      } catch (error) {
        console.error(`Error testing ${htmlFile}:`, error.message);
        this.results.push({
          file: htmlFile,
          relativePath: path.relative(inputDir, htmlFile),
          error: error.message,
          violations: [],
          passes: [],
          incomplete: []
        });
      }
    }

    // Generate reports
    this.generateTextReport(totalViolations, totalPasses, totalIncomplete);
    this.generateJsonReport();
    this.generateSarifReport();

    console.log(`\nAccessibility testing complete:`);
    console.log(`- Files tested: ${this.filesProcessed.length}`);
    console.log(`- Violations: ${totalViolations}`);
    console.log(`- Passes: ${totalPasses}`);
    console.log(`- Incomplete: ${totalIncomplete}`);

    return totalViolations;
  }

  findHTMLFiles(dir, fileList = []) {
    const files = fs.readdirSync(dir);

    files.forEach(file => {
      const filePath = path.join(dir, file);
      const stat = fs.statSync(filePath);

      if (stat.isDirectory()) {
        this.findHTMLFiles(filePath, fileList);
      } else if (file.endsWith('.html')) {
        fileList.push(filePath);
      }
    });

    return fileList;
  }

  async checkFile(htmlFile) {
    const htmlContent = fs.readFileSync(htmlFile, 'utf8');
    const axe = new AxeBuilder({
      source: htmlContent,
      reporter: 'v2'
    });

    // Configure WCAG level
    const tags = [`wcag2${this.wcagLevel.toLowerCase()}`];
    if (this.includeBestPractices) {
      tags.push('best-practice');
    }
    
    axe.withTags(tags);

    // Run axe-core analysis
    const result = await axe.analyze();
    
    return {
      violations: this.processViolations(result.violations),
      passes: this.processPasses(result.passes),
      incomplete: this.processIncomplete(result.incomplete),
      testEngine: {
        name: 'axe-core',
        version: require('@axe-core/cli/package.json').dependencies['axe-core']
      }
    };
  }

  processViolations(violations) {
    return violations.map(violation => ({
      id: violation.id,
      impact: violation.impact,
      tags: violation.tags,
      description: violation.description,
      help: violation.help,
      helpUrl: violation.helpUrl,
      nodes: violation.nodes.map(node => ({
        html: node.html,
        target: node.target,
        failureSummary: node.failureSummary,
        impact: node.impact,
        any: node.any,
        all: node.all,
        none: node.none
      }))
    }));
  }

  processPasses(passes) {
    return passes.map(pass => ({
      id: pass.id,
      description: pass.description,
      impact: 'pass',
      nodes: pass.nodes.map(node => ({
        html: node.html,
        target: node.target,
        any: node.any,
        all: node.all,
        none: node.none
      }))
    }));
  }

  processIncomplete(incomplete) {
    return incomplete.map(item => ({
      id: item.id,
      description: item.description,
      impact: 'incomplete',
      nodes: item.nodes.map(node => ({
        html: node.html,
        target: node.target,
        reason: node.reason,
        any: node.any,
        all: node.all,
        none: node.none
      }))
    }));
  }

  generateTextReport(totalViolations, totalPasses, totalIncomplete) {
    const lines = [];
    
    lines.push('Accessibility Testing Report');
    lines.push('============================');
    lines.push('');
    lines.push(`WCAG Level: ${this.wcagLevel}`);
    lines.push(`Browser Engine: ${this.browserEngine}`);
    lines.push(`Test Engine: axe-core`);
    lines.push('');
    
    lines.push('Summary:');
    lines.push(`- Files tested: ${this.filesProcessed.length}`);
    lines.push(`- Violations: ${totalViolations}`);
    lines.push(`- Passes: ${totalPasses}`);
    lines.push(`- Incomplete (needs manual review): ${totalIncomplete}`);
    lines.push('');

    if (totalViolations === 0) {
      lines.push('✅ No accessibility violations found!');
    } else {
      lines.push(`❌ Found ${totalViolations} accessibility violations:\n`);

      // Group violations by file
      const violationsByFile = {};
      for (const result of this.results) {
        if (result.violations && result.violations.length > 0) {
          violationsByFile[result.relativePath] = result.violations;
        }
      }

      for (const [filePath, violations] of Object.entries(violationsByFile)) {
        lines.push(`📄 ${filePath}`);
        for (const violation of violations) {
          const impactIcon = {
            'critical': '🚨',
            'serious': '⚠️',
            'moderate': '⚡',
            'minor': '💡'
          }[violation.impact] || '❓';
          
          lines.push(`   ${impactIcon} [${violation.impact.toUpperCase()}] ${violation.description}`);
          lines.push(`   💡 Help: ${violation.help}`);
          lines.push(`   🔗 Learn more: ${violation.helpUrl}`);
          
          // Show affected elements
          for (const node of violation.nodes) {
            for (const target of node.target) {
              lines.push(`       Target: ${target}`);
            }
            lines.push(`       HTML: ${node.html.substring(0, 100)}...`);
          }
          lines.push('');
        }
        lines.push('');
      }
    }

    // Include incomplete items
    if (totalIncomplete > 0) {
      lines.push('Items Requiring Manual Review:');
      const incompleteByFile = {};
      for (const result of this.results) {
        if (result.incomplete && result.incomplete.length > 0) {
          incompleteByFile[result.relativePath] = result.incomplete;
        }
      }

      for (const [filePath, incomplete] of Object.entries(incompleteByFile)) {
        lines.push(`📄 ${filePath}`);
        for (const item of incomplete) {
          lines.push(`   🔍 [MANUAL REVIEW] ${item.description}`);
          for (const node of item.nodes) {
            for (const target of node.target) {
              lines.push(`       Target: ${target}`);
            }
          }
        }
        lines.push('');
      }
    }

    fs.writeFileSync(outputReport, lines.join('\n'), 'utf8');
  }

  generateJsonReport() {
    const reportData = {
      metadata: {
        wcagLevel: this.wcagLevel,
        browserEngine: this.browserEngine,
        testEngine: 'axe-core',
        timestamp: new Date().toISOString(),
        totalFiles: this.filesProcessed.length
      },
      summary: {
        totalViolations: this.results.reduce((sum, r) => sum + (r.violations?.length || 0), 0),
        totalPasses: this.results.reduce((sum, r) => sum + (r.passes?.length || 0), 0),
        totalIncomplete: this.results.reduce((sum, r) => sum + (r.incomplete?.length || 0), 0)
      },
      results: this.results.map(result => ({
        file: result.relativePath,
        violations: result.violations || [],
        passes: result.passes || [],
        incomplete: result.incomplete || [],
        error: result.error || null
      }))
    };

    fs.writeFileSync(outputJson, JSON.stringify(reportData, null, 2), 'utf8');
  }

  generateSarifReport() {
    const sarifData = {
      $schema: 'https://json.schemastore.org/sarif-2.1.0',
      version: '2.1.0',
      runs: [{
        tool: {
          driver: {
            name: 'axe-core',
            version: require('@axe-core/cli/package.json').dependencies['axe-core'],
            informationUri: 'https://github.com/dequelabs/axe-core',
            rules: []
          }
        },
        results: [],
        automationDetails: {
          id: 'accessibility-check'
        }
      }]
    };

    // Collect all unique rules from violations
    const rules = new Map();
    for (const result of this.results) {
      if (result.violations) {
        for (const violation of result.violations) {
          if (!rules.has(violation.id)) {
            rules.set(violation.id, {
              id: violation.id,
              name: violation.id,
              shortDescription: { text: violation.description },
              fullDescription: { text: violation.help },
              helpUri: violation.helpUrl,
              defaultConfiguration: { level: violation.impact === 'critical' ? 'error' : 'warning' }
            });
          }
        }
      }
    }

    sarifData.runs[0].tool.driver.rules = Array.from(rules.values());

    // Add results
    for (const result of this.results) {
      if (result.violations) {
        for (const violation of result.violations) {
          for (const node of violation.nodes) {
            for (const target of node.target) {
              sarifData.runs[0].results.push({
                ruleId: violation.id,
                level: violation.impact === 'critical' ? 'error' : 'warning',
                message: { text: violation.description },
                locations: [{
                  physicalLocation: {
                    artifactLocation: { uri: result.relativePath },
                    region: {
                      snippet: { text: node.html }
                    }
                  }
                }],
                properties: {
                  impact: violation.impact,
                  wcagTags: violation.tags.filter(tag => tag.startsWith('wcag'))
                }
              });
            }
          }
        }
      }
    }

    fs.writeFileSync(outputSarif, JSON.stringify(sarifData, null, 2), 'utf8');
  }
}

// Run the accessibility checker
async function main() {
  const startTime = Date.now();
  
  try {
    const checker = new AccessibilityChecker(wcagLevel, browserEngine, includeBestPractices);
    const violations = await checker.checkSite();
    
    const duration = Date.now() - startTime;
    console.log(`Testing completed in ${duration}ms`);
    
    // Exit with error code if violations found
    if (violations > 0) {
      process.exit(1);
    } else {
      process.exit(0);
    }
  } catch (error) {
    console.error('Fatal error during accessibility testing:', error);
    process.exit(2);
  }
}

main();
```

**Success Criteria**:
- Script tests HTML files for WCAG compliance
- Detects accessibility violations with proper categorization
- Generates reports in text, JSON, and SARIF formats
- Supports different WCAG levels and browser engines
- Provides actionable remediation suggestions

**Testing**:
```bash
cd /home/tstapler/Programming/rules_hugo
node hugo/internal/tools/accessibility_checker/check.js test_site report.txt results.json sarif.json --wcag-level AA
```

**Dependencies**: Task 1.1 (requires rule structure)

**Status**: ⏳ Pending

---

### Task 1.3: Create Integration Test (3h) - MEDIUM

**Scope**: Create comprehensive integration test for accessibility_checker_hugo_site rule.

**Files** (4 files):
- `test_integration/accessibility_checker/BUILD.bazel` (create)
- `test_integration/accessibility_checker/test_accessibility_checker.sh` (create)
- `test_integration/accessibility_checker/config.yaml` (create)
- `test_integration/accessibility_checker/content/_index.md` (create) - with accessibility issues
- `test_integration/accessibility_checker/content/accessible-page.md` (create)
- `test_integration/accessibility_checker/content/inaccessible-page.md` (create)

**Context**:
- Follow existing test patterns in test_integration/
- Create Hugo site with various accessibility issues (missing alt text, no headings, etc.)
- Verify violation detection and reporting
- Test different WCAG levels

**Implementation**:

```yaml
# test_integration/accessibility_checker/config.yaml
baseURL: "https://example.com"
languageCode: "en-us"
title: "Accessibility Checker Test Site"
```

```python
# test_integration/accessibility_checker/BUILD.bazel
load("//hugo:rules.bzl", "hugo_site", "accessibility_checker_hugo_site")

hugo_site(
    name = "test_site",
    config = "config.yaml",
    content = glob(["content/**"]),
    static = glob(["static/**"]),
)

accessibility_checker_hugo_site(
    name = "test_site_a11y_tested",
    site = ":test_site",
    wcag_level = "AA",
    browser_engine = "chromium",
)

sh_test(
    name = "test_accessibility_checker",
    srcs = ["test_accessibility_checker.sh"],
    data = [
        ":test_site",
        ":test_site_a11y_tested",
    ],
)
```

**Success Criteria**:
- Test builds and runs successfully
- Detects accessibility violations
- Generates reports in all formats
- Validates accessible content passes tests
- Tests different WCAG levels appropriately

**Testing**:
```bash
bazel test //test_integration/accessibility_checker:test_accessibility_checker
```

**Dependencies**: Task 1.1, 1.2 (requires working rule and processor)

**Status**: ⏳ Pending

---

### Task 1.4: Update Documentation (1h) - MICRO

**Scope**: Add comprehensive documentation for accessibility_checker_hugo_site rule.

**Files** (2 files):
- `docs/DOWNSTREAM_INTEGRATION.md` (modify) - Add accessibility_checker_hugo_site section
- `README.md` (modify) - Add accessibility checker to features list

**Context**:
- Follow existing documentation patterns in DOWNSTREAM_INTEGRATION.md
- Provide clear usage examples
- Explain WCAG levels and violation types
- Note accessibility features and limitations

**Success Criteria**:
- Documentation is clear and accurate
- Examples are complete and buildable
- WCAG compliance features are explained
- Follows existing documentation style

**Testing**: Manual review of documentation

**Dependencies**: Task 1.1 (requires rule to document)

**Status**: ⏳ Pending

---

## Dependency Visualization

```
Story 1: Core Accessibility Checker Rule
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
3. WCAG 2.1 guidelines and success criteria
4. axe-core library documentation and capabilities

---

## Future Enhancements

After MVP is complete, consider:
1. **Screen Reader Testing**: Integration with screen reader simulators
2. **Color Contrast Analysis**: Advanced color contrast ratio validation
3. **Keyboard Navigation**: Automated keyboard navigation testing
4. **Voice Control**: Testing for voice command compatibility
5. **Performance Impact**: Monitor accessibility testing performance

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

**Next Action**: Start Task 1.1 - Create Accessibility Checker Rule Structure