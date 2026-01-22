load("//hugo/internal:github_hugo_theme.bzl", _github_hugo_theme = "github_hugo_theme")
load("//hugo/internal:hugo_repository.bzl", _hugo_repository = "hugo_repository")
load("//hugo/internal:hugo_site.bzl", _hugo_serve = "hugo_serve", _hugo_site = "hugo_site")
load("//hugo/internal:hugo_site_autoprefixer.bzl", _autoprefixer_hugo_site = "autoprefixer_hugo_site")
load("//hugo/internal:hugo_site_brotli.bzl", _brotli_hugo_site = "brotli_hugo_site")
load("//hugo/internal:hugo_site_critical_css.bzl", _critical_css_hugo_site = "critical_css_hugo_site")
load("//hugo/internal:hugo_site_cssnano.bzl", _cssnano_hugo_site = "cssnano_hugo_site")
load("//hugo/internal:hugo_site_files.bzl", _hugo_site_files = "hugo_site_files", _process_hugo_site = "process_hugo_site")
load("//hugo/internal:hugo_site_gzip.bzl", _gzip_hugo_site = "gzip_hugo_site")
load("//hugo/internal:hugo_site_info.bzl", _HugoSiteInfo = "HugoSiteInfo")
load("//hugo/internal:hugo_site_minify.bzl", _minify_hugo_site = "minify_hugo_site")
load("//hugo/internal:hugo_site_optimize_images.bzl", _optimize_images_hugo_site = "optimize_images_hugo_site")
load("//hugo/internal:hugo_site_postcss.bzl", _postcss_hugo_site = "postcss_hugo_site")
load("//hugo/internal:hugo_site_prerender.bzl", _prerender_hugo_site = "prerender_hugo_site")
load("//hugo/internal:hugo_site_purgecss.bzl", _purgecss_hugo_site = "purgecss_hugo_site")
load("//hugo/internal:hugo_site_stylelint.bzl", _stylelint_hugo_site = "stylelint_hugo_site")
load("//hugo/internal:hugo_theme.bzl", _hugo_theme = "hugo_theme")

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
purgecss_hugo_site = _purgecss_hugo_site
postcss_hugo_site = _postcss_hugo_site
autoprefixer_hugo_site = _autoprefixer_hugo_site
cssnano_hugo_site = _cssnano_hugo_site
stylelint_hugo_site = _stylelint_hugo_site
prerender_hugo_site = _prerender_hugo_site
