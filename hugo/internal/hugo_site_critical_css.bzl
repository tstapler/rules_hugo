"""Helper rule for extracting and inlining critical CSS in Hugo site output."""

load("//hugo/internal:hugo_site_info.bzl", "HugoSiteInfo")

def _critical_css_hugo_site_impl(ctx):
    """Extracts critical CSS and inlines it in HTML files.

    This rule processes HTML files from a Hugo site and:
    1. Extracts critical (above-the-fold) CSS
    2. Inlines it in <style> tags in the <head>
    3. Lazy-loads the remaining CSS
    4. Compresses the critical CSS

    This improves Core Web Vitals by eliminating render-blocking CSS.
    """
    site_info = ctx.attr.site[HugoSiteInfo]
    site_dir = site_info.output_dir

    # Output directory for site with critical CSS
    output = ctx.actions.declare_directory(ctx.label.name)

    # Get the Node.js processor script
    processor_script = ctx.file._processor

    # Simple wrapper script that runs the processor
    script_content = """#!/bin/bash
set -euo pipefail

SITE_DIR="{site_dir}"
OUTPUT_DIR="{output_dir}"
PROCESSOR="{processor}"

echo "Extracting critical CSS from Hugo site"

# Check if node is available
if ! command -v node &> /dev/null; then
    echo "ERROR: Node.js is required but not found in PATH"
    exit 1
fi

# Get absolute paths
SITE_ABS="$(cd "$SITE_DIR" && pwd)" || SITE_ABS="$SITE_DIR"
OUTPUT_ABS="$(mkdir -p "$OUTPUT_DIR" && cd "$OUTPUT_DIR" && pwd)"

# Run the processor directly (assumes node_modules is available)
timeout 30 node "$PROCESSOR" "$SITE_ABS" "$OUTPUT_ABS"
""".format(
        site_dir = site_dir.path,
        output_dir = output.path,
        processor = processor_script.path,
    )

    script = ctx.actions.declare_file(ctx.label.name + "_critical_css.sh")
    ctx.actions.write(
        output = script,
        content = script_content,
        is_executable = True,
    )

    # Run the script
    ctx.actions.run(
        inputs = [site_dir, processor_script],
        outputs = [output],
        executable = script,
        mnemonic = "CriticalCSS",
        progress_message = "Extracting critical CSS for Hugo site",
        use_default_shell_env = True,
        execution_requirements = {
            # Allow network access for Node.js (if needed)
            "no-sandbox": "1",
        },
    )

    return [
        DefaultInfo(files = depset([output])),
        OutputGroupInfo(
            critical_css = depset([output]),
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

        # Use in deployment
        pkg_tar(
            name = "optimized_site",
            srcs = [":site_critical"],
            package_dir = "/var/www/html",
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
