"""Prerender rule for Hugo sites - captures fully rendered HTML."""

load("//hugo/internal:hugo_site_info.bzl", "HugoSiteInfo")

def _prerender_hugo_site_impl(ctx):
    """Prerenders HTML pages using Puppeteer for better performance."""
    site_info = ctx.attr.site[HugoSiteInfo]
    site_dir = site_info.output_dir

    # Output directory for prerendered HTML
    output = ctx.actions.declare_directory(ctx.label.name)

    # Get the prerender processor script
    processor_script = ctx.file._processor

    # Build options
    options = []
    if ctx.attr.wait_for_network_idle:
        options.append("--wait-for-network-idle")
    if ctx.attr.capture_js_errors:
        options.append("--capture-js-errors")
    if ctx.attr.minify:
        options.append("--minify")

    options_str = " ".join(options)

    # Build arguments
    args = ctx.actions.args()
    args.add(site_dir.path)
    args.add(output.path)
    args.add(ctx.attr.base_url)
    args.add_all(options)

    # Run the script
    ctx.actions.run(
        inputs = [site_dir, processor_script],
        outputs = [output],
        executable = processor_script,
        arguments = [args],
        mnemonic = "Prerender",
        progress_message = "Prerendering HTML pages with Puppeteer",
        use_default_shell_env = True,
        execution_requirements = {
            # Allow network access for Puppeteer
            "no-sandbox": "1",
        },
    )

    return [
        DefaultInfo(files = depset([output])),
        OutputGroupInfo(
            prerendered = depset([output]),
        ),
    ]

prerender_hugo_site = rule(
    doc = """
    Prerenders HTML pages using Puppeteer for improved performance.

    This rule uses headless Chrome to render HTML pages and capture the
    fully rendered content. While Hugo already generates static HTML,
    prerendering is useful for:

    - Capturing JavaScript-rendered content
    - Optimizing HTML structure for better caching
    - Preparing pages for static hosting optimizations
    - Ensuring consistent rendering across environments

    **Basic Usage:**
    ```python
    prerender_hugo_site(
        name = "site_prerendered",
        site = ":my_site",
        base_url = "https://example.com",
    )
    ```

    **Advanced Configuration:**
    ```python
    prerender_hugo_site(
        name = "site_optimized",
        site = ":my_site",
        base_url = "https://example.com",
        wait_for_network_idle = True,  # Wait for all network requests
        capture_js_errors = True,      # Log JavaScript errors
        minify = True,                 # Minify the final HTML
    )
    ```

    **Configuration Options:**
    - `base_url`: Base URL for the site (used for link resolution)
    - `wait_for_network_idle`: Wait for all network requests to complete
    - `capture_js_errors`: Log any JavaScript errors during rendering
    - `minify`: Minify the final HTML output

    **Use Cases:**
    1. **Dynamic Content**: Capture content rendered by JavaScript
    2. **SEO Optimization**: Ensure search engines see fully rendered content
    3. **Performance**: Pre-render pages for instant loading
    4. **Consistency**: Ensure uniform rendering across different browsers

    **Integration with other rules:**
    ```python
    # Recommended pipeline: prerender → critical CSS → compress
    prerender_hugo_site(
        name = "prerendered",
        site = ":site",
    )

    critical_css_hugo_site(
        name = "optimized",
        site = ":prerendered",
    )

    gzip_hugo_site(
        name = "compressed",
        site = ":optimized",
    )
    ```

    **Performance Considerations:**
    - Prerendering adds build time (headless browser startup)
    - Best suited for sites with moderate JavaScript content
    - Consider selective prerendering for large sites

    **Requirements:**
    - Node.js 18+ must be installed and available in PATH
    - puppeteer must be available in node_modules
    - Sufficient memory for headless Chrome instances

    **Note:** Since Hugo generates static HTML, prerendering is most beneficial
    for sites with client-side JavaScript that modifies the DOM after initial load.
    """,
    implementation = _prerender_hugo_site_impl,
    attrs = {
        "site": attr.label(
            doc = "The hugo_site target to prerender",
            providers = [HugoSiteInfo],
            mandatory = True,
        ),
        "base_url": attr.string(
            doc = "Base URL for the site (used for link resolution)",
            mandatory = True,
        ),
        "wait_for_network_idle": attr.bool(
            doc = "Wait for all network requests to complete",
            default = False,
        ),
        "capture_js_errors": attr.bool(
            doc = "Log JavaScript errors during rendering",
            default = False,
        ),
        "minify": attr.bool(
            doc = "Minify the final HTML output",
            default = False,
        ),
        "_processor": attr.label(
            default = "//hugo/internal/tools/prerender:process.js",
            allow_single_file = True,
        ),
    },
)
