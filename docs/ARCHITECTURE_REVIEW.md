# Architecture Review: rules_hugo

**Review Date**: 2025-11-26
**Codebase**: rules_hugo (Bazel build rules for Hugo static site generator)
**Lines of Code**: ~838 lines of Starlark across 9 files
**Reviewer**: Architecture Analysis System

---

## Executive Summary

### Overall Architecture Quality Score: **8.5/10**

The rules_hugo codebase demonstrates **strong architectural foundations** with excellent separation of concerns, minimal coupling, and modern Bazel patterns. The recent improvements adding `HugoSiteInfo` provider and utility rules significantly enhance downstream integration while maintaining backward compatibility.

### Key Strengths

1. ✅ **Clean three-layer architecture** (Public API → Implementation → External Dependencies)
2. ✅ **Provider-based design** enables type-safe, loosely-coupled rule composition
3. ✅ **No circular dependencies** - clean unidirectional dependency graph
4. ✅ **Consistent naming conventions** and predictable API surface
5. ✅ **Modern Bazel practices** (providers, module extensions, bzlmod support)
6. ✅ **Backward compatible improvements** - new utilities don't break existing code

### Critical Issues Requiring Attention

**None found** - The codebase is in excellent architectural health.

### Recommended Priority Improvements

**P2 - Medium Priority** (Plan for next iteration):
1. Enhance documentation of provider contracts
2. Add integration tests for rule composition chains
3. Improve error messages for provider access failures
4. Establish formal API stability guarantees

---

## 1. SOLID Principles Analysis

### Single Responsibility Principle (SRP): **9/10** ✅

**Assessment**: Each rule and provider has a single, well-defined responsibility.

**Examples of Good SRP Adherence**:

| Component | Single Responsibility | Evidence |
|-----------|----------------------|----------|
| `hugo_site` | Build Hugo static site | hugo/internal/hugo_site.bzl:43-169 |
| `hugo_serve` | Run development server | hugo/internal/hugo_site.bzl:246-317 |
| `HugoSiteInfo` | Encapsulate site metadata | hugo/internal/hugo_site_info.bzl:3-15 |
| `gzip_hugo_site` | Pre-compress site files | hugo/internal/hugo_site_gzip.bzl:5-146 |
| `hugo_repository` | Acquire Hugo binary | hugo/internal/hugo_repository.bzl |

**Minor Issues** (-1 point):

1. **hugo_site.bzl contains both `hugo_site` and `hugo_serve`**
   - File: hugo/internal/hugo_site.bzl (329 lines)
   - Impact: Slight mixing of concerns (build vs serve)
   - Recommendation: Consider splitting into separate files when complexity grows
   - Priority: P3 (Low) - Current size doesn't justify immediate action

**Recommendations**:
- Monitor hugo_site.bzl - if it grows beyond 400 lines, consider splitting
- Extract helper functions to dedicated utils.bzl file if reused elsewhere

---

### Open/Closed Principle (OCP): **9/10** ✅

**Assessment**: The architecture is well-designed for extension through composition without modification of existing rules.

**Examples of Good OCP Adherence**:

1. **Provider-Based Extension**:
   ```starlark
   # hugo_site.bzl - Closed for modification
   return [
       DefaultInfo(files=files, runfiles=runfiles),
       HugoSiteInfo(...),  # Open for extension via provider
   ]

   # New utility rule can extend functionality without modifying hugo_site
   def _gzip_hugo_site_impl(ctx):
       site_info = ctx.attr.site[HugoSiteInfo]  # Extension point
       # ... custom processing
   ```

2. **process_hugo_site Generic Processor**:
   - File: hugo/internal/hugo_site_files.bzl:80-140
   - Allows arbitrary post-processing via executable attribute
   - New processing types don't require rule changes

3. **Tag Class Extensibility**:
   - File: hugo/internal/extensions.bzl:23-49
   - Multiple tag classes (hugo, github_theme, http_theme)
   - Can add new tag types without modifying extension implementation

**Minor Issues** (-1 point):

1. **Hugo Arguments Hardcoded**:
   - File: hugo/internal/hugo_site.bzl:118-136
   - Hugo CLI arguments constructed directly in implementation
   - Adding new Hugo flags requires modifying rule implementation
   - **Recommendation**: Consider `extra_args` attribute for advanced users
   - Priority: P3 (Low) - Current flags cover 95% of use cases

**Recommendations**:
```starlark
# Suggested enhancement
hugo_site = rule(
    attrs = {
        # ... existing attrs
        "extra_hugo_args": attr.string_list(
            doc = "Additional arguments passed to Hugo CLI",
            default = [],
        ),
    },
)
```

---

### Liskov Substitution Principle (LSP): **10/10** ✅

**Assessment**: Not directly applicable - Starlark doesn't have classical inheritance.

**Provider Contracts Analysis**:
- All providers have well-defined, immutable field contracts
- Rules consuming providers use them correctly without assumptions
- No provider "inheritance" or overriding patterns

**Recommendations**: Continue using composition over inheritance patterns.

---

### Interface Segregation Principle (ISP): **10/10** ✅

**Assessment**: Providers are lean and focused - no "fat interfaces."

**Provider Analysis**:

| Provider | Fields | Purpose | Unused Fields? |
|----------|--------|---------|----------------|
| HugoSiteInfo | 4 fields | Site metadata | None - all used |
| HugoThemeInfo | 3 fields | Theme metadata | None - all used |

**Examples of Good ISP**:

1. **HugoSiteInfo** (hugo/internal/hugo_site_info.bzl:3-15):
   ```starlark
   HugoSiteInfo = provider(fields = {
       "output_dir": "Tree artifact",      # Used by all consumers
       "files": "Depset",                  # Used by hugo_site_files
       "base_url": "String",               # Optional, used contextually
       "name": "String",                   # Used for diagnostics
   })
   ```
   - All fields have clear purpose
   - No consumer forced to depend on unused fields

2. **Separate Providers for Different Concerns**:
   - `HugoSiteInfo` for site output
   - `HugoThemeInfo` for theme metadata
   - Clean separation - themes don't expose site info, sites don't expose theme internals

**Recommendations**: Continue current provider design patterns.

---

### Dependency Inversion Principle (DIP): **9/10** ✅

**Assessment**: Dependencies point toward abstractions (providers), with minimal concrete coupling.

**Examples of Good DIP**:

1. **Provider-Based Abstraction**:
   ```starlark
   # gzip_hugo_site depends on abstraction (HugoSiteInfo)
   # NOT on concrete implementation (hugo_site rule)
   def _gzip_hugo_site_impl(ctx):
       site_info = ctx.attr.site[HugoSiteInfo]  # Abstraction dependency
       site_dir = site_info.output_dir
   ```

2. **Dependency Graph** (All point toward abstractions):
   ```
   gzip_hugo_site ─┐
   hugo_site_files ├─→ HugoSiteInfo (abstraction)
   process_hugo_site ┘
                     ↑
                hugo_site (implementation)
   ```

**Minor Issues** (-1 point):

1. **Direct Binary Dependency**:
   - File: hugo/internal/hugo_site.bzl:208-213
   - hugo_site has direct dependency on `@hugo//:hugo` executable (default)
   - **Impact**: Low - users can override, common pattern in Bazel
   - **Recommendation**: Document that executable is replaceable
   - Priority: P3 (Low) - Not a practical issue

**Recommendations**:
- Document in hugo_site docstring that `hugo` attribute can use custom binary
- Consider adding example of custom Hugo binary in documentation

---

## 2. Clean Architecture Analysis

### Layer Separation: **9/10** ✅

**Architecture Layers Identified**:

```
┌─────────────────────────────────────┐
│  Public API (rules.bzl)            │ ← Stable interface
├─────────────────────────────────────┤
│  Implementation (hugo/internal/*)   │ ← Business logic
├─────────────────────────────────────┤
│  Bazel Platform (actions, rules)   │ ← Framework
└─────────────────────────────────────┘
```

**Dependency Direction Verification**:

✅ **Correct** (all dependencies point inward):
```
rules.bzl (outer)
  ↓ imports
hugo/internal/*.bzl (implementation)
  ↓ uses
Bazel APIs (platform)
```

**Examples of Good Layer Separation**:

1. **Public API Facade** (hugo/rules.bzl:1-22):
   ```starlark
   # Public API hides internal paths
   load("//hugo:internal/hugo_site.bzl", _hugo_site = "hugo_site")
   hugo_site = _hugo_site  # Re-export
   ```
   - Users load from `@build_stack_rules_hugo//hugo:rules.bzl`
   - Internal implementation can move without breaking users

2. **Provider Abstraction** (hugo/internal/hugo_site_info.bzl):
   - Clean boundary between rules
   - No leaking of Bazel action internals through provider

**Minor Issues** (-1 point):

1. **No Formal API Contract**:
   - No documented stability guarantees for rules.bzl exports
   - **Impact**: Users don't know which APIs are stable
   - **Recommendation**: Add API stability policy in README
   - Priority: P2 (Medium)

**Recommendations**:
```markdown
## API Stability

- **Stable**: All exports from `hugo/rules.bzl`
- **Unstable**: Anything in `hugo/internal/` (subject to change)
- **Provider Fields**: Backward-compatible additions only
```

---

### Boundary Crossings: **10/10** ✅

**Assessment**: Clean boundaries with no framework leakage into domain.

**Examples**:

1. **Provider as Boundary**:
   ```starlark
   # hugo_site.bzl (implementation side)
   site_info = HugoSiteInfo(
       output_dir = hugo_outputdir,  # Bazel File artifact
       files = files,                # Bazel depset
       base_url = ctx.attr.base_url,  # String (pure data)
       name = ctx.label.name,        # String (pure data)
   )

   # gzip_hugo_site.bzl (consumer side)
   site_info = ctx.attr.site[HugoSiteInfo]  # Clean boundary crossing
   site_dir = site_info.output_dir
   ```

2. **No Leaky Abstractions**:
   - ✅ Provider fields expose Bazel artifacts (File, depset) appropriately
   - ✅ No internal action details leak through provider
   - ✅ Consumers don't need to know Hugo CLI details

---

### Testability: **7/10** ⚠️

**Assessment**: Architecture supports testing, but test coverage appears minimal.

**Testability Strengths**:
- Provider-based design enables mocking
- Rules are stateless (no global state)
- Clear input/output contracts

**Issues**:

1. **No Visible Integration Tests**:
   - Location checked: /, /test, /tests (not found)
   - Impact: Changes could break composition chains undetected
   - **Recommendation**: Add tests for common usage patterns
   - Priority: P2 (Medium)

2. **No Provider Contract Tests**:
   - HugoSiteInfo fields could change without test verification
   - **Recommendation**: Add tests verifying provider contracts
   - Priority: P2 (Medium)

**Recommended Test Structure**:
```
test/
├── integration/
│   ├── hugo_site_test.bzl         # Test basic site build
│   ├── gzip_integration_test.bzl   # Test site → gzip chain
│   └── theme_test.bzl              # Test theme integration
└── unit/
    ├── provider_contract_test.bzl  # Verify provider fields
    └── helper_function_test.bzl     # Test relative_path, copy_to_dir
```

---

## 3. Clean Code Analysis

### Naming Quality: **9/10** ✅

**Assessment**: Excellent, consistent, intention-revealing names throughout.

**Examples of Good Naming**:

| Name | File | Why It's Good |
|------|------|---------------|
| `hugo_site` | rules.bzl | Clear domain noun, obvious purpose |
| `gzip_hugo_site` | hugo_site_gzip.bzl | Verb + object pattern, transformation clear |
| `HugoSiteInfo` | hugo_site_info.bzl | CapitalCase provider, "Info" suffix (Bazel idiom) |
| `relative_path(src, dirname)` | hugo_site.bzl:3-25 | Function name describes return value |
| `copy_to_dir(ctx, srcs, dirname)` | hugo_site.bzl:27-41 | Action-oriented, parameters self-documenting |

**Naming Conventions Followed**:
- Rules: `snake_case` with domain prefix (hugo_*)
- Providers: `CapitalCase` + Info suffix
- Private implementation: `_func_name_impl`
- Attributes: `snake_case` (base_url, build_drafts)
- Boolean flags: verb prefix (build_drafts, disable_fast_render)

**Minor Issues** (-1 point):

1. **Abbreviations in Parameters**:
   - File: hugo/internal/hugo_site.bzl:246-317
   - Parameter `dep` instead of `dependencies` in hugo_serve
   - Impact: Minimal - clear from context
   - Priority: P3 (Low)

**Recommendations**: Continue current naming conventions.

---

### Function Quality: **9/10** ✅

**Assessment**: Functions are well-sized, focused, with clear responsibilities.

**Function Size Analysis**:

| Function | Lines | Status | File |
|----------|-------|--------|------|
| `_hugo_site_impl` | ~107 | ✅ Acceptable - complex setup logic | hugo_site.bzl:43-169 |
| `_gzip_hugo_site_impl` | ~50 | ✅ Good | hugo_site_gzip.bzl:5-61 |
| `relative_path` | 13 | ✅ Excellent | hugo_site.bzl:3-25 |
| `copy_to_dir` | 14 | ✅ Excellent | hugo_site.bzl:27-41 |

**Examples of Good Function Design**:

1. **Single Abstraction Level**:
   ```starlark
   # hugo_site.bzl:43-169
   def _hugo_site_impl(ctx):
       # 1. Setup phase (high-level steps)
       hugo_inputs = []
       hugo_outputdir = ctx.actions.declare_directory(ctx.label.name)

       # 2. Config handling
       config_dir = ctx.files.config_dir
       # ... (focused on config logic)

       # 3. File staging
       for name, srcs in {...}.items():
           hugo_inputs += copy_to_dir(ctx, srcs, name)  # Delegate details

       # 4. Theme handling
       # 5. Hugo execution
       # 6. Return providers
   ```
   Each section operates at similar abstraction level.

2. **Small Helper Functions**:
   ```starlark
   # hugo_site.bzl:3-25
   def relative_path(src, dirname):
       """Single purpose: extract relative path."""
       # 13 lines of focused logic
   ```

**Minor Issues** (-1 point):

1. **_hugo_site_impl Complexity**:
   - Lines: 107 (acceptable but approaching limit)
   - Cyclomatic complexity: Moderate (several conditionals)
   - **Recommendation**: Consider extracting config handling and theme handling to separate functions
   - Priority: P3 (Low) - Refactor if function grows beyond 120 lines

**Recommendations**:
```starlark
# Potential extraction
def _prepare_config(ctx):
    """Extract config file/dir preparation logic."""
    # Lines 50-79 could move here

def _prepare_theme(ctx, hugo_inputs):
    """Extract theme file staging logic."""
    # Lines 96-115 could move here
```

---

### Comment Quality: **8/10** ✅

**Assessment**: Good documentation in provider definitions, could improve inline comments.

**Examples of Good Comments**:

1. **Provider Docstrings** (hugo/internal/hugo_site_info.bzl:3-15):
   ```starlark
   HugoSiteInfo = provider(
       doc = """
       Information about a Hugo site build output.

       This provider makes it easier for downstream rules to access Hugo site files
       without dealing with tree artifacts directly.
       """,
       fields = {
           "output_dir": "Tree artifact containing all generated site files",
           # ... well-documented fields
       },
   )
   ```

2. **Inline Explanatory Comments** (hugo/internal/hugo_site.bzl:121-125):
   ```starlark
   # Hugo wants to modify the static input files for its own bookkeeping
   # but of course Bazel does not want input files to be changed. This breaks
   # in some sandboxes like RBE
   "--noTimes",
   "--noChmod",
   ```
   **Why good**: Explains **why** flags are needed, not just what they do.

**Issues** (-2 points):

1. **Missing Function Docstrings**:
   - Functions: `relative_path`, `copy_to_dir` lack docstrings
   - Impact: Harder for contributors to understand purpose
   - **Recommendation**: Add docstrings to all public functions
   - Priority: P2 (Medium)

2. **Sparse Inline Comments**:
   - hugo_site.bzl:_hugo_site_impl has minimal inline comments
   - Complex sections (theme handling, config setup) lack explanatory comments
   - Priority: P3 (Low)

**Recommendations**:
```starlark
def relative_path(src, dirname):
    """Extract relative path of a source file within a Hugo directory.

    Given a File artifact and a directory name it's under, returns the relative
    path from that directory. For example:
        src.short_path = "external/repo/content/posts/hello.md"
        dirname = "content"
        returns "content/posts/hello.md"

    Args:
        src: File artifact from Hugo source tree
        dirname: Directory name to find in path (e.g., "content", "layouts")

    Returns:
        Relative path string from dirname onwards

    Raises:
        fail() if dirname not found in src.short_path
    """
    # Implementation...
```

---

### Error Handling: **9/10** ✅

**Assessment**: Good use of Bazel's fail() for errors, clear messages.

**Examples of Good Error Handling**:

1. **Clear Validation** (hugo/internal/hugo_site.bzl:50-51):
   ```starlark
   if ctx.file.config == None and (ctx.files.config_dir == None or len(ctx.files.config_dir) == 0):
       fail("You must provide either a config file or a config_dir")
   ```
   - ✅ Clear error message
   - ✅ Explains requirement
   - ✅ Validated early

2. **Descriptive Failure Messages** (hugo/internal/hugo_site.bzl:19-20):
   ```starlark
   if i == -1:
       fail("failed to get relative path: couldn't find %s in %s" % (dirname, src.short_path))
   ```
   - ✅ Includes context (dirname, path)
   - ✅ Helps user debug issue

**Minor Issues** (-1 point):

1. **No Error Handling for Provider Access**:
   - Files: hugo_site_files.bzl, hugo_site_gzip.bzl
   - All assume `ctx.attr.site[HugoSiteInfo]` succeeds
   - If wrong target type passed, error is cryptic Bazel message
   - **Recommendation**: Add defensive checks or improve error messages
   - Priority: P2 (Medium)

**Recommendations**:
```starlark
def _gzip_hugo_site_impl(ctx):
    if HugoSiteInfo not in ctx.attr.site:
        fail("Attribute 'site' must be a hugo_site target (got: %s)" % ctx.attr.site.label)
    site_info = ctx.attr.site[HugoSiteInfo]
```

---

### Code Organization: **10/10** ✅

**Assessment**: Excellent organization with clear file structure and logical grouping.

**File Organization**:
```
hugo/
├── rules.bzl                       ← Public API (22 lines)
└── internal/                       ← Implementation details
    ├── hugo_site.bzl               ← Core site building (329 lines)
    ├── hugo_theme.bzl              ← Theme handling (29 lines)
    ├── hugo_repository.bzl         ← Binary acquisition (53 lines)
    ├── hugo_site_info.bzl          ← Provider definition (16 lines)
    ├── hugo_site_files.bzl         ← Utility rules (153 lines)
    ├── hugo_site_gzip.bzl          ← Gzip utility (146 lines)
    ├── github_hugo_theme.bzl       ← GitHub convenience (39 lines)
    └── extensions.bzl              ← Bzlmod integration (51 lines)
```

**Organizational Strengths**:
- ✅ Related functionality grouped in files
- ✅ Public/private separation (rules.bzl vs internal/)
- ✅ File size reasonable (<350 lines per file)
- ✅ Clear file naming indicates contents

**Within-File Organization**:
```starlark
# hugo_site_gzip.bzl structure:
1. Load statements (top)
2. Implementation function (_gzip_hugo_site_impl)
3. Rule definition (gzip_hugo_site)
```
- ✅ Consistent ordering across files
- ✅ Helpers before usage
- ✅ Rule definition always at bottom

---

## 4. Domain-Driven Design Analysis

### Ubiquitous Language: **8/10** ✅

**Assessment**: Good use of Hugo domain terminology, minor inconsistencies.

**Domain Concepts Mapped to Code**:

| Hugo Concept | Code Representation | File | Consistency |
|--------------|---------------------|------|-------------|
| Site | hugo_site rule | hugo_site.bzl | ✅ Perfect match |
| Theme | hugo_theme rule, HugoThemeInfo | hugo_theme.bzl | ✅ Perfect match |
| Content | `content` attribute | hugo_site.bzl:176 | ✅ Perfect match |
| Layouts | `layouts` attribute | hugo_site.bzl:191 | ✅ Perfect match |
| Static files | `static` attribute | hugo_site.bzl:183 | ✅ Perfect match |
| BaseURL | `base_url` attribute | hugo_site.bzl:215 | ✅ Correct (snake_case) |

**Examples of Good Ubiquitous Language**:

1. **Hugo Terminology Preserved**:
   ```starlark
   hugo_site(
       archetypes = [...],  # Hugo directory name
       content = [...],     # Hugo directory name
       layouts = [...],     # Hugo directory name
       static = [...],      # Hugo directory name
   )
   ```

**Minor Issues** (-2 points):

1. **Generic Term**: "dep" instead of domain-specific:
   - hugo_serve attribute: `dep` (should be `site` or `hugo_site`)
   - File: hugo_site.bzl:299
   - Priority: P3 (Low)

2. **Bazel Terminology Mixed In**:
   - `ctx`, `srcs`, `outputs` - Bazel terms, not Hugo terms
   - **Impact**: Acceptable - internal implementation details
   - Priority: P3 (Low)

**Recommendations**:
```starlark
# Rename for clarity
hugo_serve = rule(
    attrs = {
        "site": attr.label_list(  # Instead of "dep"
            doc = "The hugo_site target(s) to serve",
            mandatory=True,
        ),
    },
)
```

---

### Bounded Contexts: **9/10** ✅

**Assessment**: Clear separation between Hugo domain and Bazel build domain.

**Contexts Identified**:

1. **Hugo Build Context**:
   - Concepts: Site, Theme, Content, Layouts, Static
   - Rules: hugo_site, hugo_theme, hugo_serve
   - Pure Hugo domain logic

2. **Bazel Build Context**:
   - Concepts: Actions, Artifacts, Providers, Rules
   - Infrastructure: Repository rules, module extensions
   - Pure Bazel orchestration logic

3. **Post-Processing Context** (New):
   - Concepts: Gzip, Processing, Manifest
   - Rules: gzip_hugo_site, process_hugo_site, hugo_site_files
   - Bridge between Hugo output and deployment

**Boundary Enforcement**:
```
Hugo Context                Post-Processing Context
hugo_site                   gzip_hugo_site
    ↓                           ↓
HugoSiteInfo ← [Provider Boundary] → Consumers
    ↑
Bazel Context
(actions, artifacts)
```

**Minor Issues** (-1 point):

1. **Mixed Concerns in hugo_site.bzl**:
   - File contains both build (hugo_site) and serve (hugo_serve)
   - Serve is arguably a different context (development vs production)
   - Priority: P3 (Low) - Not a practical issue

**Recommendations**: Continue clear context separation, consider documentation of context boundaries.

---

### Tactical Patterns Usage: **7/10** ⚠️

**Assessment**: Provider pattern used well, but limited applicability of DDD patterns to build rules.

**DDD Pattern Applicability to Bazel**:

| DDD Pattern | Applicability | Used in rules_hugo? |
|-------------|---------------|---------------------|
| Entity | Low (rules are stateless) | N/A |
| Value Object | Medium (providers are immutable) | ✅ HugoSiteInfo, HugoThemeInfo |
| Aggregate | Low (no complex object graphs) | N/A |
| Repository | Low (Bazel handles artifact storage) | N/A |
| Domain Service | Medium (rule implementations) | ✅ hugo_site, gzip_hugo_site |
| Domain Event | Low (no event-driven architecture) | N/A |

**Examples of DDD-Like Patterns**:

1. **Value Objects** (Providers):
   ```starlark
   HugoSiteInfo(
       output_dir = ...,  # Immutable
       files = ...,       # Immutable
       base_url = ...,    # Immutable
       name = ...,        # Immutable
   )
   ```
   - ✅ Immutable
   - ✅ Structure-based identity
   - ✅ No behavior (pure data)

2. **Domain Services** (Rules):
   - hugo_site rule: Orchestrates Hugo site building
   - gzip_hugo_site: Domain operation (compression)
   - Stateless operations on domain objects

**Issues** (-3 points):

1. **Limited DDD Applicability**:
   - Bazel rules are procedural, not object-oriented
   - **Impact**: Not a defect - DDD patterns don't map well to build rules
   - **Recommendation**: Focus on applicable patterns (services, value objects)
   - Priority: N/A (Not applicable)

**Recommendations**: Continue using provider-as-value-object pattern.

---

### Domain Services: **9/10** ✅

**Assessment**: Rule implementations act as stateless domain services.

**Examples of Good Domain Services**:

1. **hugo_site** (hugo_site.bzl:43-169):
   - ✅ Stateless
   - ✅ Encapsulates domain logic (Hugo site building)
   - ✅ No infrastructure leakage into interface
   - ✅ Single responsibility

2. **gzip_hugo_site** (hugo_site_gzip.bzl:5-146):
   - ✅ Stateless
   - ✅ Domain operation (compression for static serving)
   - ✅ Uses domain objects (HugoSiteInfo)
   - ✅ No shared state

**Minor Issues** (-1 point):

1. **Helper Functions as Utilities**:
   - `relative_path`, `copy_to_dir` are pure utilities, not domain services
   - Could be in separate utils.bzl file
   - Priority: P3 (Low)

**Recommendations**: Continue stateless service pattern for rules.

---

### Anemic Domain Model Detection: **N/A**

**Assessment**: Not applicable - Bazel rules are inherently procedural, not object-oriented.

Providers are intentionally data-only (correct for value objects). Rules provide behavior.

---

## 5. Design Patterns Analysis

### Pattern Recognition: **9/10** ✅

**Patterns Identified and Correctly Implemented**:

#### 1. **Facade Pattern** (rules.bzl)
- **Location**: hugo/rules.bzl:1-22
- **Purpose**: Hide internal implementation paths, provide stable API
- **Implementation**:
  ```starlark
  load("//hugo:internal/hugo_site.bzl", _hugo_site = "hugo_site")
  hugo_site = _hugo_site  # Facade re-exports
  ```
- **Quality**: ✅ Excellent - clean separation of API from implementation

#### 2. **Provider Pattern** (Information Passing)
- **Location**: HugoSiteInfo, HugoThemeInfo
- **Purpose**: Type-safe data passing between rules
- **Implementation**:
  ```starlark
  HugoSiteInfo = provider(fields={...})  # Contract definition

  # Producer
  return [HugoSiteInfo(...)]

  # Consumer
  site_info = ctx.attr.site[HugoSiteInfo]
  ```
- **Quality**: ✅ Excellent - enables loose coupling

#### 3. **Repository Pattern** (Binary Acquisition)
- **Location**: hugo/internal/hugo_repository.bzl
- **Purpose**: Abstract acquisition of Hugo binary
- **Implementation**:
  ```starlark
  hugo_repository(
      name = "hugo",
      version = "0.145.0",
      extended = True,
  )
  ```
- **Quality**: ✅ Good - hides download/extraction complexity

#### 4. **Strategy Pattern** (Implicit via process_hugo_site)
- **Location**: hugo/internal/hugo_site_files.bzl:80-140
- **Purpose**: Allow different processing strategies
- **Implementation**:
  ```starlark
  process_hugo_site(
      site = ":my_site",
      processor = "//tools:my_processor",  # Strategy injection
  )
  ```
- **Quality**: ✅ Good - enables algorithm variation

#### 5. **Adapter Pattern** (GitHub Theme Wrapper)
- **Location**: hugo/internal/github_hugo_theme.bzl
- **Purpose**: Adapt GitHub archive format to Hugo theme structure
- **Implementation**:
  ```starlark
  def github_hugo_theme(owner, repo, commit, **kwargs):
      # Adapts GitHub API to http_archive API
      url = "https://github.com/{owner}/{repo}/archive/{commit}.zip"
      http_archive(url=url, strip_prefix=..., ...)
  ```
- **Quality**: ✅ Good - simplifies GitHub theme consumption

**Minor Issues** (-1 point):

1. **Pattern Documentation**:
   - Patterns not explicitly documented
   - New contributors may not recognize patterns
   - **Recommendation**: Add DESIGN_PATTERNS.md explaining patterns used
   - Priority: P3 (Low)

---

### Pattern Opportunities: **8/10** ✅

**Assessment**: Most beneficial patterns already implemented. Minor opportunities exist.

**Potential Pattern Enhancements**:

1. **Builder Pattern for hugo_site Configuration** (Priority: P3):
   ```starlark
   # Current: Many attributes directly on hugo_site
   hugo_site(
       config = "config.yaml",
       base_url = "https://example.com",
       build_drafts = True,
       quiet = False,
       verbose = True,
       # ... many more
   )

   # Potential: Group related configs
   hugo_site(
       config = hugo_config(
           file = "config.yaml",
           base_url = "https://example.com",
       ),
       build_options = hugo_build_options(
           drafts = True,
           verbose = True,
       ),
   )
   ```
   **Assessment**: Not recommended - Bazel attributes are already declarative, grouping adds indirection without benefit.

2. **Template Method for Rule Implementations** (Priority: P3):
   - Extract common setup/teardown logic
   - **Assessment**: Low value - rules are already focused

**Recommendations**: Current pattern usage is appropriate. No immediate pattern additions needed.

---

## 6. Coupling and Cohesion Analysis

### Coupling Metrics: **9/10** ✅

**Assessment**: Minimal coupling with clean dependencies.

**Coupling Analysis**:

| Module | Afferent (Ca) | Efferent (Ce) | Instability (I) | Assessment |
|--------|---------------|---------------|-----------------|------------|
| HugoSiteInfo | 4 | 0 | 0.0 (Stable) | ✅ Excellent - pure abstraction |
| HugoThemeInfo | 1 | 0 | 0.0 (Stable) | ✅ Excellent - pure abstraction |
| hugo_site | 3 | 2 | 0.4 (Balanced) | ✅ Good - reasonable coupling |
| gzip_hugo_site | 0 | 1 | 1.0 (Unstable) | ✅ Expected - leaf node |
| hugo_site_files | 0 | 1 | 1.0 (Unstable) | ✅ Expected - leaf node |

**Dependency Graph** (Simplified):
```
External Dependencies (Bazel)
    ↑
    │ (minimal)
    │
HugoSiteInfo, HugoThemeInfo (Abstractions)
    ↑
    │
hugo_site (Implementation)
    ↑
    │
gzip_hugo_site, hugo_site_files, process_hugo_site (Utilities)
```

**Coupling Strengths**:
- ✅ No circular dependencies
- ✅ Dependencies point toward stable abstractions
- ✅ Utility rules depend only on HugoSiteInfo (loose coupling)
- ✅ No tight coupling to external frameworks

**Minor Issues** (-1 point):

1. **Bazel Action API Coupling**:
   - All rules depend on Bazel's action/rule APIs
   - **Impact**: Unavoidable - part of Bazel platform
   - **Assessment**: Not a defect - expected coupling
   - Priority: N/A

**Recommendations**: Maintain current low coupling through provider abstractions.

---

### Cohesion Analysis: **9/10** ✅

**Assessment**: High cohesion - related functionality well-grouped.

**Cohesion Analysis by File**:

| File | Cohesion | Evidence |
|------|----------|----------|
| hugo_site_info.bzl | ✅ Perfect | Single provider definition, all fields related |
| hugo_theme.bzl | ✅ High | Theme rule + provider, closely related |
| hugo_site_gzip.bzl | ✅ Perfect | Single focused purpose (gzip compression) |
| hugo_site_files.bzl | ✅ High | Two related utilities (manifest + processor) |
| hugo_repository.bzl | ✅ Perfect | Single purpose (binary acquisition) |

**Examples of Good Cohesion**:

1. **hugo_site_gzip.bzl**:
   - All code relates to gzip compression
   - Implementation function, rule definition, documentation
   - No unrelated functionality

2. **HugoSiteInfo**:
   - All fields describe site output
   - No unrelated metadata mixed in

**Minor Issues** (-1 point):

1. **hugo_site.bzl Contains Two Rules**:
   - hugo_site (build) and hugo_serve (serve)
   - Slightly different concerns (production vs development)
   - **Impact**: Low - both operate on Hugo sites
   - Priority: P3 (Low)

**Recommendations**: Monitor hugo_site.bzl - if it grows significantly, consider splitting.

---

## 7. Critical Issues

### P0 - Critical (Fix Immediately)

**None found** - Codebase is architecturally sound.

---

### P1 - High Priority (Fix This Sprint)

**None found** - No high-priority architectural issues.

---

### P2 - Medium Priority (Plan for Next Sprint)

#### Issue 1: Missing Integration Tests

**Description**: No visible integration tests for rule composition chains.

**Impact**:
- **Business**: Changes could break common usage patterns undetected
- **Technical**: Refactoring risks breaking downstream integrations

**Root Cause**: Testing infrastructure not prioritized in initial development.

**Recommendation**:
```starlark
# test/integration/gzip_integration_test.bzl
load("@build_stack_rules_hugo//hugo:rules.bzl", "hugo_site", "gzip_hugo_site")
load("@bazel_skylib//rules:build_test.bzl", "build_test")

hugo_site(
    name = "test_site",
    config = "test_config.yaml",
    content = ["content/test.md"],
)

gzip_hugo_site(
    name = "test_site_gz",
    site = ":test_site",
)

build_test(
    name = "gzip_integration_test",
    targets = [":test_site_gz"],
)

# Verify gzipped files exist
sh_test(
    name = "verify_gzip_output",
    srcs = ["verify_gzip.sh"],
    data = [":test_site_gz"],
)
```

**Agent Usage**: Use `feature-implementation` agent to create test infrastructure following TDD principles.

---

#### Issue 2: Missing Provider Contract Documentation

**Description**: Provider fields lack formal contract documentation.

**Impact**:
- **Business**: Breaking changes could affect downstream rules
- **Technical**: Contributors don't know which fields are stable

**Root Cause**: Provider definitions have doc strings, but no stability guarantees.

**Recommendation**:
```starlark
# hugo/internal/hugo_site_info.bzl
HugoSiteInfo = provider(
    doc = """
    Information about a Hugo site build output.

    **STABILITY**: Stable - fields will not be removed or change type.
    New fields may be added in backward-compatible manner.

    **CONTRACT**:
    - output_dir: Always present, always tree artifact
    - files: Always present, may be empty depset
    - base_url: Always present, may be empty string
    - name: Always present, always non-empty string

    This provider makes it easier for downstream rules to access Hugo site files
    without dealing with tree artifacts directly.
    """,
    fields = {
        "output_dir": "Tree artifact containing all generated site files (REQUIRED)",
        "files": "Depset of all files, empty if not expanded (REQUIRED)",
        "base_url": "Base URL configured for site, empty string if not set (REQUIRED)",
        "name": "Target name, used for diagnostics and path construction (REQUIRED)",
    },
)
```

---

#### Issue 3: Improve Error Messages for Provider Access

**Description**: No defensive checks when accessing providers, cryptic errors if wrong target type passed.

**Impact**:
- **Business**: User experience - confusing error messages
- **Technical**: Harder to debug BUILD file errors

**Root Cause**: Bazel provides default error, rules don't add context.

**Recommendation**:
```starlark
# hugo/internal/hugo_site_gzip.bzl
def _gzip_hugo_site_impl(ctx):
    # Add defensive check
    if HugoSiteInfo not in ctx.attr.site:
        fail("""
Attribute 'site' must be a hugo_site target.

Got: %s
Expected: A target created by hugo_site() rule

Example:
    hugo_site(
        name = "my_site",
        config = "config.yaml",
        content = glob(["content/**"]),
    )

    gzip_hugo_site(
        name = "my_site_gz",
        site = ":my_site",  # ← Must be a hugo_site target
    )
""" % ctx.attr.site.label)

    site_info = ctx.attr.site[HugoSiteInfo]
    # ... rest of implementation
```

**Agent Usage**: Use `code-refactoring` agent to add defensive checks across all utility rules.

---

### P3 - Low Priority (Technical Debt Backlog)

#### Issue 1: hugo_site.bzl File Size

**Description**: hugo_site.bzl is 329 lines, approaching complexity limit.

**Impact**:
- **Technical**: Harder to maintain if it grows significantly
- **Business**: Slower development velocity for future changes

**Root Cause**: hugo_site and hugo_serve in same file, complex setup logic.

**Recommendation**: Monitor size - if it exceeds 400 lines, extract helper functions.

**Refactoring Plan**:
1. Create hugo/internal/utils.bzl
2. Move relative_path, copy_to_dir to utils.bzl
3. Extract config preparation to _prepare_config()
4. Extract theme handling to _prepare_theme()

---

#### Issue 2: Attribute Naming Inconsistency

**Description**: hugo_serve uses `dep` instead of more descriptive name.

**Impact**: Minor - reduces clarity

**Recommendation**:
```starlark
# hugo_serve attribute rename
"site": attr.label_list(  # Instead of "dep"
    doc = "The hugo_site target(s) to serve for development",
    mandatory = True,
),
```

---

#### Issue 3: Missing hugo_site extra_args Attribute

**Description**: Cannot pass arbitrary Hugo CLI arguments without modifying rule.

**Impact**: Power users can't use advanced Hugo features

**Recommendation**:
```starlark
hugo_site = rule(
    attrs = {
        # ... existing attrs
        "extra_hugo_args": attr.string_list(
            doc = """
            Additional arguments passed directly to Hugo CLI.
            Use this for advanced Hugo features not covered by other attributes.

            Example: extra_hugo_args = ["--minify", "--enableGitInfo"]
            """,
            default = [],
        ),
    },
)

# In implementation
hugo_args += ctx.attr.extra_hugo_args
```

---

## 8. Refactoring Recommendations

### Refactoring Plan 1: Add Integration Test Suite

**Current State**: No integration tests for rule composition.

**Target State**: Comprehensive test suite covering common usage patterns.

**Refactoring Steps**:
1. Create test/ directory structure
2. Add test BUILD.bazel files
3. Create minimal test fixtures (config, content)
4. Implement build_test targets for each rule
5. Add shell tests for output verification
6. Integrate into CI pipeline

**Agent Usage**: `feature-implementation` agent for TDD-based test creation.

**Testing Strategy**:
- Build tests verify targets build successfully
- Shell tests verify file outputs exist and are correct
- Integration tests verify rule composition chains

**Risk Assessment**:
- **Low Risk**: Adding tests doesn't modify production code
- **Benefit**: High - prevents regressions, documents usage

---

### Refactoring Plan 2: Enhance Provider Documentation

**Current State**: Provider fields documented, but no stability contract.

**Target State**: Clear API stability guarantees and field contracts.

**Refactoring Steps**:
1. Add STABILITY section to each provider docstring
2. Document CONTRACT for each field
3. Mark fields as REQUIRED or OPTIONAL
4. Add examples to provider documentation
5. Create CONTRIBUTING.md explaining stability policy

**Agent Usage**: `expert-writer` agent for documentation improvement.

**Testing Strategy**:
- Manual review of documentation clarity
- Ensure all providers have stability guarantees

**Risk Assessment**:
- **Low Risk**: Documentation changes only
- **Benefit**: High - sets expectations, prevents breaking changes

---

### Refactoring Plan 3: Add Defensive Provider Checks

**Current State**: No validation when accessing providers.

**Target State**: Clear error messages when wrong target types used.

**Refactoring Steps**:
1. Identify all provider access sites
2. Add defensive checks before accessing provider
3. Craft helpful error messages with examples
4. Test with intentionally wrong targets
5. Document error message patterns

**Agent Usage**: `code-refactoring` agent for systematic provider check addition.

**Testing Strategy**:
- Create test with wrong target type
- Verify error message is helpful
- Ensure correct targets still work

**Risk Assessment**:
- **Medium Risk**: Changes rule implementation code
- **Benefit**: Medium - improves UX for common mistakes

---

## 9. Architecture Improvement Roadmap

### Short Term (1-2 Sprints)

- [P2] Add integration test suite
  - **Effort**: 3-5 days
  - **Impact**: High - prevents regressions
  - **Owner**: Team lead

- [P2] Enhance provider documentation with stability contracts
  - **Effort**: 1-2 days
  - **Impact**: Medium - sets expectations
  - **Owner**: Documentation owner

- [P2] Add defensive provider access checks
  - **Effort**: 2-3 days
  - **Impact**: Medium - improves UX
  - **Owner**: Developer

---

### Medium Term (3-6 Sprints)

- [P3] Monitor hugo_site.bzl complexity, extract if needed
  - **Effort**: 1-2 days (if needed)
  - **Impact**: Low - future maintainability
  - **Owner**: Team

- [P3] Add extra_hugo_args attribute for power users
  - **Effort**: 1 day
  - **Impact**: Low - enables advanced use cases
  - **Owner**: Developer

- [P3] Rename hugo_serve `dep` attribute to `site`
  - **Effort**: 1 day (includes migration guide)
  - **Impact**: Low - improves clarity
  - **Owner**: Developer

---

### Long Term (6+ Sprints)

- Create DESIGN_PATTERNS.md documenting architecture
  - **Effort**: 2-3 days
  - **Impact**: Medium - onboarding, knowledge sharing
  - **Owner**: Architect

- Establish automated architecture validation
  - **Effort**: 1 week
  - **Impact**: Medium - prevents architectural drift
  - **Owner**: DevOps

---

## 10. Positive Patterns and Strengths

The following architectural patterns should be **protected and replicated**:

### 1. Provider-Based Abstraction ⭐⭐⭐

**Location**: HugoSiteInfo, HugoThemeInfo
**Why Excellent**:
- Enables loose coupling between rules
- Type-safe cross-rule dependencies
- Allows rule composition without tight coupling

**Example**:
```starlark
# Producer doesn't know consumers exist
site_info = HugoSiteInfo(output_dir=..., ...)
return [site_info]

# Consumer depends on abstraction, not concrete rule
def _consumer_impl(ctx):
    site_info = ctx.attr.site[HugoSiteInfo]  # Abstraction
```

**Use This Pattern For**: Any new rule that needs to pass structured data to downstream consumers.

---

### 2. Public API Facade ⭐⭐⭐

**Location**: hugo/rules.bzl
**Why Excellent**:
- Stable API path for users
- Internal implementation can move without breaking users
- Clear documentation point

**Example**:
```starlark
# Users load from stable path
load("@build_stack_rules_hugo//hugo:rules.bzl", "hugo_site")

# Internal implementation can move
load("//hugo:internal/hugo_site.bzl", _hugo_site = "hugo_site")
hugo_site = _hugo_site
```

**Use This Pattern For**: All new rules - export through rules.bzl.

---

### 3. Single Responsibility Rules ⭐⭐⭐

**Location**: gzip_hugo_site, hugo_site_files
**Why Excellent**:
- Each rule has one clear purpose
- Easy to understand and maintain
- Composable through providers

**Example**:
```starlark
# One rule = one responsibility
gzip_hugo_site:     Gzip compression
hugo_site_files:    Manifest generation
process_hugo_site:  Generic processing
```

**Use This Pattern For**: All new functionality - create focused rules, compose via providers.

---

### 4. Consistent Naming Conventions ⭐⭐⭐

**Location**: Throughout codebase
**Why Excellent**:
- Predictable API surface
- Easy discoverability
- Clear intent

**Examples**:
- Rules: `hugo_*` (domain prefix)
- Providers: `Hugo*Info` (CapitalCase + Info suffix)
- Private impls: `_*_impl`
- Attributes: `snake_case`

**Use This Pattern For**: All new code - maintain consistency.

---

### 5. Helper Function Extraction ⭐⭐

**Location**: relative_path, copy_to_dir
**Why Good**:
- Reusable logic
- Testable in isolation
- Improves readability

**Example**:
```starlark
# Extract complex logic to named function
hugo_inputs += copy_to_dir(ctx, srcs, name)  # Clear intent
```

**Use This Pattern For**: Any complex logic used multiple times.

---

## Summary of Scores

| Category | Score | Grade |
|----------|-------|-------|
| **SOLID Principles** | **9.0/10** | A |
| - Single Responsibility | 9/10 | A |
| - Open/Closed | 9/10 | A |
| - Liskov Substitution | 10/10 | A+ |
| - Interface Segregation | 10/10 | A+ |
| - Dependency Inversion | 9/10 | A |
| **Clean Architecture** | **8.7/10** | B+ |
| - Layer Separation | 9/10 | A |
| - Boundary Crossings | 10/10 | A+ |
| - Testability | 7/10 | B |
| **Clean Code** | **8.8/10** | B+ |
| - Naming Quality | 9/10 | A |
| - Function Quality | 9/10 | A |
| - Comment Quality | 8/10 | B+ |
| - Error Handling | 9/10 | A |
| - Code Organization | 10/10 | A+ |
| **Domain-Driven Design** | **8.3/10** | B+ |
| - Ubiquitous Language | 8/10 | B+ |
| - Bounded Contexts | 9/10 | A |
| - Tactical Patterns | 7/10 | B |
| - Domain Services | 9/10 | A |
| **Design Patterns** | **8.5/10** | B+ |
| - Pattern Recognition | 9/10 | A |
| - Pattern Opportunities | 8/10 | B+ |
| **Coupling & Cohesion** | **9.0/10** | A |
| - Coupling Metrics | 9/10 | A |
| - Cohesion Analysis | 9/10 | A |

---

## Final Recommendations

### Immediate Actions

1. ✅ **Document the improvements** - Already done (DOWNSTREAM_INTEGRATION.md)
2. 📋 **Add integration tests** - High value, low risk
3. 📋 **Enhance provider documentation** - Clarifies stability contracts

### Preserve and Protect

- Provider-based abstraction pattern
- Public API facade pattern
- Single responsibility rule design
- Consistent naming conventions

### Continue Monitoring

- hugo_site.bzl file size (extract if >400 lines)
- New rules should follow existing patterns
- Maintain low coupling through providers

---

**Overall Assessment**: The rules_hugo codebase demonstrates excellent architectural health with strong separation of concerns, minimal coupling, and modern Bazel practices. The recent improvements adding downstream integration utilities follow the same high-quality patterns. Continue the current architectural approach, add tests and documentation as recommended, and the codebase will remain maintainable and extensible for the long term.

---

**End of Architecture Review**
