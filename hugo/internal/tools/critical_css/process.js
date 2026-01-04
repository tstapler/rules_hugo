#!/usr/bin/env node
/**
 * Critical CSS processor for Hugo sites
 * Extracts and inlines critical CSS using Beasties
 */

const fs = require('fs');
const path = require('path');
const Beasties = require('beasties');

// Parse command line arguments
const args = process.argv.slice(2);
if (args.length < 2) {
  console.error('Usage: process.js <input_dir> <output_dir>');
  process.exit(1);
}

const inputDir = args[0];
const outputDir = args[1];

// Create output directory
fs.mkdirSync(outputDir, { recursive: true });

// Configure Beasties
const beasties = new Beasties({
  path: inputDir,
  reduceInlineStyles: true,
  preload: 'swap',  // Use font-display: swap for better performance
  compress: true,   // Compress the critical CSS
  logLevel: 'info',
});

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

// Copy non-HTML files
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

async function processHTMLFiles() {
  console.log(`Processing HTML files from ${inputDir} to ${outputDir}`);

  // Copy all non-HTML files first
  copyDirectory(inputDir, outputDir);

  // Find all HTML files
  const htmlFiles = findHTMLFiles(inputDir);
  console.log(`Found ${htmlFiles.length} HTML files to process`);

  let processed = 0;
  let failed = 0;

  for (const htmlFile of htmlFiles) {
    try {
      const html = fs.readFileSync(htmlFile, 'utf8');
      const relativePath = path.relative(inputDir, htmlFile);
      const outputPath = path.join(outputDir, relativePath);

      console.log(`Processing: ${relativePath}`);

      // Process with Beasties
      const result = await beasties.process(html);

      // Ensure output directory exists
      fs.mkdirSync(path.dirname(outputPath), { recursive: true });

      // Write processed HTML
      fs.writeFileSync(outputPath, result);
      processed++;

    } catch (error) {
      console.error(`Error processing ${htmlFile}:`, error.message);
      failed++;
    }
  }

  console.log(`\nProcessed ${processed} HTML files`);
  if (failed > 0) {
    console.error(`Failed to process ${failed} files`);
    process.exit(1);
  }
}

// Run the processor
processHTMLFiles().catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});
