# Epic: Bzlmod Migration and CI Stabilization

## Overview

**Goal**: Migrate the repository to use Bzlmod (Bazel's new dependency management system) and stabilize the CI/CD pipeline.

**Value Proposition**:
- Modernize Bazel dependency management
- Fix persistent CI failures
- Ensure reproducible builds across environments
- Update themes and dependencies to latest versions

**Success Metrics**:
- All CI checks pass (GitHub Actions)
- Site builds successfully with Bzlmod enabled
- Integration tests pass
- No legacy `WORKSPACE` dependencies required (eventually)

**Target Effort**: Completed

---

## Story Breakdown

### Story 1: CI Stabilization and Bzlmod Support (Completed)

**Objective**: Fix build and test failures arising from the Bzlmod migration and environment differences.

**Deliverables**:
- Updated Starlark code compatible with recent Bazel versions
- Configured Node.js toolchain for CI environments
- Fixed theme integration issues
- Passing CI pipeline

---

## Atomic Tasks

### Task 1.1: Fix Starlark JSON Loading (Completed)

**Scope**: Remove deprecated `json` module load.

**Details**:
- Removed `load("@bazel_tools//tools/build_defs/repo:utils.bzl", "json")`
- Used built-in `json` module available in recent Bazel versions.

### Task 1.2: Configure Node.js and Puppeteer for CI (Completed)

**Scope**: Ensure Puppeteer runs correctly in CI environment.

**Details**:
- Added `--no-sandbox` args to Puppeteer launch.
- Configured `PUPPETEER_DOWNLOAD_PATH` and `PUPPETEER_SKIP_CHROMIUM_DOWNLOAD` properly.
- Ensured Chrome is installed in the CI environment.

### Task 1.3: Update Hugo Themes (Completed)

**Scope**: Update `hugo-book` and `hugo-geekdoc` themes and fix integration.

**Details**:
- Updated theme versions.
- Fixed `_partials` mapping issue where partials were not being found.
- Verified theme rendering in `site_complex` and `site_simple`.

### Task 1.4: Fix Stylelint Configuration (Completed)

**Scope**: Resolve Stylelint errors in CI.

**Details**:
- Updated `.stylelintrc` configuration.
- Fixed specific linting errors in SCSS files.

### Task 1.5: Verify CI Pipeline (Completed)

**Scope**: Ensure all checks pass in GitHub Actions.

**Details**:
- Verified `ci.yml` workflow execution.
- Confirmed all tests (unit and integration) pass.

---

## Next Steps

1.  **Merge PR**: Merge the `support_bzlmod` branch into `main`.
2.  **Documentation Update**: Update `README.md` to reflect Bzlmod usage instructions.
3.  **Cleanup**: Remove legacy `WORKSPACE` file if fully migrated (or plan for removal).
