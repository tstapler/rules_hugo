"""Helper rule for purging unused CSS classes from Hugo site output."""

load("//hugo/internal:hugo_site_info.bzl", "HugoSiteInfo")

def _purgecss_hugo_site_impl(ctx):
    """Removes unused CSS classes from Hugo site stylesheets.

    This rule processes CSS files from a Hugo site and removes unused classes
    by analyzing the HTML content. This significantly reduces CSS bundle sizes
    while maintaining functionality.
    """
    site_info = ctx.attr.site[HugoSiteInfo]
    site_dir = site_info.output_dir

    # Output directory for purged CSS
    output = ctx.actions.declare_directory(ctx.label.name)

    # Get the purgecss processor script
    processor_script = ctx.file._processor

    # Build content glob pattern for scanning HTML files
    content_glob = ctx.attr.content_glob

    # Build options string
    options = []
    if ctx.attr.keyframes:
        options.append("--keyframes")
    if ctx.attr.font_face:
        options.append("--font-face")
    if ctx.attr.variables:
        options.append("--variables")

    options_str = " ".join(options)

    # Create wrapper script that invokes the processor
    script_content = """#!/bin/bash
set -euo pipefail

SITE_DIR="{site_dir}"
OUTPUT_DIR="{output_dir}"
PROCESSOR="{processor}"
CONTENT_GLOB="{content_glob}"
OPTIONS="{options}"

echo "Purging unused CSS from Hugo site"

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

# Get absolute paths
SITE_ABS="$(cd "$SITE_DIR" && pwd)" || SITE_ABS="$SITE_DIR"
OUTPUT_ABS="$(mkdir -p "$OUTPUT_DIR" && cd "$OUTPUT_DIR" && pwd)"

# Run the processor directly (assumes node_modules is available)
timeout 120 node "$PROCESSOR" "$SITE_ABS" "$OUTPUT_ABS" "$CONTENT_GLOB" $OPTIONS
""".format(
        site_dir = site_dir.path,
        output_dir = output.path,
        processor = processor_script.path,
        content_glob = content_glob,
        options = options_str,
    )

    script = ctx.actions.declare_file(ctx.label.name + "_purgecss.sh")
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
        mnemonic = "PurgeCSS",
        progress_message = "Purging unused CSS from Hugo site",
        use_default_shell_env = True,
        execution_requirements = {
            "no-sandbox": "1",
        },
    )

    return [
        DefaultInfo(files = depset([output])),
        OutputGroupInfo(
            purged = depset([output]),
        ),
    ]

purgecss_hugo_site = rule(
    doc = """
    Removes unused CSS classes from Hugo site stylesheets.

    This rule analyzes HTML content in the Hugo site and removes unused CSS
    classes from stylesheets, significantly reducing bundle sizes while
    maintaining functionality.

    The rule scans the specified content files to determine which CSS classes
    are actually used, then removes any unused classes from the CSS files.

    **Usage Examples:**

    Basic usage:
    ```python
    hugo_site(
        name = "site",
        config = "config.yaml",
        content = glob(["content/**"]),
        static = glob(["static/**"]),
    )

    purgecss_hugo_site(
        name = "site_purged",
        site = ":site",
        content_glob = "**/*.html",  # Scan all HTML files
    )
    ```

    Advanced configuration:
    ```python
    purgecss_hugo_site(
        name = "site_optimized",
        site = ":site",
        content_glob = "**/*.{html,js}",  # Scan HTML and JS files
        keyframes = True,                 # Keep unused keyframes
        font_face = True,                 # Keep unused @font-face rules
        variables = True,                 # Keep unused CSS variables
    )
    ```

    **Integration with other rules:**
    ```python
    # Recommended order: purge -> minify -> compress
    purgecss_hugo_site(
        name = "site_purged",
        site = ":site",
    )

    minify_hugo_site(
        name = "site_minified",
        site = ":site_purged",
    )

    gzip_hugo_site(
        name = "site_compressed",
        site = ":site_minified",
    )
    ```

    **Configuration Options:**
    - `content_glob`: Glob pattern for files to scan for CSS class usage
    - `keyframes`: Preserve unused CSS keyframes
    - `font_face`: Preserve unused @font-face declarations
    - `variables`: Preserve unused CSS custom properties

    **Requirements:**
    - Node.js 18+ must be installed and available in PATH
    - This is a temporary limitation; future versions will be fully hermetic

    **Expected Results:**
    - CSS file sizes reduced by 20-60% (depending on usage)
    - Unused classes, keyframes, and other CSS rules removed
    - HTML and other files copied unchanged
    """,
    implementation = _purgecss_hugo_site_impl,
    attrs = {
        "site": attr.label(
            doc = "The hugo_site target to process",
            providers = [HugoSiteInfo],
            mandatory = True,
        ),
        "content_glob": attr.string(
            doc = """
            Glob pattern for files to scan for CSS class usage.
            Examples: "**/*.html", "**/*.{html,js}", "public/**/*.html"
            """,
            default = "**/*.html",
        ),
        "keyframes": attr.bool(
            doc = "Preserve unused CSS keyframes (@keyframes rules)",
            default = False,
        ),
        "font_face": attr.bool(
            doc = "Preserve unused @font-face declarations",
            default = False,
        ),
        "variables": attr.bool(
            doc = "Preserve unused CSS custom properties (CSS variables)",
            default = False,
        ),
        "_processor": attr.label(
            default = "//hugo/internal/tools/purgecss:process.js",
            allow_single_file = True,
        ),
    },
)