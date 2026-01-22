"""Stylelint rule for Hugo sites - CSS linting and fixing."""

load("//hugo/internal:hugo_site_info.bzl", "HugoSiteInfo")

def _stylelint_hugo_site_impl(ctx):
    """Lints and optionally fixes CSS files using Stylelint."""
    site_info = ctx.attr.site[HugoSiteInfo]
    site_dir = site_info.output_dir

    # Output directory for linted/fixed CSS
    output = ctx.actions.declare_directory(ctx.label.name)

    # Get the stylelint processor script
    processor_script = ctx.file._processor

    # Configuration file (optional)
    config_file = ctx.file.config

    # Determine mode
    mode = "fix" if ctx.attr.fix else "check"

    # Build arguments
    args = ctx.actions.args()
    args.add(site_dir.path)
    args.add(output.path)
    if config_file:
        args.add(config_file.path)
    else:
        args.add("")  # Use default config
    args.add(mode)

    # Run the script
    ctx.actions.run(
        inputs = [site_dir] + ([config_file] if config_file else []),
        outputs = [output],
        executable = processor_script,
        arguments = [args],
        mnemonic = "Stylelint",
        progress_message = "Linting CSS with Stylelint ({} mode)".format(mode),
        use_default_shell_env = True,
        execution_requirements = {
            "no-sandbox": "1",
        },
    )

    return [
        DefaultInfo(files = depset([output])),
        OutputGroupInfo(
            linted = depset([output]),
        ),
    ]

stylelint_hugo_site = rule(
    doc = """
    Lints and optionally fixes CSS files using Stylelint.

    Stylelint is a powerful CSS linter that helps catch errors, enforce
    consistent conventions, and ensure code quality before processing.

    **Lint-Only Mode (default):**
    ```python
    stylelint_hugo_site(
        name = "site_linted",
        site = ":my_site",
    )
    ```

    **Auto-Fix Mode:**
    ```python
    stylelint_hugo_site(
        name = "site_fixed",
        site = ":my_site",
        fix = True,
    )
    ```

    **Custom Configuration:**
    ```python
    stylelint_hugo_site(
        name = "site_custom_lint",
        site = ":my_site",
        config = ".stylelintrc.json",
    )
    ```

    **Configuration File (.stylelintrc.json):**
    ```json
    {
      "extends": ["stylelint-config-standard"],
      "rules": {
        "property-no-unknown": true,
        "selector-class-pattern": "^[a-z][a-zA-Z0-9]*$",
        "color-hex-case": "lower",
        "color-no-invalid-hex": true
      }
    }
    ```

    **What Stylelint checks:**
    - Syntax errors and invalid properties
    - Consistent formatting and naming conventions
    - Performance issues (e.g., inefficient selectors)
    - Maintainability concerns
    - Accessibility guidelines

    **Hugo-specific considerations:**
    - Automatically allows Hugo's dynamic class patterns
    - Permits custom properties and Hugo variables
    - Works with both SCSS/Sass and plain CSS

    **Integration with development workflow:**
    ```python
    # Pre-commit linting
    stylelint_hugo_site(
        name = "lint_css",
        site = ":site",
    )

    # CI pipeline with auto-fix
    stylelint_hugo_site(
        name = "fix_css",
        site = ":site",
        fix = True,
    )
    ```

    **Requirements:**
    - Node.js 18+ must be installed and available in PATH
    - stylelint and stylelint-config-standard must be available in node_modules
    """,
    implementation = _stylelint_hugo_site_impl,
    attrs = {
        "site": attr.label(
            doc = "The hugo_site target to process",
            providers = [HugoSiteInfo],
            mandatory = True,
        ),
        "fix": attr.bool(
            doc = "Automatically fix linting issues when possible",
            default = False,
        ),
        "config": attr.label(
            doc = "Optional Stylelint configuration file",
            allow_single_file = ["json"],
        ),
        "_processor": attr.label(
            default = "//hugo/internal/tools/stylelint:process.js",
            allow_single_file = True,
        ),
    },
)
