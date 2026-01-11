"""Autoprefixer rule for Hugo sites - adds vendor prefixes to CSS."""

load("//hugo/internal:hugo_site_info.bzl", "HugoSiteInfo")


def _autoprefixer_hugo_site_impl(ctx):
    """Adds vendor prefixes to CSS using Autoprefixer."""
    site_info = ctx.attr.site[HugoSiteInfo]
    site_dir = site_info.output_dir

    # Output directory for prefixed CSS
    output = ctx.actions.declare_directory(ctx.label.name)

    # Get the postcss processor script
    processor_script = ctx.file._processor

    # Build configuration
    config = {
        "autoprefixer": {
            "grid": getattr(ctx.attr, "grid", True),
        }
    }

    # Create config file
    config_content = json.encode(config)
    config_file = ctx.actions.declare_file(ctx.label.name + "_config.json")
    ctx.actions.write(
        output = config_file,
        content = config_content,
    )

    # Build arguments
    args = ctx.actions.args()
    args.add(site_dir.path)
    args.add(output.path)
    args.add(config_file.path)
    args.add("autoprefixer")

    # Run the script
    ctx.actions.run(
        inputs = [site_dir, config_file],
        outputs = [output],
        executable = processor_script,
        arguments = [args],
        mnemonic = "Autoprefixer",
        progress_message = "Adding vendor prefixes with Autoprefixer",
        execution_requirements = {
            "no-sandbox": "1",
        },
    )

    return [
        DefaultInfo(files = depset([output])),
        OutputGroupInfo(
            autoprefixed = depset([output]),
        ),
    ]

autoprefixer_hugo_site = rule(
    doc = """
    Adds vendor prefixes to CSS using Autoprefixer.

    Autoprefixer automatically adds vendor prefixes to CSS rules based on
    current browser support data from Can I Use. This ensures compatibility
    with older browsers while writing modern CSS.

    **Basic Usage:**
    ```python
    autoprefixer_hugo_site(
        name = "site_prefixed",
        site = ":my_site",
    )
    ```

    **With Grid Support:**
    ```python
    autoprefixer_hugo_site(
        name = "site_prefixed",
        site = ":my_site",
        grid = True,  # Enable CSS Grid prefixes
    )
    ```

    **What it does:**
    - Transforms: `display: flex` → `-webkit-display: flex; display: flex`
    - Adds prefixes for: flexbox, grid, transforms, transitions, etc.
    - Based on current browser support data

    **Integration with other rules:**
    ```python
    # Recommended: autoprefixer → purgecss → minify
    autoprefixer_hugo_site(
        name = "prefixed",
        site = ":site",
    )

    purgecss_hugo_site(
        name = "optimized",
        site = ":prefixed",
    )
    ```

    **Requirements:**
    - Node.js 18+ must be installed and available in PATH
    """,
    implementation = _autoprefixer_hugo_site_impl,
    attrs = {
        "site": attr.label(
            doc = "The hugo_site target to process",
            providers = [HugoSiteInfo],
            mandatory = True,
        ),
        "grid": attr.bool(
            doc = "Enable CSS Grid vendor prefixes",
            default = True,
        ),
        "_processor": attr.label(
            default = "//hugo/internal/tools/postcss:process.js",
            allow_single_file = True,
        ),
    },
)