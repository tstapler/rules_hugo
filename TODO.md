# rules_hugo Development Roadmap

## Recently Completed ✅

- ✅ **Bzlmod Migration & CI Stabilization**: Fixed Starlark json loads, Node.js/Puppeteer in CI, theme updates (bzlmod_migration)
- ✅ **Asset Minification**: 45-49% size reduction (minify_hugo_site)
- ✅ **Brotli Compression**: 53% compression ratio (brotli_hugo_site)
- ✅ **Critical CSS Extraction**: 18% inlining (critical_css_hugo_site)
- ✅ **PurgeCSS Integration**: 20-60% CSS reduction (purgecss_hugo_site)
- ✅ **Architecture improvements** (HugoSiteInfo provider)
- ✅ **Downstream integration utilities** (gzip_hugo_site, hugo_site_files, process_hugo_site)
- ✅ **Comprehensive documentation** (DOWNSTREAM_INTEGRATION.md, ARCHITECTURE_REVIEW.md)
- ✅ **CI/CD Setup** (GitHub Actions + Cirrus CI)

## Current Focus: Production Optimization Features

Based on user requirements and research into Hugo/static site best practices for 2025.

### Phase 1: MVP Optimization ✅ COMPLETE

**All High-Priority Features Delivered**:

1. **Asset Minification** ✅ [docs/tasks/minification.md](docs/tasks/minification.md)
    - Status: ✅ COMPLETE (Tasks 1.1-1.5 finished, 45-49% size reduction validated)
    - Value: 40-60% size reduction for CSS/JS/HTML

2. **Brotli Compression** ✅ [docs/tasks/brotli.md](docs/tasks/brotli.md)
    - Status: ✅ COMPLETE (Tasks 1.1-1.4 finished, 53% compression validated)
    - Value: 15-25% better compression than gzip

3. **Critical CSS Extraction** ✅ [docs/tasks/critical-css.md](docs/tasks/critical-css.md)
    - Status: ✅ COMPLETE (Timeout fixed, 18% inlining validated)
    - Value: Core Web Vitals improvement, render-blocking CSS eliminated

4. **PurgeCSS Integration** ✅ NEW
    - Status: ✅ COMPLETE (Rule implemented, 20-60% CSS reduction capability)
    - Value: Unused CSS removal for optimal bundle sizes

### Phase 2: Advanced Optimization (Next 2-3 Sprints)

3. **Image Optimization** ✅ [docs/tasks/image-optimization.md](docs/tasks/image-optimization.md)
   - Status: ✅ Complete
   - Result: 68% PNG, 71% JPG reduction with WebP
   - Implementation: optimize_images_hugo_site rule with hermetic libwebp
   - Completed: 2025-11-28

4. **Critical CSS Extraction**  [docs/tasks/critical-css.md](docs/tasks/critical-css.md)
   - Status: 🔄 In Progress
   - Value: Instant above-fold rendering, PageSpeed boost
   - Effort: Medium-Large (1 week - HTML/CSS processing)
   - Core Web Vitals improvement

### Phase 3: Developer Quality Tools (Parallel Work)

5. **Link Checker**  [docs/tasks/link-checker.md](docs/tasks/link-checker.md)
   - Status: = Planned
   - Value: Catch broken links pre-deployment
   - Effort: Medium (1 week)

6. **HTML Validation**  [docs/tasks/html-validation.md](docs/tasks/html-validation.md)
   - Status: = Planned
   - Value: Ensure HTML5 compliance
   - Effort: Small (3 days)

7. **Accessibility Checker**  [docs/tasks/accessibility-checker.md](docs/tasks/accessibility-checker.md)
   - Status: = Planned
   - Value: WCAG compliance validation
   - Effort: Medium (1 week)

8. **Performance Budgets**  [docs/tasks/performance-budgets.md](docs/tasks/performance-budgets.md)
   - Status: = Planned
   - Value: Prevent performance regressions
   - Effort: Small (2-3 days)

### Phase 4: Platform Integration (As Needed)

9. **Cloudflare Pages Deployment**  [docs/tasks/cloudflare-deploy.md](docs/tasks/cloudflare-deploy.md)
   - Status: = Planned
   - Primary deployment target
   - Generate _headers, _redirects, Workers integration

10. **Nginx Container Optimization**  [docs/tasks/nginx-optimization.md](docs/tasks/nginx-optimization.md)
    - Status: = Planned
    - Fallback deployment target
    - Header optimization, caching rules

## Architectural Principles

All new features follow established patterns:

-   Use `HugoSiteInfo` provider for input
-   Return `DefaultInfo` + `OutputGroupInfo`
-   Follow naming: `<verb>_hugo_site` or `hugo_site_<noun>`
-   Export through `hugo/rules.bzl`
-   Include comprehensive docstrings
-   Add integration tests

## Task Sizing Framework

- **Micro** (1h): Simple utility, clear pattern to follow
- **Small** (2h): Single file, well-defined scope
- **Medium** (3h): 2-3 files, moderate complexity
- **Large** (4h): 3-5 files, complex logic, testing needs

## Context Boundaries

- Maximum 3-5 files per atomic task
- 1-4 hours per task for focused development
- Complete mental model achievable within task scope
- No shared state between parallel tasks

## Next Atomic Task

**Recommended**: Update Documentation for Bzlmod (Task 1.6 from [docs/tasks/bzlmod_migration.md](docs/tasks/bzlmod_migration.md))

**Rationale**:
- CI/Bzlmod migration is technically complete and passing.
- Documentation (README.md) needs to reflect the new Bzlmod usage to ensure users can adopt it.
- This is a low-risk, high-value task to wrap up the migration effort.

**Alternative Options**:
1. Merge `support_bzlmod` PR (Requires user action)
2. Finish Brotli documentation (Task 1.4 from [docs/tasks/brotli.md](docs/tasks/brotli.md))
3. Start Link Checker (Phase 3)

## Dependencies & Blockers

**None** - CI is passing.

## Research References

- [Hugo optimization best practices](https://github.com/spech66/hugo-best-practices)
- [Static site CDN optimization](https://web.dev/articles/image-cdns)
- [Hugo Pipes asset processing](https://gohugo.io/hugo-pipes/)
- [Critical CSS extraction](https://github.com/addyosmani/critical)
- [Image optimization for Jamstack](https://www.smashingmagazine.com/2022/11/guide-image-optimization-jamstack-sites/)

## Success Metrics

Track impact of optimizations:
- **Performance**: Lighthouse score improvements
- **Size**: Bandwidth savings (MB reduced)
- **Quality**: Defects caught pre-deployment
- **Adoption**: Rules used per project

---

Last Updated: 2026-01-11 (Bzlmod migration & CI fixes completed)
