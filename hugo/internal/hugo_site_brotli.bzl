"""Helper rule for brotli compression of Hugo site files."""

load("//hugo/internal:hugo_site_info.bzl", "HugoSiteInfo")

def _brotli_hugo_site_impl(ctx):
    """Creates brotli-compressed versions of compressible files in a Hugo site.

    This rule makes it easy to create pre-compressed .br files for static serving
    with nginx's brotli_static module or similar.
    """
    site_info = ctx.attr.site[HugoSiteInfo]
    site_dir = site_info.output_dir

    # Output directory for brotli-compressed files
    output = ctx.actions.declare_directory(ctx.label.name)

    # Build file extensions pattern
    extensions = ctx.attr.extensions
    find_expr = " -o ".join(['-name "*.{}"'.format(ext) for ext in extensions])

    # Compression quality (0-11, where 11 is maximum)
    compression_quality = ctx.attr.compression_quality

    # Create the brotli script
    script_content = """#!/bin/bash
set -euo pipefail

SITE_DIR="{site_dir}"
OUTPUT_DIR="{output_dir}"

echo "Brotli compressing files from $SITE_DIR to $OUTPUT_DIR"

# Check if brotli is available
if ! command -v brotli >/dev/null 2>&1; then
    echo "ERROR: brotli command not found in PATH"
    echo "PATH: $PATH"
    exit 1
fi

# Create output directory structure and get absolute path
mkdir -p "$OUTPUT_DIR"
OUTPUT_ABS="$(cd "$OUTPUT_DIR" && pwd)"

# Find and compress matching files
cd "$SITE_DIR"

COMPRESSED=0
find -L . -type f \\( {find_expr} \\) | while read -r file; do
    # Create directory structure in output
    dirname="$(dirname "$file")"
    mkdir -p "$OUTPUT_ABS/$dirname"

    # Brotli compress the file
    brotli -q {compression_quality} -c "$file" > "$OUTPUT_ABS/$file.br"
    echo "Compressed: $file -> $file.br"
done

# Count results
TOTAL=$(find "$OUTPUT_ABS" -name "*.br" | wc -l)
echo "Created $TOTAL brotli-compressed files"
""".format(
        site_dir = site_dir.path,
        output_dir = output.path,
        find_expr = find_expr,
        compression_quality = compression_quality,
    )

    script = ctx.actions.declare_file(ctx.label.name + "_brotli.sh")
    ctx.actions.write(
        output = script,
        content = script_content,
        is_executable = True,
    )

    ctx.actions.run(
        inputs = [site_dir],
        outputs = [output],
        executable = script,
        mnemonic = "BrotliHugoSite",
        progress_message = "Brotli compressing Hugo site files",
    )

    return [
        DefaultInfo(files = depset([output])),
        OutputGroupInfo(
            brotli = depset([output]),
        ),
    ]

brotli_hugo_site = rule(
    doc = """
    Creates brotli-compressed versions of compressible files from a Hugo site.

    This rule processes a hugo_site output and creates .br versions of files
    matching the specified extensions. Brotli provides 15-25% better compression
    than gzip and is supported by all modern browsers.

    The output is a directory tree mirroring the site structure, containing
    only the .br files (e.g., styles.css becomes styles.css.br).

    Example:
        hugo_site(
            name = "site",
            config = "config.yaml",
            content = glob(["content/**"]),
        )

        brotli_hugo_site(
            name = "site_br",
            site = ":site",
            extensions = ["html", "css", "js", "xml", "txt", "json"],
            compression_quality = 11,
        )

        # Use both gzip and brotli for maximum compatibility
        gzip_hugo_site(
            name = "site_gz",
            site = ":site",
        )

        # Package both compression formats
        pkg_tar(
            name = "static_assets",
            srcs = [":site"],
            package_dir = "/usr/share/nginx/html",
        )

        pkg_tar(
            name = "static_assets_compressed",
            srcs = [":site_gz", ":site_br"],
            package_dir = "/usr/share/nginx/html",
        )

        # Combine in your container
        oci_image(
            name = "nginx_image",
            tars = [
                ":static_assets",
                ":static_assets_compressed",
            ],
        )
    """,
    implementation = _brotli_hugo_site_impl,
    attrs = {
        "site": attr.label(
            doc = "The hugo_site target to compress",
            providers = [HugoSiteInfo],
            mandatory = True,
        ),
        "extensions": attr.string_list(
            doc = """
            File extensions to compress (without the dot).
            Common values: html, css, js, xml, json, txt, svg, woff2
            """,
            default = ["html", "css", "js", "xml", "json", "txt", "svg"],
        ),
        "compression_quality": attr.int(
            doc = "Brotli compression quality (0-11, where 11 is maximum compression)",
            default = 11,
        ),
    },
)
