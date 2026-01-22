---
title: "Broken Page"
---

# Broken Links Test Page

This page intentionally contains broken links for testing the link checker's ability to detect issues.

## Valid Links (should pass)
- [Home](_index.md)
- [Valid Page](valid-page.md)
- [Google](https://www.google.com)

## Broken Internal Links (should fail)
- [Non-existent Page](this-page-does-not-exist.md)
- [Another Missing Page](missing-content.md)
- [Typo in Reference](valid-pae.md)

## Broken External Links (should fail)
- [Invalid Domain](https://this-domain-absolutely-does-not-exist-12345.com)
- [Bad Protocol](htp://missing-protocol-letter.com)
- [Malformed URL](https://[invalid-chars].com)
- [Non-secure HTTP](http://http-only-should-work-but-might-be-flagged.com)
- [Port That Doesn't Exist](https://localhost:99999)

## Edge Cases
- [Empty Link]()
- [Relative Link](/relative/path/that/does/not/exist)
- [Anchor Only](#section-that-does-not-exist)

## Mixed Valid and Invalid
This page tests that the link checker can distinguish between working and broken links on the same page.