"""Helper rule for gzipping Hugo site files."""

load("//hugo/internal:hugo_site_info.bzl", "HugoSiteInfo")

def _gzip_hugo_site_impl(ctx):
    """Creates gzipped versions of compressible files in a Hugo site.

    This rule makes it easy to create pre-compressed .gz files for static serving
    with nginx's gzip_static module or similar.
    """
    site_info = ctx.attr.site[HugoSiteInfo]
    site_dir = site_info.output_dir

    # Output directory for gzipped files
    output = ctx.actions.declare_directory(ctx.label.name)

    # Build file extensions pattern
    extensions = ctx.attr.extensions
    find_expr = " -o ".join(['-name "*.{}"'.format(ext) for ext in extensions])

    # Compression level
    compression_level = ctx.attr.compression_level

    # Create the gzip script
    script_content = """#!/bin/bash
set -euo pipefail

SITE_DIR="{site_dir}"
OUTPUT_DIR="{output_dir}"

echo "Gzipping files from $SITE_DIR to $OUTPUT_DIR"

# Create output directory structure
mkdir -p "$OUTPUT_DIR"

# Find and gzip matching files
cd "$SITE_DIR"
find . -type f \\( {find_expr} \\) | while read -r file; do
    # Create directory structure in output
    dirname="$(dirname "$file")"
    mkdir -p "$OUTPUT_DIR/$dirname"

    # Gzip the file
    gzip -{compression_level} -c "$file" > "$OUTPUT_DIR/$file.gz"
    echo "Compressed: $file -> $file.gz"
done

# Count results
TOTAL=$(find "$OUTPUT_DIR" -name "*.gz" | wc -l)
echo "Created $TOTAL gzipped files"
""".format(
        site_dir = site_dir.path,
        output_dir = output.path,
        find_expr = find_expr,
        compression_level = compression_level,
    )

    script = ctx.actions.declare_file(ctx.label.name + "_gzip.sh")
    ctx.actions.write(
        output = script,
        content = script_content,
        is_executable = True,
    )

    ctx.actions.run(
        inputs = [site_dir],
        outputs = [output],
        executable = script,
        mnemonic = "GzipHugoSite",
        progress_message = "Gzipping Hugo site files",
    )

    return [
        DefaultInfo(files = depset([output])),
        OutputGroupInfo(
            gzipped = depset([output]),
        ),
    ]

gzip_hugo_site = rule(
    doc = """
    Creates gzipped versions of compressible files from a Hugo site.

    This rule processes a hugo_site output and creates .gz versions of files
    matching the specified extensions. This is useful for nginx's gzip_static
    or similar static pre-compression features.

    The output is a directory tree mirroring the site structure, containing
    only the .gz files (e.g., styles.css becomes styles.css.gz).

    Example:
        hugo_site(
            name = "site",
            config = "config.yaml",
            content = glob(["content/**"]),
        )

        gzip_hugo_site(
            name = "site_gz",
            site = ":site",
            extensions = ["html", "css", "js", "xml", "txt", "json"],
            compression_level = 9,
        )

        # Use with pkg_tar
        pkg_tar(
            name = "static_assets",
            srcs = [":site"],
            package_dir = "/usr/share/nginx/html",
        )

        pkg_tar(
            name = "static_assets_gz",
            srcs = [":site_gz"],
            package_dir = "/usr/share/nginx/html",
        )

        # Combine both in your container
        oci_image(
            name = "nginx_image",
            tars = [
                ":static_assets",
                ":static_assets_gz",
            ],
        )
    """,
    implementation = _gzip_hugo_site_impl,
    attrs = {
        "site": attr.label(
            doc = "The hugo_site target to gzip",
            providers = [HugoSiteInfo],
            mandatory = True,
        ),
        "extensions": attr.string_list(
            doc = """
            File extensions to gzip (without the dot).
            Common values: html, css, js, xml, json, txt, svg
            """,
            default = ["html", "css", "js", "xml", "json", "txt"],
        ),
        "compression_level": attr.int(
            doc = "Gzip compression level (1-9, where 9 is maximum compression)",
            default = 9,
        ),
    },
)
