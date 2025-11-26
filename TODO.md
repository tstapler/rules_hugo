# rules_hugo Development Roadmap

## Recently Completed 

-  Architecture improvements (HugoSiteInfo provider)
-  Downstream integration utilities (gzip_hugo_site, hugo_site_files, process_hugo_site)
-  Comprehensive documentation (DOWNSTREAM_INTEGRATION.md, ARCHITECTURE_REVIEW.md)
-  Architecture review (8.5/10 score)

## Current Focus: Production Optimization Features

Based on user requirements and research into Hugo/static site best practices for 2025.

### Phase 1: MVP Optimization (Current Sprint)

**High-Priority Features** (Universal production needs):

1. **Asset Minification** ’ [docs/tasks/minification.md](docs/tasks/minification.md)
   - Status: = Next up
   - Value: 40-60% size reduction for CSS/JS/HTML
   - Effort: Medium (2-3 days)
   - Follows gzip_hugo_site pattern

2. **Brotli Compression** ’ [docs/tasks/brotli.md](docs/tasks/brotli.md)
   - Status: =Ë Planned
   - Value: 15-25% better compression than gzip
   - Effort: Small (1 day - mirrors gzip pattern)
   - Modern browser support

### Phase 2: Advanced Optimization (Next 2-3 Sprints)

3. **Image Optimization** ’ [docs/tasks/image-optimization.md](docs/tasks/image-optimization.md)
   - Status: =Ë Planned
   - Value: 40-80% size reduction, WebP/AVIF support
   - Effort: Large (1-2 weeks - complex processing)
   - Biggest performance impact

4. **Critical CSS Extraction** ’ [docs/tasks/critical-css.md](docs/tasks/critical-css.md)
   - Status: =Ë Planned
   - Value: Instant above-fold rendering, PageSpeed boost
   - Effort: Medium-Large (1 week - HTML/CSS processing)
   - Core Web Vitals improvement

### Phase 3: Developer Quality Tools (Parallel Work)

5. **Link Checker** ’ [docs/tasks/link-checker.md](docs/tasks/link-checker.md)
   - Status: =Ë Planned
   - Value: Catch broken links pre-deployment
   - Effort: Medium (1 week)

6. **HTML Validation** ’ [docs/tasks/html-validation.md](docs/tasks/html-validation.md)
   - Status: =Ë Planned
   - Value: Ensure HTML5 compliance
   - Effort: Small (3 days)

7. **Accessibility Checker** ’ [docs/tasks/accessibility-checker.md](docs/tasks/accessibility-checker.md)
   - Status: =Ë Planned
   - Value: WCAG compliance validation
   - Effort: Medium (1 week)

8. **Performance Budgets** ’ [docs/tasks/performance-budgets.md](docs/tasks/performance-budgets.md)
   - Status: =Ë Planned
   - Value: Prevent performance regressions
   - Effort: Small (2-3 days)

### Phase 4: Platform Integration (As Needed)

9. **Cloudflare Pages Deployment** ’ [docs/tasks/cloudflare-deploy.md](docs/tasks/cloudflare-deploy.md)
   - Status: =Ë Planned
   - Primary deployment target
   - Generate _headers, _redirects, Workers integration

10. **Nginx Container Optimization** ’ [docs/tasks/nginx-optimization.md](docs/tasks/nginx-optimization.md)
    - Status: =Ë Planned
    - Fallback deployment target
    - Header optimization, caching rules

## Architectural Principles

All new features follow established patterns:

-  Use `HugoSiteInfo` provider for input
-  Return `DefaultInfo` + `OutputGroupInfo`
-  Follow naming: `<verb>_hugo_site` or `hugo_site_<noun>`
-  Export through `hugo/rules.bzl`
-  Include comprehensive docstrings
-  Add integration tests

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

**Recommended**: Start with Task 1.1 from [docs/tasks/minification.md](docs/tasks/minification.md)

**Rationale**:
- Builds directly on `gzip_hugo_site` pattern (proven)
- Universal value (every production deployment needs it)
- Clear scope (3 files, ~2 hours)
- No complex dependencies

**Alternative Options**:
1. Brotli compression (even simpler, 1 file, 1 hour)
2. Performance budgets (independent, quality tool)
3. HTML validation (independent, quality tool)

## Dependencies & Blockers

**None** - All Phase 1 tasks are unblocked and can start immediately.

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

Last Updated: 2025-11-26
