#!/usr/bin/env node
/**
 * Prerender processor for Hugo sites
 * Uses Puppeteer to prerender pages for better performance
 */

const fs = require('fs');
const path = require('path');
const puppeteer = require('puppeteer');

// Parse command line arguments
const args = process.argv.slice(2);
if (args.length < 3) {
  console.error('Usage: prerender.js <input_dir> <output_dir> <base_url> [options]');
  console.error('Options: --wait-for-network-idle --capture-js-errors --minify');
  process.exit(1);
}

const inputDir = path.resolve(args[0]);
const outputDir = path.resolve(args[1]);
const baseUrl = args[2];
const options = args.slice(3);

// Parse options
const prerenderOptions = {
  waitForNetworkIdle: options.includes('--wait-for-network-idle'),
  captureJSErrors: options.includes('--capture-js-errors'),
  minify: options.includes('--minify'),
};

// Recursively find all HTML files
function findHTMLFiles(dir, fileList = []) {
  const files = fs.readdirSync(dir);

  files.forEach(file => {
    const filePath = path.join(dir, file);
    const stat = fs.statSync(filePath);

    if (stat.isDirectory()) {
      findHTMLFiles(filePath, fileList);
    } else if (file.endsWith('.html')) {
      fileList.push(filePath);
    }
  });

  return fileList;
}

// Copy directory (for non-HTML files)
function copyDirectory(src, dest) {
  fs.mkdirSync(dest, { recursive: true });
  const entries = fs.readdirSync(src, { withFileTypes: true });

  for (const entry of entries) {
    const srcPath = path.join(src, entry.name);
    const destPath = path.join(dest, entry.name);

    if (entry.isDirectory()) {
      copyDirectory(srcPath, destPath);
    } else if (!entry.name.endsWith('.html')) {
      fs.copyFileSync(srcPath, destPath);
    }
  }
}

// Minify HTML (simple)
function minifyHTML(html) {
  return html
    .replace(/>\s+</g, '><')  // Remove whitespace between tags
    .replace(/\s+/g, ' ')    // Collapse multiple spaces
    .replace(/\s*\n\s*/g, '') // Remove newlines
    .trim();
}

async function prerenderPages() {
  console.log(`Prerendering HTML files from ${inputDir} to ${outputDir}`);
  console.log(`Base URL: ${baseUrl}`);

  // Copy all non-HTML files first
  copyDirectory(inputDir, outputDir);

  // Find all HTML files
  const htmlFiles = findHTMLFiles(inputDir);
  console.log(`Found ${htmlFiles.length} HTML files to prerender`);

  if (htmlFiles.length === 0) {
    console.log('No HTML files found to prerender');
    return;
  }

  // Launch browser
  try {
      console.log('Puppeteer executable path:', puppeteer.executablePath());
  } catch (e) {
      console.log('Could not determine executable path:', e.message);
  }

  const browser = await puppeteer.launch({
    headless: 'new',
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-dev-shm-usage',
      '--disable-accelerated-2d-canvas',
      '--no-first-run',
      '--no-zygote',
      '--disable-gpu'
    ]
  });

  let processed = 0;
  let failed = 0;

  try {
    for (const htmlFile of htmlFiles) {
      try {
        const relativePath = path.relative(inputDir, htmlFile);
        const outputPath = path.join(outputDir, relativePath);

        // Calculate URL for this file
        const fileUrl = `file://${htmlFile}`;
        console.log(`Prerendering: ${relativePath}`);

        // Create new page
        const page = await browser.newPage();

        // Set up error capture if requested
        if (prerenderOptions.captureJSErrors) {
          page.on('pageerror', error => {
            console.warn(`JS Error in ${relativePath}: ${error.message}`);
          });
        }

        // Navigate to the file
        await page.goto(fileUrl, {
          waitUntil: 'domcontentloaded',
          timeout: 10000
        });

        // Wait for network idle if requested
        if (prerenderOptions.waitForNetworkIdle) {
          await page.waitForNetworkIdle({ timeout: 5000 });
        }

        // Get the rendered HTML
        const renderedHTML = await page.content();

        // Close the page
        await page.close();

        // Process the HTML
        let finalHTML = renderedHTML;
        if (prerenderOptions.minify) {
          finalHTML = minifyHTML(renderedHTML);
        }

        // Ensure output directory exists
        fs.mkdirSync(path.dirname(outputPath), { recursive: true });

        // Write the prerendered HTML
        fs.writeFileSync(outputPath, finalHTML);

        console.log(`✓ Prerendered: ${relativePath}`);
        processed++;

      } catch (error) {
        console.error(`Error prerendering ${htmlFile}:`, error.message);
        // Copy original file on error
        const relativePath = path.relative(inputDir, htmlFile);
        const outputPath = path.join(outputDir, relativePath);
        fs.mkdirSync(path.dirname(outputPath), { recursive: true });
        fs.copyFileSync(htmlFile, outputPath);
        console.log(`⚠️  Copied original file due to error: ${relativePath}`);
        failed++;
      }
    }

    console.log(`\nPrerendering Summary:`);
    console.log(`Files processed: ${processed}`);
    if (failed > 0) {
      console.log(`Files failed: ${failed}`);
    }
    console.log('✅ Prerendering completed');

  } finally {
    await browser.close();
  }
}

// Run the prerenderer
prerenderPages().catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});