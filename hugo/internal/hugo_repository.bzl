load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

HUGO_BUILD_FILE = """
package(default_visibility = ["//visibility:public"])
exports_files( ["hugo"] )
"""

def _validate(repository_ctx):
    """Fails fast on option combinations that would otherwise be silently ignored."""
    a = repository_ctx.attr
    version_parts = a.version.split(".")
    if len(version_parts) != 3 or not all([p.isdigit() for p in version_parts]):
        fail("hugo_repository: version must look like 0.170.1, got {!r}".format(a.version))
    for tag in a.build_tags:
        if not tag.replace("_", "").isalnum():
            fail("hugo_repository: invalid build tag {!r}".format(tag))

    modes = [n for n, on in [("binary", a.binary), ("use_system", a.use_system), ("from_source", a.from_source)] if on]
    if len(modes) > 1:
        fail("hugo_repository: {} are mutually exclusive".format(", ".join(modes)))
    if a.url and modes:
        fail("hugo_repository: url only applies to release downloads, not {}".format(modes[0]))
    if a.build_tags and not a.from_source:
        fail("hugo_repository: build_tags only applies with from_source = True")
    if (a.binary or a.use_system) and a.sha256:
        fail("hugo_repository: sha256 cannot be checked for a binary supplied by the host (binary/use_system)")
    if (a.url or a.from_source) and not a.sha256:
        print("WARNING: hugo_repository {} downloads {} without sha256; set sha256 to pin it".format(repository_ctx.name, "source" if a.from_source else "an archive from a mirror"))

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
            # go.sum must verify every module; blank out host settings that would skip checksum verification.
            "GOFLAGS": "-mod=readonly",
            "GOENV": "off",
            "GONOSUMDB": "",
            "GONOSUMCHECK": "",
            "GOPRIVATE": "",
            "GOINSECURE": "",
            "GOSUMDB": "sum.golang.org",
            "GOTELEMETRY": "off",
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
    if not path.startswith("/"):
        fail("hugo_repository: binary must be an absolute path, got {}".format(path))
    binary = repository_ctx.path(path)
    if not binary.exists or binary.is_dir:
        fail("hugo_repository: binary {} does not exist or is a directory".format(path))

    # Re-run when the binary changes, otherwise Bazel would keep a stale symlink target's content cached.
    repository_ctx.watch(binary)
    repository_ctx.symlink(binary, "hugo")
    repository_ctx.file("BUILD.bazel", HUGO_BUILD_FILE)

def _hugo_repository_impl(repository_ctx):
    # Precedence: env override > explicit binary > system PATH > build from source > custom url > GitHub release.
    _validate(repository_ctx)
    override = repository_ctx.getenv("HUGO_BINARY")
    if override:
        print("hugo_repository {}: using HUGO_BINARY={} (ignores version, sha256 and other sourcing options)".format(repository_ctx.name, override))
        return _use_local_binary(repository_ctx, override)
    if repository_ctx.attr.binary:
        return _use_local_binary(repository_ctx, repository_ctx.attr.binary)
    if repository_ctx.attr.use_system:
        repository_ctx.getenv("PATH")  # re-resolve when PATH changes
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
            if not repository_ctx.attr.url:
                print("NOTE: Hugo publishes no macOS tarball after 0.146; if the download 404s, set from_source = True or use_system = True")
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
            doc = "Archive URL template overriding the GitHub release (for mirrors); {version}, {hugo} and {os_arch} are substituted, so avoid other braces.",
        ),
        "from_source": attr.bool(
            doc = "Build Hugo from the tagged source with the host Go toolchain instead of downloading a release binary. Needed on platforms without release tarballs (e.g. macOS >= 0.147).",
        ),
        "build_tags": attr.string_list(
            doc = "Go build tags when from_source is set, e.g. [\"withdeploy\"]",
        ),
    },
)
