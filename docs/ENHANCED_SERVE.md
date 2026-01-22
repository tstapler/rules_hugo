# Enhanced Hugo Serve with rules_devserver Integration

This enhancement adds extensive configuration options to the `hugo_serve` rule, making it much more suitable for development workflows and enabling better integration with `rules_devserver`.

## New Features

### Enhanced Server Configuration
- `draft`: Include draft content (-D flag)
- `bind`: Specify interface to bind to (e.g., "0.0.0.0")
- `port`: Custom port for the server
- `base_url`: Custom base URL
- `live_reload_port`: Custom live reload port
- `navigate_to_changed`: Navigate to changed files on reload

### Development Options
- `build_drafts`: Build draft content
- `build_future`: Include future content
- `build_expired`: Include expired content
- `additional_args`: Custom arguments for rules_devserver integration

## Usage Examples

### Basic Enhanced Serve
```starlark
load("@io_bazel_rules_hugo//hugo:defs.bzl", "hugo_serve")

hugo_serve(
    name = "serve",
    site = ":my_site",
    draft = True,
    bind = "0.0.0.0",
    port = 1313,
    navigate_to_changed = True,
)
```

### With rules_devserver Integration
```starlark
load("@io_bazel_rules_hugo//hugo:defs.bzl", "hugo_serve")
load("@io_bazel_rules_devserver//devserver:defs.bzl", "devserver")

# Enhanced hugo serve target
hugo_serve(
    name = "hugo_dev",
    site = ":my_site",
    draft = True,
    build_drafts = True,
    bind = "127.0.0.1",
    port = 1313,
    live_reload_port = 35729,
    navigate_to_changed = True,
    disable_fast_render = False,
)

# rules_devserver integration
devserver(
    name = "devserver",
    main = ":hugo_dev",
    additional_args = [
        "--port=8080",  # Override port via rules_devserver
        "--verbose",
    ],
    # Additional devserver features
    support_workspace = True,
    data = [":my_site"],
)
```

### Production-like Development
```starlark
hugo_serve(
    name = "serve_prod_like",
    site = ":my_site",
    draft = False,
    build_drafts = False,
    build_future = False,
    bind = "0.0.0.0",
    port = 8080,
    base_url = "https://example.com",
    disable_fast_render = False,
)
```

## Migration from Previous Version

### Before
```starlark
hugo_serve(
    name = "serve",
    dep = [":site"],
    quiet = True,
    disable_fast_render = True,
)
```

### After
```starlark
hugo_serve(
    name = "serve",
    site = [":site"],  # Changed from 'dep' to 'site'
    quiet = True,
    disable_fast_render = True,
    # New options available
    draft = True,
    bind = "0.0.0.0",
    port = 1313,
)
```

## Running the Server

### Direct Bazel Run
```bash
bazel run //:serve
```

### Via rules_devserver
```bash
bazel run //:devserver
```

### With Custom Port
```bash
bazel run //:serve -- --port=8080
```

## Implementation Details

The enhanced hugo_serve rule:
1. Generates a proper shell script with the Hugo server command
2. Passes all configured arguments correctly
3. Maintains compatibility with existing rules_devserver patterns
4. Provides better error handling and user feedback

The script template now includes:
- Proper bash execution with `set -e`
- Directory navigation to the site directory
- Clear startup message
- Proper executable permissions

## Testing

To test the new functionality:

1. Create a test Hugo site
2. Add the enhanced hugo_serve rule to your BUILD.bazel
3. Run `bazel run //:serve`
4. Verify the server starts with the configured options
5. Test live reload functionality
6. Test rules_devserver integration if configured