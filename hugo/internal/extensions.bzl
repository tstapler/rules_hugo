load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("//hugo/internal:github_hugo_theme.bzl", "github_hugo_theme")
load("//hugo/internal:hugo_repository.bzl", "hugo_repository")

def _hugo_extension_impl(ctx):
    for mod in ctx.modules:
        for hugo_tag in mod.tags.hugo:
            hugo_repository(
                name = hugo_tag.name,
                version = hugo_tag.version,
                extended = hugo_tag.extended,
                sha256 = hugo_tag.sha256,
                from_source = hugo_tag.from_source,
                binary = hugo_tag.binary,
                use_system = hugo_tag.use_system,
                url = hugo_tag.url,
                build_tags = hugo_tag.build_tags,
            )
        for theme_tag in mod.tags.github_theme:
            github_hugo_theme(
                name = theme_tag.name,
                owner = theme_tag.owner,
                repo = theme_tag.repo,
                commit = theme_tag.commit,
                sha256 = theme_tag.sha256,
            )
        for theme_tag in mod.tags.http_theme:
            http_archive(
                name = theme_tag.name,
                url = theme_tag.url,
                sha256 = theme_tag.sha256,
                build_file_content = theme_tag.build_file_content,
            )

hugo_extension = module_extension(
    implementation = _hugo_extension_impl,
    tag_classes = {
        "hugo": tag_class(attrs = {
            "name": attr.string(mandatory = True),
            "version": attr.string(mandatory = True),
            "extended": attr.bool(default = True),
            "sha256": attr.string(doc = "sha256 of the release tarball, or of the source archive when from_source is set"),
            "from_source": attr.bool(default = False),
            "binary": attr.string(doc = "Absolute path to a Hugo binary to use as-is"),
            "use_system": attr.bool(default = False),
            "url": attr.string(doc = "Archive URL template ({version}, {hugo}, {os_arch})"),
            "build_tags": attr.string_list(),
        }),
        "github_theme": tag_class(attrs = {
            "name": attr.string(mandatory = True),
            "owner": attr.string(mandatory = True),
            "repo": attr.string(mandatory = True),
            "commit": attr.string(mandatory = True),
            "sha256": attr.string(),
        }),
        "http_theme": tag_class(attrs = {
            "name": attr.string(mandatory = True),
            "url": attr.string(mandatory = True),
            "sha256": attr.string(),
            "build_file_content": attr.string(),
        }),
    },
)
