"""Helper rule for optimizing images in Hugo site output."""

load("//hugo/internal:hugo_site_info.bzl", "HugoSiteInfo")

def _optimize_images_hugo_site_impl(ctx):
    """Optimizes images in a Hugo site by generating WebP and AVIF variants.

    This rule processes images from a Hugo site and creates modern format variants
    (WebP and AVIF) for improved performance and smaller file sizes.
    """
    site_info = ctx.attr.site[HugoSiteInfo]
    site_dir = site_info.output_dir

    # Output directory for optimized images
    output = ctx.actions.declare_directory(ctx.label.name)

    # Get the hermetic tools (as File objects, not executables)
    cwebp = ctx.file._cwebp
    avifenc = ctx.file._avifenc if ctx.attr.generate_avif else None

    # Build list of image extensions to process
    extensions = ctx.attr.extensions
    find_expr = " -o ".join(['-name "*.{}"'.format(ext) for ext in extensions])

    # Quality settings
    webp_quality = ctx.attr.webp_quality
    avif_quality = ctx.attr.avif_quality

    # Create the optimization script
    avif_section = ""
    if ctx.attr.generate_avif:
        avif_section = """
    # Generate AVIF variant
    if [ -n "$AVIFENC" ]; then
        "$AVIFENC" -s 4 -j 4 -d 10 -y 444 --min 0 --max 63 -a end-usage=q -a cq-level={avif_quality} -a tune=ssim \\
            "$ORIG_PATH" "$OUTPUT_ABS/${{file%.}}.avif" 2>/dev/null || true
        if [ -f "$OUTPUT_ABS/${{file%.}}.avif" ]; then
            echo "  Created AVIF: ${{file%.}}.avif"
        fi
    fi
""".format(avif_quality = avif_quality)

    # Build correct paths for external repository files
    # For files from external repos, we need to use "external/repo_name/path"
    cwebp_path = "external/" + cwebp.short_path.lstrip("../")
    avifenc_path = ("external/" + avifenc.short_path.lstrip("../")) if avifenc else ""

    script_content = """#!/bin/bash
set -euo pipefail

SITE_DIR="{site_dir}"
OUTPUT_DIR="{output_dir}"
CWEBP="{cwebp}"
AVIFENC="{avifenc}"

echo "Optimizing images from $SITE_DIR to $OUTPUT_DIR"

# Create output directory and get absolute path
mkdir -p "$OUTPUT_DIR"
OUTPUT_ABS="$(cd "$OUTPUT_DIR" && pwd)"

# Copy entire site structure first (preserving originals)
cp -rL "$SITE_DIR/." "$OUTPUT_ABS/"

# Copy cwebp to a local path to work around symlink issues in sandbox
# The -L flag follows symlinks
CWEBP_LOCAL="$(pwd)/cwebp_tool"
cp -L "$CWEBP" "$CWEBP_LOCAL" || {{
    echo "ERROR: Failed to copy cwebp from: $CWEBP"
    exit 1
}}
chmod +x "$CWEBP_LOCAL"
CWEBP="$CWEBP_LOCAL"

# Get absolute path for site directory
SITE_ABS="$(cd "$SITE_DIR" && pwd)"

# Find and process images
cd "$SITE_ABS"
PROCESSED=0

find -L . -type f \\( {find_expr} \\) | while read -r file; do
    # Get the original file path (file starts with ./)
    ORIG_PATH="$SITE_ABS/$file"

    echo "Processing: $file"

    # Generate WebP variant
    "$CWEBP" -q {webp_quality} "$ORIG_PATH" -o "$OUTPUT_ABS/${{file}}.webp" >/dev/null 2>&1
    if [ -f "$OUTPUT_ABS/${{file}}.webp" ]; then
        echo "  Created WebP: $file.webp"
    fi
{avif_section}
    PROCESSED=$((PROCESSED + 1))
done

echo "Processed $PROCESSED images"

# Count generated files
WEBP_COUNT=$(find "$OUTPUT_ABS" -name "*.webp" 2>/dev/null | wc -l)
AVIF_COUNT=$(find "$OUTPUT_ABS" -name "*.avif" 2>/dev/null | wc -l)

echo "Generated $WEBP_COUNT WebP and $AVIF_COUNT AVIF variants"
""".format(
        site_dir = site_dir.path,
        output_dir = output.path,
        cwebp = cwebp_path,
        avifenc = avifenc_path,
        find_expr = find_expr,
        webp_quality = webp_quality,
        avif_section = avif_section,
    )

    script = ctx.actions.declare_file(ctx.label.name + "_optimize.sh")
    ctx.actions.write(
        output = script,
        content = script_content,
        is_executable = True,
    )

    # Prepare inputs and tools
    # Add cwebp to inputs so it's available in the sandbox
    inputs = [site_dir, cwebp]
    if avifenc:
        inputs.append(avifenc)

    tools = []

    ctx.actions.run(
        inputs = inputs,
        outputs = [output],
        executable = script,
        tools = tools,
        mnemonic = "OptimizeImages",
        progress_message = "Optimizing images for Hugo site",
    )

    return [
        DefaultInfo(files = depset([output])),
        OutputGroupInfo(
            optimized = depset([output]),
        ),
    ]

optimize_images_hugo_site = rule(
    doc = """
    Optimizes images in a Hugo site by generating WebP and AVIF variants.

    This rule processes images from a hugo_site output and creates modern format
    variants (WebP and optionally AVIF) alongside the originals. This provides
    40-80% file size reduction while maintaining visual quality.

    The output is a complete site directory with:
    - Original images (JPEG, PNG, etc.)
    - WebP variants (.webp extension added)
    - AVIF variants (.avif extension added, if enabled)

    Example:
        hugo_site(
            name = "site",
            config = "config.yaml",
            content = glob(["content/**"]),
            static = glob(["static/**"]),
        )

        optimize_images_hugo_site(
            name = "site_optimized",
            site = ":site",
            extensions = ["jpg", "jpeg", "png"],
            webp_quality = 80,
            generate_avif = True,
            avif_quality = 65,
        )

        # Use in deployment
        pkg_tar(
            name = "static_assets",
            srcs = [":site_optimized"],
            package_dir = "/usr/share/nginx/html",
        )
    """,
    implementation = _optimize_images_hugo_site_impl,
    attrs = {
        "site": attr.label(
            doc = "The hugo_site target to optimize",
            providers = [HugoSiteInfo],
            mandatory = True,
        ),
        "extensions": attr.string_list(
            doc = """
            Image file extensions to process (without the dot).
            Common values: jpg, jpeg, png, gif
            """,
            default = ["jpg", "jpeg", "png"],
        ),
        "webp_quality": attr.int(
            doc = "WebP quality (0-100, where 100 is maximum quality)",
            default = 80,
        ),
        "generate_avif": attr.bool(
            doc = "Whether to generate AVIF variants (better compression but slower)",
            default = False,
        ),
        "avif_quality": attr.int(
            doc = "AVIF quality (0-100, where 100 is maximum quality)",
            default = 65,
        ),
        "_cwebp": attr.label(
            default = "@libwebp//:bin/cwebp",
            allow_single_file = True,
            cfg = "exec",
        ),
        "_avifenc": attr.label(
            # TODO: Set up hermetic avifenc when generate_avif support is added
            default = "@libwebp//:bin/cwebp",  # Dummy default, not used when generate_avif=False
            allow_single_file = True,
            cfg = "exec",
        ),
    },
)
