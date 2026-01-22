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

### Phase 2: Advanced Optimization ✅ COMPLETE

3. **Image Optimization** ✅ [docs/tasks/image-optimization.md](docs/tasks/image-optimization.md)
   - Status: ✅ Complete (75% complete - documentation pending)
   - Result: 68% PNG, 71% JPG reduction with WebP
   - Implementation: optimize_images_hugo_site rule with hermetic libwebp
   - Completed: 2025-11-28
   - Next: Complete Task 1.4 - Update Documentation (1h)

4. **Critical CSS Extraction** ✅ [docs/tasks/critical-css.md](docs/tasks/critical-css.md)
   - Status: ✅ COMPLETE (All Tasks 1.1-1.4 finished, timeout fixed)
   - Value: Instant above-fold rendering, PageSpeed boost
   - Result: 18% CSS inlining validated
   - Effort: Completed in 2 sprints with timeout resolution

### Phase 3: Developer Quality Tools ✅ DOCUMENTED (Ready for Implementation)

**All Quality Tool Epics Fully Documented with Atomic Tasks**:

5. **Link Checker** ✅ [docs/tasks/link-checker.md](docs/tasks/link-checker.md)
   - Status: ✅ DOCUMENTED (Tasks 1.1-1.4 planned, 12h total)
   - Value: Catch broken links pre-deployment
   - Effort: Medium (1 week)
   - Next: Task 1.1 - Create Link Checker Rule Structure (4h)

6. **HTML Validation** ✅ [docs/tasks/html-validation.md](docs/tasks/html-validation.md)
   - Status: ✅ DOCUMENTED (Tasks 1.1-1.4 planned, 11h total)
   - Value: Ensure HTML5 compliance
   - Effort: Small (3 days)
   - Next: Task 1.1 - Create HTML Validator Rule Structure (3h)

7. **Accessibility Checker** ✅ [docs/tasks/accessibility-checker.md](docs/tasks/accessibility-checker.md)
   - Status: ✅ DOCUMENTED (Tasks 1.1-1.4 planned, 12h total)
   - Value: WCAG compliance validation
   - Effort: Medium (1 week)
   - Next: Task 1.1 - Create Accessibility Checker Rule Structure (4h)

8. **Performance Budgets** ✅ [docs/tasks/performance-budgets.md](docs/tasks/performance-budgets.md)
   - Status: ✅ DOCUMENTED (Tasks 1.1-1.4 planned, 10h total)
   - Value: Prevent performance regressions
   - Effort: Small (2-3 days)
   - Next: Task 1.1 - Create Performance Budget Rule Structure (3h)

### Phase 4: Platform Integration (As Needed)

9. **Cloudflare Pages Deployment** 📋 [docs/tasks/cloudflare-deploy.md](docs/tasks/cloudflare-deploy.md)
   - Status: 📋 Planned (Documentation needed)
   - Primary deployment target
   - Generate _headers, _redirects, Workers integration

10. **Nginx Container Optimization** 📋 [docs/tasks/nginx-optimization.md](docs/tasks/nginx-optimization.md)
    - Status: 📋 Planned (Documentation needed)
    - Fallback deployment target
    - Header optimization, caching rules

## Current Implementation Status Summary

### Completed Features ✅
- **Asset Minification**: 45-49% size reduction achieved
- **Brotli Compression**: 53% compression ratio achieved
- **Critical CSS Extraction**: 18% inlining achieved with timeout fix
- **PurgeCSS Integration**: 20-60% CSS reduction capability
- **Image Optimization**: 68-71% size reduction achieved, documentation pending

### Documented & Ready for Implementation 📋
- **Link Checker**: Full atomic task breakdown (4 tasks, 12h)
- **HTML Validation**: Full atomic task breakdown (4 tasks, 11h)  
- **Accessibility Checker**: Full atomic task breakdown (4 tasks, 12h)
- **Performance Budgets**: Full atomic task breakdown (4 tasks, 10h)

### Outstanding Work Items 🔧
1. **Complete Image Optimization Documentation** (1h)
2. **Start Phase 3 Implementation** (45h total across 4 epics)

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

**Recommended**: Complete Image Optimization Documentation

**Rationale**:
- Image optimization is 75% complete with working implementation
- Only documentation (Task 1.4, 1h) remains
- Low-effort completion that closes Phase 2
- Clears way for Phase 3 implementation

**Alternative Options**:
1. Start Link Checker Implementation (Task 1.1, 4h) - Begin Phase 3
2. Start HTML Validation (Task 1.1, 3h) - Smaller Phase 3 start
3. Complete any pending integration tests from Phase 2

## Dependencies & Blockers

**None** - All completed features are passing tests. Phase 3 is ready for implementation.

## Bug Status

🐛 **No known critical or high-severity bugs**

- All integration tests passing
- No reported issues in current implementation
- Phase 3 features are documented but not yet implemented

## Research References

- [Hugo optimization best practices](https://github.com/spech66/hugo-best-practices)
- [Static site CDN optimization](https://web.dev/articles/image-cdns)
- [Hugo Pipes asset processing](https://gohugo.io/hugo-pipes/)
- [Critical CSS extraction](https://github.com/addyosmani/critical)
- [Image optimization for Jamstack](https://www.smashingmagazine.com/2022/11/guide-image-optimization-jamstack-sites/)
- [WCAG 2.1 Guidelines](https://www.w3.org/TR/WCAG21/)
- [axe-core accessibility testing](https://github.com/dequelabs/axe-core)
- [Performance budgeting](https://web.dev/performance-budgeting-101/)

## Success Metrics

Track impact of optimizations:
- **Performance**: Lighthouse score improvements
- **Size**: Bandwidth savings (MB reduced)
- **Quality**: Defects caught pre-deployment
- **Adoption**: Rules used per project

---

Last Updated: 2026-01-21 (Phase 3 documentation complete, ready for implementation)
