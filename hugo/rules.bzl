load("//hugo/internal:hugo_repository.bzl", _hugo_repository = "hugo_repository")
load("//hugo/internal:hugo_site.bzl", _hugo_site = "hugo_site", _hugo_serve = "hugo_serve")
load("//hugo/internal:hugo_theme.bzl", _hugo_theme = "hugo_theme")
load("//hugo/internal:github_hugo_theme.bzl", _github_hugo_theme = "github_hugo_theme")
load("//hugo/internal:hugo_site_info.bzl", _HugoSiteInfo = "HugoSiteInfo")
load("//hugo/internal:hugo_site_files.bzl", _hugo_site_files = "hugo_site_files", _process_hugo_site = "process_hugo_site")
load("//hugo/internal:hugo_site_gzip.bzl", _gzip_hugo_site = "gzip_hugo_site")
load("//hugo/internal:hugo_site_brotli.bzl", _brotli_hugo_site = "brotli_hugo_site")
load("//hugo/internal:hugo_site_minify.bzl", _minify_hugo_site = "minify_hugo_site")
load("//hugo/internal:hugo_site_optimize_images.bzl", _optimize_images_hugo_site = "optimize_images_hugo_site")
load("//hugo/internal:hugo_site_critical_css.bzl", _critical_css_hugo_site = "critical_css_hugo_site")

# Core rules
hugo_repository = _hugo_repository
hugo_serve = _hugo_serve
hugo_site = _hugo_site
hugo_theme = _hugo_theme
github_hugo_theme = _github_hugo_theme

# Provider for downstream integration
HugoSiteInfo = _HugoSiteInfo

# Utilities for downstream processing
hugo_site_files = _hugo_site_files
process_hugo_site = _process_hugo_site
gzip_hugo_site = _gzip_hugo_site
brotli_hugo_site = _brotli_hugo_site
minify_hugo_site = _minify_hugo_site
optimize_images_hugo_site = _optimize_images_hugo_site
critical_css_hugo_site = _critical_css_hugo_site
