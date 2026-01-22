"""CSSnano rule for Hugo sites - advanced CSS minification."""

load("//hugo/internal:hugo_site_info.bzl", "HugoSiteInfo")

def _cssnano_hugo_site_impl(ctx):
    """Minifies CSS using CSSnano for maximum compression."""
    site_info = ctx.attr.site[HugoSiteInfo]
    site_dir = site_info.output_dir

    # Output directory for minified CSS
    output = ctx.actions.declare_directory(ctx.label.name)

    # Get the postcss processor script
    processor_script = ctx.file._processor

    # Build configuration
    config = {
        "cssnano": {
            "preset": ctx.attr.preset,
        },
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
    args.add("cssnano")

    # Run the script
    ctx.actions.run(
        inputs = [site_dir, config_file],
        outputs = [output],
        executable = processor_script,
        arguments = [args],
        mnemonic = "CSSnano",
        progress_message = "Minifying CSS with CSSnano",
        use_default_shell_env = True,
        execution_requirements = {
            "no-sandbox": "1",
        },
    )

    return [
        DefaultInfo(files = depset([output])),
        OutputGroupInfo(
            minified = depset([output]),
        ),
    ]

cssnano_hugo_site = rule(
    doc = """
    Minifies CSS using CSSnano for maximum compression.

    CSSnano is the most popular CSS minifier, providing advanced optimization
    beyond simple whitespace removal. It can restructure CSS for better compression
    while maintaining functionality.

    **Basic Usage:**
    ```python
    cssnano_hugo_site(
        name = "site_minified",
        site = ":my_site",
    )
    ```

    **Advanced Presets:**
    ```python
    cssnano_hugo_site(
        name = "site_compressed",
        site = ":my_site",
        preset = "advanced",  # More aggressive optimization
    )
    ```

    **Available Presets:**
    - `"default"`: Safe optimizations (recommended)
    - `"advanced"`: More aggressive optimizations
    - `"lite"`: Minimal optimizations

    **What CSSnano does:**
    - Removes unnecessary whitespace and comments
    - Merges duplicate rules
    - Removes unused @keyframes
    - Optimizes font-weight values
    - Converts colors to shorter formats (e.g., #ffffff → #fff)
    - Removes empty rules and declarations

    **Integration with other rules:**
    ```python
    # Recommended pipeline: autoprefixer → purgecss → cssnano
    autoprefixer_hugo_site(
        name = "prefixed",
        site = ":site",
    )

    purgecss_hugo_site(
        name = "purged",
        site = ":prefixed",
    )

    cssnano_hugo_site(
        name = "final",
        site = ":purged",
    )
    ```

    **Comparison with minify_hugo_site:**
    - `minify_hugo_site`: Simple shell-based minification (45-49% reduction)
    - `cssnano_hugo_site`: Advanced PostCSS-based minification (up to 60%+ reduction)

    **Requirements:**
    - Node.js 18+ must be installed and available in PATH
    """,
    implementation = _cssnano_hugo_site_impl,
    attrs = {
        "site": attr.label(
            doc = "The hugo_site target to process",
            providers = [HugoSiteInfo],
            mandatory = True,
        ),
        "preset": attr.string(
            doc = "CSSnano preset to use",
            default = "default",
            values = ["default", "advanced", "lite"],
        ),
        "_processor": attr.label(
            default = "//hugo/internal/tools/postcss:process.js",
            allow_single_file = True,
        ),
    },
)
