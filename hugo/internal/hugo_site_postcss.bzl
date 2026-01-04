"""General PostCSS processing rule for Hugo sites."""

load("//hugo/internal:hugo_site_info.bzl", "HugoSiteInfo")

def _postcss_hugo_site_impl(ctx):
    """Processes CSS files with PostCSS plugins.

    This rule applies configurable PostCSS transformations to CSS files
    in a Hugo site, supporting plugins like autoprefixer, cssnano, and more.
    """
    site_info = ctx.attr.site[HugoSiteInfo]
    site_dir = site_info.output_dir

    # Output directory for processed CSS
    output = ctx.actions.declare_directory(ctx.label.name)

    # Get the postcss processor script
    processor_script = ctx.file._processor

    # Build plugin list
    plugins = ctx.attr.plugins

    # Configuration file (optional)
    config_file = ctx.file.config

    # Build arguments
    args = ctx.actions.args()
    args.add(site_dir.path)
    args.add(output.path)
    if config_file:
        args.add(config_file.path)
    else:
        args.add("")  # Empty config
    args.add(",".join(plugins))

    # Run the script
    ctx.actions.run(
        inputs = [site_dir] + ([config_file] if config_file else []),
        outputs = [output],
        executable = processor_script,
        arguments = [args],
        mnemonic = "PostCSS",
        progress_message = "Processing CSS with PostCSS",
    )

    return [
        DefaultInfo(files = depset([output])),
        OutputGroupInfo(
            postcss = depset([output]),
        ),
    ]

postcss_hugo_site = rule(
    doc = """
    Processes CSS files with PostCSS plugins.

    This rule applies configurable PostCSS transformations to CSS files,
    supporting a wide range of plugins for optimization and compatibility.

    **Supported Plugins:**
    - `autoprefixer`: Adds vendor prefixes based on browser support
    - `cssnano`: Advanced CSS minification
    - `postcss-preset-env`: Transpiles future CSS features
    - `purgecss`: Removes unused CSS classes

    **Basic Usage:**
    ```python
    postcss_hugo_site(
        name = "site_postcss",
        site = ":my_site",
        plugins = ["autoprefixer"],
    )
    ```

    **Advanced Configuration:**
    ```python
    postcss_hugo_site(
        name = "site_optimized",
        site = ":my_site",
        plugins = ["autoprefixer", "cssnano"],
        config = "postcss.config.json",
    )
    ```

    **Configuration File (postcss.config.json):**
    ```json
    {
      "autoprefixer": {
        "grid": true
      },
      "cssnano": {
        "preset": ["default", {
          "discardComments": {
            "removeAll": true
          }
        }]
      }
    }
    ```

    **Requirements:**
    - Node.js 18+ must be installed and available in PATH
    - PostCSS plugins must be available in node_modules
    """,
    implementation = _postcss_hugo_site_impl,
    attrs = {
        "site": attr.label(
            doc = "The hugo_site target to process",
            providers = [HugoSiteInfo],
            mandatory = True,
        ),
        "plugins": attr.string_list(
            doc = """
            List of PostCSS plugins to apply.
            Supported: autoprefixer, cssnano, postcss-preset-env, purgecss
            """,
            mandatory = True,
        ),
        "config": attr.label(
            doc = "Optional PostCSS configuration file (JSON)",
            allow_single_file = ["json"],
        ),
        "_processor": attr.label(
            default = "//hugo/internal/tools/postcss:process.js",
            allow_single_file = True,
        ),
    },
)