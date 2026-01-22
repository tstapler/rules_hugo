#!/usr/bin/env python3
"""
Simple test for the link checker functionality.
"""

import os
import tempfile
import unittest
from pathlib import Path

from check import LinkChecker


class TestLinkChecker(unittest.TestCase):
    """Test cases for LinkChecker class."""
    
    def setUp(self):
        """Set up test environment."""
        self.test_dir = tempfile.mkdtemp()
        self.test_site = Path(self.test_dir)
        
        # Create test HTML files
        (self.test_site / "index.html").write_text("""<!DOCTYPE html>
<html>
<head><title>Test</title></head>
<body>
    <a href="page1.html">Page 1</a>
    <a href="missing.html">Missing</a>
    <a href="#section1">Anchor</a>
    <a href="https://example.com">External</a>
</body>
</html>""")
        
        (self.test_site / "page1.html").write_text("""<!DOCTYPE html>
<html>
<head><title>Page 1</title></head>
<body>
    <h1 id="section1">Section 1</h1>
    <a href="index.html">Back</a>
</body>
</html>""")
    
    def tearDown(self):
        """Clean up test environment."""
        import shutil
        shutil.rmtree(self.test_dir)
    
    def test_internal_links(self):
        """Test internal link checking."""
        checker = LinkChecker(str(self.test_site), check_external=False)
        issues = checker.check_site()
        
        # Should find the missing.html link
        missing_issues = [i for i in issues if i.url == "missing.html"]
        self.assertTrue(len(missing_issues) > 0)
        
        # Should not find page1.html (exists)
        valid_issues = [i for i in issues if i.url == "page1.html"]
        self.assertEqual(len(valid_issues), 0)
    
    def test_anchor_links(self):
        """Test anchor link checking."""
        checker = LinkChecker(str(self.test_site), check_external=False)
        issues = checker.check_site()
        
        # Should not find section1 (exists)
        anchor_issues = [i for i in issues if i.url == "#section1"]
        self.assertEqual(len(anchor_issues), 0)
    
    def test_external_links_disabled(self):
        """Test that external links are not checked when disabled."""
        checker = LinkChecker(str(self.test_site), check_external=False)
        issues = checker.check_site()
        
        # Should not check external links
        external_issues = [i for i in issues if i.link_type == "external"]
        self.assertEqual(len(external_issues), 0)


if __name__ == '__main__':
    unittest.main()