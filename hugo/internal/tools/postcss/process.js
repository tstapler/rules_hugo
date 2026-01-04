#!/usr/bin/env node
/**
 * PostCSS processor for Hugo sites
 * Runs configurable PostCSS plugins on CSS files
 */

const fs = require('fs');
const path = require('path');
const postcss = require('postcss');

// Parse command line arguments
const args = process.argv.slice(2);
if (args.length < 4) {
  console.error('Usage: postcss.js <input_dir> <output_dir> <config_file> <plugins>');
  console.error('Example: postcss.js input/ output/ config.json autoprefixer,cssnano');
  process.exit(1);
}

const inputDir = args[0];
const outputDir = args[1];
const configFile = args[2];
const pluginsList = args[3].split(',');

// Load configuration
let config = {};
if (fs.existsSync(configFile)) {
  config = JSON.parse(fs.readFileSync(configFile, 'utf8'));
}

// Initialize PostCSS plugins
const plugins = [];

// Add requested plugins
for (const pluginName of pluginsList) {
  switch (pluginName.trim()) {
    case 'autoprefixer':
      const autoprefixer = require('autoprefixer');
      plugins.push(autoprefixer(config.autoprefixer || {}));
      break;

    case 'cssnano':
      const cssnano = require('cssnano');
      plugins.push(cssnano(config.cssnano || { preset: 'default' }));
      break;

    case 'postcss-preset-env':
      const postcssPresetEnv = require('postcss-preset-env');
      plugins.push(postcssPresetEnv(config['postcss-preset-env'] || {}));
      break;

    case 'purgecss':
      const purgecss = require('@fullhuman/postcss-purgecss');
      plugins.push(purgecss(config.purgecss || {
        content: [path.join(inputDir, '**/*.html')],
        safelist: {
          standard: [/^hugo-/]
        }
      }));
      break;

    default:
      console.warn(`Unknown plugin: ${pluginName}`);
  }
}

if (plugins.length === 0) {
  console.error('No valid plugins specified');
  process.exit(1);
}

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
  console.log(`Plugins: ${pluginsList.join(', ')}`);

  // Copy all non-CSS files first
  copyDirectory(inputDir, outputDir);

  // Find all CSS files
  const cssFiles = findCSSFiles(inputDir);
  console.log(`Found ${cssFiles.length} CSS files to process`);

  let processed = 0;
  let totalReduction = 0;

  for (const cssFile of cssFiles) {
    try {
      const css = fs.readFileSync(cssFile, 'utf8');
      const relativePath = path.relative(inputDir, cssFile);
      const outputPath = path.join(outputDir, relativePath);

      console.log(`Processing: ${relativePath}`);

      const originalSize = css.length;

      // Process with PostCSS
      const result = await postcss(plugins).process(css, {
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

      console.log(`✓ Processed: ${originalSize} → ${newSize} bytes (${percent}% change)`);

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
  console.log(`Total size change: ${totalReduction > 0 ? '-' : '+'}${Math.abs(totalReduction)} bytes (${totalPercent}% of original CSS)`);
}

// Run the processor
processCSSFiles().catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});