# rules_hugo

Bazel rules for building [Hugo](https://gohugo.io/) static sites.

## Features

- **Hermetic Hugo Toolchain**: Automatically downloads and configures the correct Hugo binary (Standard or Extended) for your platform.
- **Bzlmod Support**: Fully compatible with Bazel 8.x, 9.x, and Bzlmod for dependency management.
- **Theme Management**: Easily fetch themes from GitHub or arbitrary URLs.
- **Optimization Pipeline**:
    - **Minification**: HTML, CSS, JS, XML, and JSON minification.
    - **Fingerprinting**: Asset fingerprinting for cache busting.
    - **Compression**: Gzip and Brotli compression for production artifacts.
    - **Image Optimization**: WebP and AVIF conversion with 60-75% size reduction (up to 80% with AVIF) while maintaining visual quality.
    - **Critical CSS**: Extract critical CSS for above-the-fold content.
    - **Prerendering**: Generate static HTML for JS-heavy sites using Puppeteer.
- **Development Server**: Fast incremental builds with `bazel run //path/to:site_serve`.

## Installation (Bzlmod)

Add the following to your `MODULE.bazel` file:

```starlark
bazel_dep(name = "build_stack_rules_hugo", version = "0.1.0")

hugo = use_extension("@build_stack_rules_hugo//hugo/internal:extensions.bzl", "hugo_extension")

# Configure the Hugo toolchain
hugo.hugo(
    name = "hugo",
    version = "0.170.1",
    extended = True,  # Use extended version for Sass/SCSS support
)

# Other ways to obtain the binary. binary, use_system and from_source are mutually exclusive, and url only
# applies to release downloads (conflicts fail). The HUGO_BINARY env var overrides all of them, logs a notice,
# and is not checked against sha256 or version. binary/use_system/HUGO_BINARY trust the host and are unverified.
# from_source builds with GOFLAGS=-mod=readonly and the Go checksum database on (sum.golang.org must be reachable); the result depends on the host
# Go version. Set sha256 for url and from_source, otherwise the archive is unverified (a warning is printed).
#   binary = "/opt/hugo/bin/hugo",   # absolute path to a binary you provide
#   use_system = True,               # the `hugo` on PATH
#   from_source = True,              # `go build` the tagged source with the host Go (needs `go` on PATH);
#                                    # set build_tags = ["withdeploy"] for deploy support. Works where no release
#                                    # tarball exists (macOS >= 0.147). Set sha256 to pin the source archive.
#   url = "https://mirror/{hugo}_{version}_{os_arch}.tar.gz",  # mirror for the release archive

# Register a theme from GitHub
hugo.github_theme(
    name = "com_github_alex_shpak_hugo_book",
    owner = "alex-shpak",
    repo = "hugo-book",
    commit = "cec082b8dd9b31d0c52b2de95d86ced9909cc7ec",
    sha256 = "71b6885054d0b11562fc8353d31b98ca225915ce9441b6e4909484e7556e2f22",
)

use_repo(hugo, "hugo", "com_github_alex_shpak_hugo_book")
```

## Usage

### 1. Define your Hugo site

In your `BUILD.bazel` file:

```starlark
load("@build_stack_rules_hugo//hugo:rules.bzl", "hugo_site", "hugo_theme")

# Define the site
hugo_site(
    name = "my_site",
    config = "config.yaml",
    content = glob(["content/**"]),
    layouts = glob(["layouts/**"]),
    static = glob(["static/**"]),
    theme = ":my_theme",
)

# Define the theme target (wrapper around the external repo)
hugo_theme(
    name = "my_theme",
    theme_name = "book",
    srcs = ["@com_github_alex_shpak_hugo_book//:files"],
)
```

### 2. Run the development server

```bash
bazel run //:my_site_serve
```

### 3. Build for production

```bash
bazel build //:my_site
```

### 4. Optimize for deployment

```starlark
load("@build_stack_rules_hugo//hugo:rules.bzl", "minify_hugo_site", "gzip_hugo_site", "brotli_hugo_site", "optimize_images_hugo_site")

# Minify HTML, CSS, and JavaScript
minify_hugo_site(
    name = "site_minified",
    site = ":my_site",
)

# Optimize images (WebP and AVIF generation)
optimize_images_hugo_site(
    name = "site_optimized",
    site = ":site_minified",
    extensions = ["jpg", "jpeg", "png"],
    webp_quality = 80,
    generate_avif = True,
    avif_quality = 65,
)

# Compress for web delivery
gzip_hugo_site(
    name = "site_gzip",
    site = ":site_optimized",
)

brotli_hugo_site(
    name = "site_brotli",
    site = ":site_optimized",
)
```

## Legacy Installation (WORKSPACE)

<details>
<summary>Click to expand legacy WORKSPACE instructions</summary>

If you are not yet using Bzlmod, add this to your `WORKSPACE` file:

```starlark
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "build_stack_rules_hugo",
    sha256 = "...",
    strip_prefix = "rules_hugo-...",
    urls = ["https://github.com/stackb/rules_hugo/archive/..."],
)

load("@build_stack_rules_hugo//hugo:repositories.bzl", "hugo_repositories")

hugo_repositories()

load("@build_stack_rules_hugo//hugo:index.bzl", "hugo_toolchains")

hugo_toolchains(
    version = "0.146.0",
    extended = True,
)
```

</details>
