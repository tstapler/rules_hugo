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

    # Create inline minification script
    # Note: {{ and }} are escaped as {{{{ and }}}} in format strings
    script_content = """#!/bin/bash
set -euo pipefail

SITE_DIR="{site_dir}"
OUTPUT_DIR="{output_dir}"

echo "Minifying files from $SITE_DIR to $OUTPUT_DIR"

# Copy entire directory structure first, dereferencing symlinks
cp -rL "$SITE_DIR/." "$OUTPUT_DIR/"

# Minification functions
minify_html() {{
    local file="$1"
    sed -i -e 's/<!--[^>]*-->//g' \\
           -e 's/[[:space:]]\\+/ /g' \\
           -e 's/^[[:space:]]*//g' \\
           -e 's/[[:space:]]*$//g' \\
           -e '/^$/d' "$file"
}}

minify_css() {{
    local file="$1"
    # Remove CSS comments and extra whitespace
    sed -i -e 's|/\\*[^*]*\\*\\+\\([^/*][^*]*\\*\\+\\)*/||g' \\
           -e 's/^[[:space:]]*//g' \\
           -e 's/[[:space:]]*$//g' \\
           -e 's/[[:space:]]*:[[:space:]]*/:/g' \\
           -e 's/[[:space:]]*;[[:space:]]*/;/g' \\
           -e 's/[[:space:]]*,[[:space:]]*/, /g' \\
           -e '/^$/d' "$file"
}}

minify_js() {{
    local file="$1"
    sed -i -e 's|//.*$||g' \\
           -e 's|/\\*[^*]*\\*\\+\\([^/*][^*]*\\*\\+\\)*/||g' \\
           -e 's/^[[:space:]]*//g' \\
           -e 's/[[:space:]]*$//g' \\
           -e '/^$/d' "$file"
}}

minify_xml() {{
    local file="$1"
    sed -i -e 's/<!--[^>]*-->//g' \\
           -e 's/^[[:space:]]*//g' \\
           -e 's/[[:space:]]*$//g' \\
           -e '/^$/d' "$file"
}}

minify_json() {{
    local file="$1"
    if command -v jq >/dev/null 2>&1; then
        jq -c . "$file" > "$file.tmp" && mv "$file.tmp" "$file"
    else
        sed -i -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g' -e '/^$/d' "$file"
    fi
}}

# Process each extension
cd "$OUTPUT_DIR"
total_files=0

for ext in {extensions}; do
    find . -type f -name "*.$ext" | while read -r file; do
        case "$ext" in
            html|htm) minify_html "$file" ;;
            css) minify_css "$file" ;;
            js) minify_js "$file" ;;
            xml) minify_xml "$file" ;;
            json) minify_json "$file" ;;
        esac
        total_files=$((total_files + 1))
        echo "Minified: $file"
    done
done

echo "Minified $total_files files"
""".format(
        site_dir = site_dir.path,
        output_dir = output.path,
        extensions = " ".join(extensions),
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
