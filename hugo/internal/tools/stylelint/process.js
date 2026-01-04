#!/usr/bin/env node
/**
 * Stylelint processor for Hugo sites
 * Lints CSS files using Stylelint
 */

const fs = require('fs');
const path = require('path');
const stylelint = require('stylelint');

// Parse command line arguments
const args = process.argv.slice(2);
if (args.length < 3) {
  console.error('Usage: stylelint.js <input_dir> <output_dir> <config_file> [fix]');
  console.error('Example: stylelint.js input/ output/ .stylelintrc.json');
  process.exit(1);
}

const inputDir = args[0];
const outputDir = args[1];
const configFile = args[2];
const shouldFix = args[3] === 'fix';

// Load configuration
let config = {};
if (fs.existsSync(configFile)) {
  config = JSON.parse(fs.readFileSync(configFile, 'utf8'));
} else {
  // Use standard config if no custom config provided
  config = {
    extends: ["stylelint-config-standard"],
    rules: {
      // Hugo-specific overrides
      "selector-class-pattern": null, // Allow Hugo's dynamic classes
      "custom-property-pattern": null, // Allow Hugo variables
    }
  };
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

// Copy directory (for both linting and fixing modes)
function copyDirectory(src, dest) {
  fs.mkdirSync(dest, { recursive: true });
  const entries = fs.readdirSync(src, { withFileTypes: true });

  for (const entry of entries) {
    const srcPath = path.join(src, entry.name);
    const destPath = path.join(dest, entry.name);

    if (entry.isDirectory()) {
      copyDirectory(srcPath, destPath);
    } else {
      fs.copyFileSync(srcPath, destPath);
    }
  }
}

async function lintCSSFiles() {
  console.log(`Linting CSS files in ${inputDir}`);
  console.log(`Mode: ${shouldFix ? 'fix' : 'check'}`);

  // Find all CSS files
  const cssFiles = findCSSFiles(inputDir);
  console.log(`Found ${cssFiles.length} CSS files to process`);

  if (cssFiles.length === 0) {
    console.log('No CSS files found to lint');
    // Copy directory even if no CSS files
    copyDirectory(inputDir, outputDir);
    return;
  }

  // Copy directory first
  copyDirectory(inputDir, outputDir);

  try {
    const result = await stylelint.lint({
      files: cssFiles,
      config: config,
      fix: shouldFix,
      formatter: 'string',
    });

    // Output results
    if (result.output) {
      console.log(result.output);
    }

    // Handle results
    const errored = result.results.filter(r => r.errored);
    const warnings = result.results.filter(r => r.warnings && r.warnings.length > 0);

    console.log(`\nLinting Summary:`);
    console.log(`Files processed: ${result.results.length}`);
    console.log(`Files with errors: ${errored.length}`);
    console.log(`Files with warnings: ${warnings.length}`);

    if (errored.length > 0) {
      console.error('\n❌ Linting failed - errors found');
      process.exit(1);
    } else if (warnings.length > 0) {
      console.warn('\n⚠️  Linting passed with warnings');
    } else {
      console.log('\n✅ Linting passed - no issues found');
    }

    // If fixing, overwrite files in output directory
    if (shouldFix) {
      for (const fileResult of result.results) {
        if (fileResult.source && fileResult._postcssResult) {
          const relativePath = path.relative(inputDir, fileResult.source);
          const outputPath = path.join(outputDir, relativePath);
          const fixedCss = fileResult._postcssResult.css;

          fs.writeFileSync(outputPath, fixedCss);
          console.log(`Fixed: ${relativePath}`);
        }
      }
    }

  } catch (error) {
    console.error('Stylelint error:', error.message);
    process.exit(1);
  }
}

// Run the linter
lintCSSFiles().catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});