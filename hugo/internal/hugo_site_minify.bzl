"""Helper rule for minifying Hugo site files."""

load("//hugo:internal/hugo_site_info.bzl", "HugoSiteInfo")

def _minify_hugo_site_impl(ctx):
    """Minifies compressible text files in a Hugo site.

    This rule makes it easy to reduce file sizes for production deployments
    by removing unnecessary whitespace and comments from HTML, CSS, JS, XML, and JSON files.
    """
    site_info = ctx.attr.site[HugoSiteInfo]
    site_dir = site_info.output_dir

    # Output directory for minified files
    output = ctx.actions.declare_directory(ctx.label.name)

    # Build file extensions pattern
    extensions = ctx.attr.extensions
    find_expr = " -o ".join(['-name "*.{}"'.format(ext) for ext in extensions])

    # Create the minification script
    # NOTE: Task 1.1 creates skeleton only - full minification logic comes in Task 1.2
    script_content = """#!/bin/bash
set -euo pipefail

SITE_DIR="{site_dir}"
OUTPUT_DIR="{output_dir}"

echo "Minifying files from $SITE_DIR to $OUTPUT_DIR"

# Create output directory structure
mkdir -p "$OUTPUT_DIR"

# Copy entire directory structure first (Task 1.1: skeleton)
# Task 1.2 will add actual minification logic
cp -r "$SITE_DIR/." "$OUTPUT_DIR/"

# Find matching files for processing
cd "$SITE_DIR"
TOTAL=0
find . -type f \\( {find_expr} \\) | while read -r file; do
    echo "Found for minification: $file"
    TOTAL=$((TOTAL + 1))
done

echo "Ready to minify $TOTAL files (minification logic in Task 1.2)"
""".format(
        site_dir = site_dir.path,
        output_dir = output.path,
        find_expr = find_expr,
    )

    script = ctx.actions.declare_file(ctx.label.name + "_minify.sh")
    ctx.actions.write(
        output = script,
        content = script_content,
        is_executable = True,
    )

    ctx.actions.run(
        inputs = [site_dir],
        outputs = [output],
        executable = script,
        mnemonic = "MinifyHugoSite",
        progress_message = "Minifying Hugo site files",
    )

    return [
        DefaultInfo(files = depset([output])),
        OutputGroupInfo(
            minified = depset([output]),
        ),
    ]

minify_hugo_site = rule(
    doc = """
    Minifies text files from a Hugo site to reduce file sizes for production.

    This rule processes a hugo_site output and creates minified versions of
    HTML, CSS, JavaScript, XML, and JSON files. The output is a complete
    directory tree with minified files replacing the originals.

    Minification removes unnecessary whitespace, comments, and formatting
    to reduce file sizes by 40-60% for CSS/JS and 10-30% for HTML.

    Example:
        hugo_site(
            name = "site",
            config = "config.yaml",
            content = glob(["content/**"]),
        )

        minify_hugo_site(
            name = "site_minified",
            site = ":site",
            extensions = ["html", "css", "js", "xml", "json"],
        )

        # Combine with gzip for maximum compression
        gzip_hugo_site(
            name = "site_compressed",
            site = ":site_minified",
        )

        # Use with pkg_tar for deployment
        pkg_tar(
            name = "static_assets",
            srcs = [":site_minified"],
            package_dir = "/usr/share/nginx/html",
        )
    """,
    implementation = _minify_hugo_site_impl,
    attrs = {
        "site": attr.label(
            doc = "The hugo_site target to minify",
            providers = [HugoSiteInfo],
            mandatory = True,
        ),
        "extensions": attr.string_list(
            doc = """
            File extensions to minify (without the dot).
            Common values: html, css, js, xml, json
            """,
            default = ["html", "css", "js", "xml", "json"],
        ),
    },
)
