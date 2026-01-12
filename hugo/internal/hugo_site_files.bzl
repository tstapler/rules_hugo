"""Utilities for working with Hugo site files in downstream rules."""

load("//hugo/internal:hugo_site_info.bzl", "HugoSiteInfo")

def _expand_hugo_site_impl(ctx):
    """Expands a Hugo site directory into individual file outputs.

    This is useful for downstream rules that need to process individual files
    rather than working with a tree artifact.
    """
    site_info = ctx.attr.site[HugoSiteInfo]
    output_dir = site_info.output_dir

    # Use a simple approach: create a manifest of files and make it available
    # Downstream rules can read the directory directly
    manifest = ctx.actions.declare_file(ctx.label.name + "_manifest.txt")

    ctx.actions.run_shell(
        inputs = [output_dir],
        outputs = [manifest],
        command = """
            manifest_path="$PWD/{manifest}"
            cd {dir}
            find . -type f | sort > "$manifest_path"
        """.format(
            dir = output_dir.path,
            manifest = manifest.path,
        ),
        mnemonic = "HugoSiteManifest",
        progress_message = "Creating manifest for Hugo site",
    )

    return [
        DefaultInfo(
            files = depset([manifest, output_dir]),
        ),
        OutputGroupInfo(
            manifest = depset([manifest]),
            directory = depset([output_dir]),
        ),
        site_info,
    ]

hugo_site_files = rule(
    doc = """
    Expands a Hugo site into a manifest of files for easier downstream processing.

    This rule takes a hugo_site target and creates a manifest file listing all
    generated files. This makes it easier to write genrules and other rules that
    need to process Hugo output files.

    Example:
        hugo_site_files(
            name = "site_files",
            site = ":my_site",
        )

        genrule(
            name = "process_files",
            srcs = [":site_files"],
            outs = ["processed.tar"],
            cmd = '''
                # Access the site directory
                SITE_DIR=$$(dirname $$(echo $(locations :site_files) | cut -d' ' -f2))
                # Access the manifest
                MANIFEST=$$(echo $(locations :site_files) | grep manifest.txt)
                # Process files listed in manifest
                while read file; do
                    echo "Processing $$file"
                    # Your processing here
                done < $$MANIFEST
            ''',
        )
    """,
    implementation = _expand_hugo_site_impl,
    attrs = {
        "site": attr.label(
            doc = "The hugo_site target to expand",
            providers = [HugoSiteInfo],
            mandatory = True,
        ),
    },
)


def _process_hugo_site_impl(ctx):
    """Generic processor for Hugo site files with a custom script."""
    site_info = ctx.attr.site[HugoSiteInfo]
    site_dir = site_info.output_dir

    output = ctx.actions.declare_directory(ctx.label.name)

    # Prepare the processor script arguments
    args = ctx.actions.args()
    args.add(site_dir.path)
    args.add(output.path)
    args.add_all(ctx.attr.processor_args)

    ctx.actions.run(
        inputs = [site_dir] + ctx.files.processor_data,
        outputs = [output],
        executable = ctx.executable.processor,
        arguments = [args],
        mnemonic = "ProcessHugoSite",
        progress_message = "Processing Hugo site with %s" % ctx.attr.processor.label,
    )

    return [
        DefaultInfo(files = depset([output])),
        OutputGroupInfo(
            processed = depset([output]),
        ),
    ]

process_hugo_site = rule(
    doc = """
    Process a Hugo site with a custom script or tool.

    This rule provides a convenient way to run post-processing on Hugo site output.
    The processor receives the site directory path as the first argument and the
    output directory path as the second argument.

    Example:
        process_hugo_site(
            name = "minified_site",
            site = ":my_site",
            processor = "@npm//minify:bin",
            processor_args = ["--css", "--js"],
        )
    """,
    implementation = _process_hugo_site_impl,
    attrs = {
        "site": attr.label(
            doc = "The hugo_site target to process",
            providers = [HugoSiteInfo],
            mandatory = True,
        ),
        "processor": attr.label(
            doc = "The executable to use for processing",
            executable = True,
            cfg = "exec",
            mandatory = True,
        ),
        "processor_args": attr.string_list(
            doc = "Additional arguments to pass to the processor",
            default = [],
        ),
        "processor_data": attr.label_list(
            doc = "Additional data files needed by the processor",
            allow_files = True,
            default = [],
        ),
    },
)
