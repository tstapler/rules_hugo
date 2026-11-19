load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

HUGO_BUILD_FILE = """
package(default_visibility = ["//visibility:public"])
exports_files( ["hugo"] )
"""

def _build_from_source(repository_ctx):
    """Compiles Hugo from the tagged source archive with the host's Go toolchain."""
    go = repository_ctx.which("go")
    if not go:
        fail("hugo_repository(from_source = True) needs `go` on PATH (Hugo {} requires the Go version in its go.mod; GOTOOLCHAIN=auto fetches it).".format(repository_ctx.attr.version))

    repository_ctx.download_and_extract(
        url = "https://github.com/gohugoio/hugo/archive/refs/tags/v{}.tar.gz".format(repository_ctx.attr.version),
        sha256 = repository_ctx.attr.sha256,
        stripPrefix = "hugo-{}".format(repository_ctx.attr.version),
    )

    # Since 0.170 the standard build already includes the former "extended" features and needs no cgo.
    args = [str(go), "build", "-trimpath", "-ldflags", "-X github.com/gohugoio/hugo/common/hugo.vendorInfo=bazel", "-o", "hugo"]
    if repository_ctx.attr.build_tags:
        args += ["-tags", ",".join(repository_ctx.attr.build_tags)]
    args.append(".")

    result = repository_ctx.execute(
        args,
        environment = {
            "CGO_ENABLED": "0",
            "GOCACHE": str(repository_ctx.path(".gocache")),
            "GOMODCACHE": str(repository_ctx.path(".gomodcache")),
            "GOFLAGS": "-mod=mod",
        },
        timeout = 1800,
    )
    if result.return_code != 0:
        fail("go build of Hugo {} failed:\n{}".format(repository_ctx.attr.version, result.stderr))

    # Keep the external repo small: only the binary is needed afterwards.
    repository_ctx.delete(".gocache")
    repository_ctx.delete(".gomodcache")
    repository_ctx.file("BUILD.bazel", HUGO_BUILD_FILE)

def _use_local_binary(repository_ctx, path):
    """Exposes a Hugo binary that already exists on the host (not downloaded or built)."""
    binary = repository_ctx.path(path)
    if not binary.exists:
        fail("hugo_repository: binary {} does not exist".format(path))

    # Re-run when the binary changes, otherwise Bazel would keep a stale symlink target's content cached.
    repository_ctx.watch(binary)
    repository_ctx.symlink(binary, "hugo")
    repository_ctx.file("BUILD.bazel", HUGO_BUILD_FILE)

def _hugo_repository_impl(repository_ctx):
    # Precedence: env override > explicit binary > system PATH > build from source > custom url > GitHub release.
    override = repository_ctx.getenv("HUGO_BINARY")
    if override:
        return _use_local_binary(repository_ctx, override)
    if repository_ctx.attr.binary:
        return _use_local_binary(repository_ctx, repository_ctx.attr.binary)
    if repository_ctx.attr.use_system:
        found = repository_ctx.which("hugo")
        if not found:
            fail("hugo_repository(use_system = True): `hugo` not found on PATH")
        return _use_local_binary(repository_ctx, str(found))
    if repository_ctx.attr.from_source:
        return _build_from_source(repository_ctx)

    hugo = "hugo"
    if repository_ctx.attr.extended:
        hugo = "hugo_extended"

    os_arch = repository_ctx.attr.os_arch
    if not os_arch:
        os_name = repository_ctx.os.name.lower()
        arch = repository_ctx.os.arch
        if os_name.startswith("mac os"):
            # Hugo publishes no macOS tarball after 0.146 (only .pkg), so newer versions fail to download.
            os_arch = "darwin-universal"
        elif arch in ("aarch64", "arm64"):
            os_arch = "linux-arm64"
        else:
            os_arch = "linux-amd64"

    url_template = repository_ctx.attr.url or "https://github.com/gohugoio/hugo/releases/download/v{version}/{hugo}_{version}_{os_arch}.tar.gz"
    url = url_template.format(
        hugo = hugo,
        os_arch = os_arch,
        version = repository_ctx.attr.version,
    )

    repository_ctx.download_and_extract(
        url = url,
        sha256 = repository_ctx.attr.sha256,
    )

    repository_ctx.file("BUILD.bazel", HUGO_BUILD_FILE)

hugo_repository = repository_rule(
    _hugo_repository_impl,
    environ = ["HUGO_BINARY"],
    attrs = {
        "version": attr.string(
            default = "0.55.5",
            doc = "The hugo version to use",
        ),
        "sha256": attr.string(
            doc = "The sha256 value for the binary",
        ),
        "os_arch": attr.string(
            doc = "The os arch value. If empty, autodetect it",
        ),
        "extended": attr.bool(
            doc = "Use extended hugo version (ignored with from_source; 0.170+ has no separate extended build)",
        ),
        "binary": attr.string(
            doc = "Absolute path to an existing Hugo binary to use instead of downloading or building one. The HUGO_BINARY environment variable overrides it.",
        ),
        "use_system": attr.bool(
            doc = "Use the `hugo` found on PATH.",
        ),
        "url": attr.string(
            doc = "Archive URL template overriding the GitHub release (for mirrors); {version}, {hugo} and {os_arch} are substituted.",
        ),
        "from_source": attr.bool(
            doc = "Build Hugo from the tagged source with the host Go toolchain instead of downloading a release binary. Needed on platforms without release tarballs (e.g. macOS >= 0.147).",
        ),
        "build_tags": attr.string_list(
            doc = "Go build tags when from_source is set, e.g. [\"withdeploy\"]",
        ),
    },
)
