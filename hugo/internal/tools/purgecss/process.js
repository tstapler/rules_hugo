#!/usr/bin/env node
/**
 * PurgeCSS processor for Hugo sites
 * Removes unused CSS classes using PurgeCSS
 */

const fs = require('fs');
const path = require('path');
const postcss = require('postcss');
const purgecss = require('@fullhuman/postcss-purgecss');

// Parse command line arguments
const args = process.argv.slice(2);
if (args.length < 3) {
  console.error('Usage: purgecss.js <input_dir> <output_dir> <content_glob> [options]');
  console.error('Options: --keyframes --font-face --variables');
  process.exit(1);
}

const inputDir = args[0];
const outputDir = args[1];
const contentGlob = args[2];
const options = args.slice(3);

// Parse options
const purgeOptions = {
  keyframes: options.includes('--keyframes'),
  fontFace: options.includes('--font-face'),
  variables: options.includes('--variables'),
};

// Create output directory
fs.mkdirSync(outputDir, { recursive: true });

// Recursively find all CSS files
function findCSSFiles(dir, fileList = []) {
  const files = fs.readdirSync(dir);

  files.forEach(file => {
    const filePath = path.join(dir, file);
    const stat = fs.statSync(filePath);

    if (stat.isDirectory()) {
      findCSSFiles(filePath, fileList);
    } else if (file.endsWith('.css')) {
      fileList.push(filePath);
    }
  });

  return fileList;
}

// Copy non-CSS files
function copyDirectory(src, dest) {
  fs.mkdirSync(dest, { recursive: true });
  const entries = fs.readdirSync(src, { withFileTypes: true });

  for (const entry of entries) {
    const srcPath = path.join(src, entry.name);
    const destPath = path.join(dest, entry.name);

    if (entry.isDirectory()) {
      copyDirectory(srcPath, destPath);
    } else if (!entry.name.endsWith('.css')) {
      fs.copyFileSync(srcPath, destPath);
    }
  }
}

async function processCSSFiles() {
  console.log(`Processing CSS files from ${inputDir} to ${outputDir}`);
  console.log(`Content glob: ${contentGlob}`);
  console.log(`Options:`, purgeOptions);

  // Copy all non-CSS files first
  copyDirectory(inputDir, outputDir);

  // Find all CSS files
  const cssFiles = findCSSFiles(inputDir);
  console.log(`Found ${cssFiles.length} CSS files to process`);

  // Configure PurgeCSS
  const purgecssPlugin = purgecss({
    content: [path.join(inputDir, contentGlob)], // Scan HTML/content files
    css: cssFiles, // CSS files to purge
    keyframes: purgeOptions.keyframes,
    fontFace: purgeOptions.fontFace,
    variables: purgeOptions.variables,
    safelist: {
      // Common Hugo classes that might be dynamically generated
      standard: [
        /^hugo-/,
        /^menu-/,
        /^pagination-/,
        /^social-/,
        /^tag-/,
        /^taxonomy-/,
      ]
    }
  });

  let processed = 0;
  let totalReduction = 0;

  for (const cssFile of cssFiles) {
    try {
      const css = fs.readFileSync(cssFile, 'utf8');
      const relativePath = path.relative(inputDir, cssFile);
      const outputPath = path.join(outputDir, relativePath);

      console.log(`Processing: ${relativePath}`);

      const originalSize = css.length;

      // Process with PostCSS + PurgeCSS
      const result = await postcss([purgecssPlugin]).process(css, {
        from: cssFile,
        to: outputPath,
      });

      // Ensure output directory exists
      fs.mkdirSync(path.dirname(outputPath), { recursive: true });

      // Write processed CSS
      fs.writeFileSync(outputPath, result.css);

      const newSize = result.css.length;
      const reduction = originalSize - newSize;
      const percent = originalSize > 0 ? ((reduction / originalSize) * 100).toFixed(1) : 0;

      console.log(`✓ Reduced: ${originalSize} → ${newSize} bytes (${percent}% reduction)`);

      processed++;
      totalReduction += reduction;

    } catch (error) {
      console.error(`Error processing ${cssFile}:`, error.message);
      // Copy original file on error
      const relativePath = path.relative(inputDir, cssFile);
      const outputPath = path.join(outputDir, relativePath);
      fs.mkdirSync(path.dirname(outputPath), { recursive: true });
      fs.copyFileSync(cssFile, outputPath);
      console.log(`⚠️  Copied original file due to error`);
    }
  }

  const totalPercent = cssFiles.length > 0 ? ((totalReduction / cssFiles.reduce((sum, file) => sum + fs.statSync(file).size, 0)) * 100).toFixed(1) : 0;
  console.log(`\nProcessed ${processed} CSS files`);
  console.log(`Total reduction: ${totalReduction} bytes (${totalPercent}% of original CSS)`);
}

// Run the processor
processCSSFiles().catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});