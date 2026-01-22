#!/usr/bin/env python3
"""
Hugo Link Checker Processor

Checks HTML files for broken internal and external links, including anchor links.
Provides comprehensive error reporting with line numbers and file paths.
"""

import argparse
import os
import re
import sys
import time
import urllib.parse
from dataclasses import dataclass
from pathlib import Path
from typing import List, Optional, Set, Tuple

import requests
from bs4 import BeautifulSoup


@dataclass
class LinkIssue:
    """Represents a link validation issue."""
    file_path: str
    line_number: int
    link_type: str  # 'internal', 'external', 'anchor'
    url: str
    issue: str
    context: str  # Surrounding HTML context


class LinkChecker:
    """Main link checker class."""
    
    def __init__(self, site_dir: str, check_external: bool = False, timeout: int = 10):
        self.site_dir = Path(site_dir).resolve()
        self.check_external = check_external
        self.timeout = timeout
        self.issues: List[LinkIssue] = []
        self.visited_external: Set[str] = set()
        self.base_url = None
        
        # Validate site directory
        if not self.site_dir.exists():
            raise ValueError(f"Site directory does not exist: {self.site_dir}")
        
        # Try to determine base URL from config or use default
        self._detect_base_url()
    
    def _detect_base_url(self):
        """Attempt to detect the base URL from Hugo config."""
        config_files = [
            self.site_dir / "config.yaml",
            self.site_dir / "config.yml", 
            self.site_dir / "config.toml",
            self.site_dir / "config.json"
        ]
        
        for config_file in config_files:
            if config_file.exists():
                try:
                    content = config_file.read_text()
                    # Simple regex to find baseURL in various formats
                    match = re.search(r'baseURL\s*[:=]\s*["\']([^"\']+)["\']', content)
                    if match:
                        self.base_url = match.group(1).rstrip('/')
                        break
                except Exception:
                    # If we can't read config, continue with None
                    pass
        
        # Default base URL if not found
        if not self.base_url:
            self.base_url = "https://example.com"
    
    def check_site(self) -> List[LinkIssue]:
        """Check all HTML files in the site for link issues."""
        print(f"Checking links in site: {self.site_dir}")
        
        # Find all HTML files
        html_files = list(self.site_dir.rglob("*.html"))
        if not html_files:
            print("Warning: No HTML files found in site directory")
            return self.issues
        
        print(f"Found {len(html_files)} HTML files to check")
        
        # Check each file
        for html_file in html_files:
            self._check_file(html_file)
        
        # Report summary
        self._print_summary()
        
        return self.issues
    
    def _check_file(self, file_path: Path):
        """Check links in a single HTML file."""
        try:
            content = file_path.read_text(encoding='utf-8')
            soup = BeautifulSoup(content, 'html.parser')
            
            # Extract all links
            links = self._extract_links(soup, file_path)
            
            # Check each link
            for link_info in links:
                self._check_link(link_info, file_path)
                
        except Exception as e:
            issue = LinkIssue(
                file_path=str(file_path.relative_to(self.site_dir)),
                line_number=1,
                link_type='file',
                url='',
                issue=f'Error reading file: {str(e)}',
                context=''
            )
            self.issues.append(issue)
    
    def _extract_links(self, soup: BeautifulSoup, file_path: Path) -> List[Tuple[str, int, str]]:
        """Extract all links from HTML with line numbers.
        
        Returns:
            List of tuples: (url, line_number, context)
        """
        links = []
        
        # Get the original HTML content for line number calculation
        content = file_path.read_text(encoding='utf-8')
        lines = content.split('\n')
        
        # Find all <a> tags with href attributes
        for tag in soup.find_all('a', href=True):
            href = tag['href'].strip()
            if not href or href.startswith('#'):  # Skip empty and pure anchors
                continue
                
            # Find line number by searching for this tag in the source
            line_number = self._find_line_number(tag, content)
            
            # Get context (simplified tag representation)
            context = str(tag)[:100] + '...' if len(str(tag)) > 100 else str(tag)
            
            links.append((href, line_number, context))
        
        return links
    
    def _find_line_number(self, tag, content: str) -> int:
        """Find the line number of a tag in the original HTML content."""
        # This is a simplified approach - in practice, you might want a more
        # sophisticated method to handle edge cases
        tag_str = str(tag)
        lines = content.split('\n')
        
        for i, line in enumerate(lines, 1):
            if tag_str in line:
                return i
        
        # If not found exactly, try partial matching
        tag_parts = tag_str.split()
        for i, line in enumerate(lines, 1):
            matches = sum(1 for part in tag_parts if part in line)
            if matches >= len(tag_parts) // 2:  # At least half match
                return i
        
        return 1  # Default to first line if not found
    
    def _check_link(self, link_info: Tuple[str, int, str], file_path: Path):
        """Check a single link and add issues if found."""
        url, line_number, context = link_info
        
        try:
            parsed = urllib.parse.urlparse(url)
            
            if parsed.scheme in ('http', 'https'):
                # External link
                if self.check_external:
                    self._check_external_link(url, line_number, file_path, context)
            elif parsed.scheme == '':
                # Internal link or anchor
                if url.startswith('#'):
                    # Anchor link within the same page
                    self._check_anchor_link(url, line_number, file_path, context)
                else:
                    # Internal link to another page
                    self._check_internal_link(url, line_number, file_path, context)
            # Other schemes (mailto:, tel:, etc.) are ignored
            
        except Exception as e:
            issue = LinkIssue(
                file_path=str(file_path.relative_to(self.site_dir)),
                line_number=line_number,
                link_type='internal',
                url=url,
                issue=f'Error parsing link: {str(e)}',
                context=context
            )
            self.issues.append(issue)
    
    def _check_internal_link(self, url: str, line_number: int, file_path: Path, context: str):
        """Check an internal link to another page."""
        try:
            # Resolve the URL relative to the current file
            current_dir = file_path.parent
            target_path = (current_dir / url).resolve()
            
            # Handle potential directory URLs (add index.html)
            if target_path.is_dir():
                target_path = target_path / 'index.html'
            
            # Check if the target file exists
            if not target_path.exists():
                issue = LinkIssue(
                    file_path=str(file_path.relative_to(self.site_dir)),
                    line_number=line_number,
                    link_type='internal',
                    url=url,
                    issue='Target file not found',
                    context=context
                )
                self.issues.append(issue)
            elif not target_path.suffix:
                # URL without extension, try adding .html
                html_path = target_path.with_suffix('.html')
                if html_path.exists():
                    # Valid link to HTML file without extension
                    pass
                else:
                    issue = LinkIssue(
                        file_path=str(file_path.relative_to(self.site_dir)),
                        line_number=line_number,
                        link_type='internal',
                        url=url,
                        issue='Target file not found (tried .html extension)',
                        context=context
                    )
                    self.issues.append(issue)
                    
        except Exception as e:
            issue = LinkIssue(
                file_path=str(file_path.relative_to(self.site_dir)),
                line_number=line_number,
                link_type='internal',
                url=url,
                issue=f'Error resolving internal link: {str(e)}',
                context=context
            )
            self.issues.append(issue)
    
    def _check_anchor_link(self, url: str, line_number: int, file_path: Path, context: str):
        """Check an anchor link within the current page."""
        try:
            # Remove the # and get the anchor name
            anchor = url[1:]
            
            # Read the file content
            content = file_path.read_text(encoding='utf-8')
            soup = BeautifulSoup(content, 'html.parser')
            
            # Look for the anchor
            found = False
            
            # Check for id attributes
            if soup.find(id=anchor):
                found = True
            else:
                # Check for name attributes in a tags
                if soup.find('a', {'name': anchor}):
                    found = True
                else:
                    # Check for headers with text matching the anchor (URL-encoded)
                    decoded_anchor = urllib.parse.unquote(anchor)
                    for header in soup.find_all(re.compile(r'^h[1-6]$')):
                        if header.get_text().strip().lower().replace(' ', '-') == decoded_anchor.lower().replace(' ', '-'):
                            found = True
                            break
            
            if not found:
                issue = LinkIssue(
                    file_path=str(file_path.relative_to(self.site_dir)),
                    line_number=line_number,
                    link_type='anchor',
                    url=url,
                    issue='Anchor not found on page',
                    context=context
                )
                self.issues.append(issue)
                
        except Exception as e:
            issue = LinkIssue(
                file_path=str(file_path.relative_to(self.site_dir)),
                line_number=line_number,
                link_type='anchor',
                url=url,
                issue=f'Error checking anchor: {str(e)}',
                context=context
            )
            self.issues.append(issue)
    
    def _check_external_link(self, url: str, line_number: int, file_path: Path, context: str):
        """Check an external link using HTTP request."""
        # Avoid checking the same URL multiple times
        if url in self.visited_external:
            return
        
        self.visited_external.add(url)
        
        try:
            # Make HTTP request with timeout
            response = requests.head(url, timeout=self.timeout, allow_redirects=True)
            
            # Check status code
            if response.status_code >= 400:
                issue = LinkIssue(
                    file_path=str(file_path.relative_to(self.site_dir)),
                    line_number=line_number,
                    link_type='external',
                    url=url,
                    issue=f'HTTP {response.status_code}: {response.reason}',
                    context=context
                )
                self.issues.append(issue)
                
        except requests.exceptions.Timeout:
            issue = LinkIssue(
                file_path=str(file_path.relative_to(self.site_dir)),
                line_number=line_number,
                link_type='external',
                url=url,
                issue=f'Request timeout after {self.timeout} seconds',
                context=context
            )
            self.issues.append(issue)
        except requests.exceptions.ConnectionError:
            issue = LinkIssue(
                file_path=str(file_path.relative_to(self.site_dir)),
                line_number=line_number,
                link_type='external',
                url=url,
                issue='Connection error',
                context=context
            )
            self.issues.append(issue)
        except requests.exceptions.RequestException as e:
            issue = LinkIssue(
                file_path=str(file_path.relative_to(self.site_dir)),
                line_number=line_number,
                link_type='external',
                url=url,
                issue=f'Request error: {str(e)}',
                context=context
            )
            self.issues.append(issue)
    
    def _print_summary(self):
        """Print a summary of the link checking results."""
        total_issues = len(self.issues)
        if total_issues == 0:
            print("✅ No link issues found!")
            return
        
        # Count by type
        type_counts = {}
        for issue in self.issues:
            type_counts[issue.link_type] = type_counts.get(issue.link_type, 0) + 1
        
        print(f"❌ Found {total_issues} link issues:")
        for link_type, count in sorted(type_counts.items()):
            print(f"  {link_type}: {count}")
    
    def write_report(self, output_path: str):
        """Write a detailed report of link issues to a file."""
        if not self.issues:
            print("No issues to report.")
            return
        
        report_path = Path(output_path)
        
        with open(report_path, 'w', encoding='utf-8') as f:
            f.write("# Link Checker Report\n\n")
            f.write(f"Total Issues: {len(self.issues)}\n\n")
            
            # Group issues by file
            issues_by_file = {}
            for issue in self.issues:
                file_path = issue.file_path
                if file_path not in issues_by_file:
                    issues_by_file[file_path] = []
                issues_by_file[file_path].append(issue)
            
            # Write issues by file
            for file_path, file_issues in sorted(issues_by_file.items()):
                f.write(f"## {file_path}\n\n")
                
                for issue in sorted(file_issues, key=lambda x: x.line_number):
                    f.write(f"### Line {issue.line_number} - {issue.link_type.upper()}\n\n")
                    f.write(f"**URL:** `{issue.url}`\n\n")
                    f.write(f"**Issue:** {issue.issue}\n\n")
                    f.write(f"**Context:** `{issue.context}`\n\n")
                    f.write("---\n\n")
        
        print(f"📄 Report written to: {report_path}")


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description='Check HTML files for broken links',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s public/                    # Check internal links only
  %(prog)s public/ --check-external  # Check external links too
  %(prog)s public/ report.txt         # Save report to file
  %(prog)s public/ --timeout 5       # Set timeout for external requests
        """
    )
    
    parser.add_argument(
        'site_dir',
        help='Directory containing the built Hugo site'
    )
    
    parser.add_argument(
        'output_report',
        nargs='?',
        help='Path to write the report file (optional)'
    )
    
    parser.add_argument(
        '--check-external',
        action='store_true',
        help='Check external links (requires internet connection)'
    )
    
    parser.add_argument(
        '--timeout',
        type=int,
        default=10,
        help='Timeout for external link requests in seconds (default: 10)'
    )
    
    args = parser.parse_args()
    
    try:
        # Create link checker
        checker = LinkChecker(
            site_dir=args.site_dir,
            check_external=args.check_external,
            timeout=args.timeout
        )
        
        # Run the check
        issues = checker.check_site()
        
        # Write report if requested
        if args.output_report:
            checker.write_report(args.output_report)
        
        # Exit with appropriate code
        if issues:
            print(f"\n❌ Link checking completed with {len(issues)} issues found.")
            sys.exit(1)
        else:
            print("\n✅ Link checking completed successfully.")
            sys.exit(0)
            
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(2)


if __name__ == '__main__':
    main()