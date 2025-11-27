"""Provider for Hugo site output information."""

HugoSiteInfo = provider(
    doc = """
    Information about a Hugo site build output.

    This provider makes it easier for downstream rules to access Hugo site files
    without dealing with tree artifacts directly.
    """,
    fields = {
        "output_dir": "Tree artifact containing all generated site files",
        "files": "Depset of all individual files in the output (if expanded)",
        "base_url": "The base URL configured for the site (if any)",
        "name": "The name of the site target",
    },
)
