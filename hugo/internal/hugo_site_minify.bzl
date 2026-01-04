"""Helper rule for minifying Hugo site files."""

load("//hugo/internal:hugo_site_info.bzl", "HugoSiteInfo")

def _minify_hugo_site_impl(ctx):
    """Minifies compressible text files in a Hugo site."""
    site_info = ctx.attr.site[HugoSiteInfo]
    site_dir = site_info.output_dir

    # Output directory for minified files
    output = ctx.actions.declare_directory(ctx.label.name)

    # Build comma-separated extensions list for the script
    extensions = ",".join(ctx.attr.extensions)

    ctx.actions.run(
        inputs = [site_dir],
        outputs = [output],
        executable = ctx.executable._minify_script,
        arguments = [
            site_dir.path,
            output.path,
            extensions,
        ],
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
    Minifies text files from a Hugo site to reduce file sizes.

    This rule processes a hugo_site output and creates minified versions
    of HTML, CSS, JS, XML, and JSON files. The output is a complete
    directory tree with minified files replacing the originals.

    Example:
        hugo_site(
            name = "site",
            config = "config.yaml",
            content = glob(["content/**"]),
        )

        minify_hugo_site(
            name = "site_minified",
            site = ":site",
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
            doc = "File extensions to minify (without the dot)",
            default = ["html", "css", "js", "xml", "json"],
        ),
        "_minify_script": attr.label(
            default = "//hugo/internal:hugo_site_minify.sh",
            allow_single_file = True,
            executable = True,
            cfg = "exec",
        ),
    },
)
