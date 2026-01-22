load("//hugo/internal:hugo_site_info.bzl", "HugoSiteInfo")

def _link_checker_hugo_site_impl(ctx):
    """Checks all links in a Hugo site for broken references."""
    site_info = ctx.attr.site[HugoSiteInfo]
    site_dir = site_info.output_dir

    # Output directory for link check results
    output = ctx.actions.declare_file(ctx.label.name + "_report.txt")

    # Get link checker processor script
    processor_script = ctx.file._processor

    # Create wrapper script that invokes processor
    script_content = """#!/bin/bash
set -euo pipefail

SITE_DIR="{site_dir}"
OUTPUT_REPORT="{output_report}"
PROCESSOR="{processor}"
CHECK_EXTERNAL={check_external}
TIMEOUT={timeout}

echo "Checking links in Hugo site (external links: $CHECK_EXTERNAL)"

# Check if python3 is available
if ! command -v python3 &> /dev/null; then
    echo "ERROR: Python 3 is required but not found in PATH"
    echo "To install Python dependencies, use:"
    echo "  pip install -r hugo/internal/tools/link_checker/requirements.txt"
    echo "Or use the Bazel target: //hugo/internal/tools/link_checker:check"
    exit 1
fi

# Run the link checker, capturing exit status
EXIT_CODE=0
if [ "$CHECK_EXTERNAL" = "True" ]; then
    echo "Note: External link checking enabled - requires internet access"
    python3 "$PROCESSOR" "$SITE_DIR" "$OUTPUT_REPORT" --check-external --timeout "$TIMEOUT" || EXIT_CODE=$?
else
    echo "Note: External link checking disabled (CI-friendly default)"
    python3 "$PROCESSOR" "$SITE_DIR" "$OUTPUT_REPORT" --timeout "$TIMEOUT" || EXIT_CODE=$?
fi

# Check for specific error conditions
if [ $EXIT_CODE -eq 2 ]; then
    echo "ERROR: Link checker failed with configuration error"
    echo "Check that Python dependencies are installed:"
    echo "  pip install beautifulsoup4 requests"
    exit 1
elif [ $EXIT_CODE -eq 1 ] && [ ! -f "$OUTPUT_REPORT" ]; then
    echo "ERROR: Link checker failed and no report was generated"
    exit 1
elif [ $EXIT_CODE -ne 0 ] && [ -f "$OUTPUT_REPORT" ]; then
    echo "WARNING: Link checker found issues (exit code $EXIT_CODE)"
    echo "Report generated at: $OUTPUT_REPORT"
elif [ $EXIT_CODE -eq 0 ]; then
    echo "✅ Link checking completed successfully"
fi

echo "Link checking complete - report available at: $OUTPUT_REPORT"
""".format(
        site_dir = site_dir.path,
        output_report = output.path,
        processor = processor_script.path,
        check_external = str(ctx.attr.check_external),
        timeout = ctx.attr.timeout,
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
    - Python packages: beautifulsoup4, requests (install with pip)
    - Internet access for external link validation (optional, disabled by default)

    **CI/CD Usage:**
    The rule is CI-friendly by default:
    - External link checking is disabled (check_external = False)
    - Only internal links are validated (no network dependencies)
    - Reports are generated even when issues are found
    - Graceful error handling for missing dependencies

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
            doc = "Whether to check external links (requires internet). Default is False for CI safety.",
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