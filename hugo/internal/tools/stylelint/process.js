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
  
  // Try to resolve extends in provided config
  if (config.extends) {
    const extendsArr = Array.isArray(config.extends) ? config.extends : [config.extends];
    config.extends = extendsArr.map(ext => {
      try {
        if (ext === 'stylelint-config-standard') {
            return require.resolve('stylelint-config-standard');
        }
        return ext;
      } catch (e) {
        return ext;
      }
    });
  }
} else {
  // Use standard config if no custom config provided
  try {
    const standardConfigPath = require.resolve("stylelint-config-standard");
    config = {
      extends: [standardConfigPath],
      rules: {
        // Hugo-specific overrides
        "selector-class-pattern": null, // Allow Hugo's dynamic classes
        "custom-property-pattern": null, // Allow Hugo variables
      }
    };
  } catch (e) {
    console.warn("Warning: Could not resolve stylelint-config-standard. Using basic config.");
    config = {
        rules: {
            "selector-class-pattern": null,
            "custom-property-pattern": null,
        }
    };
  }
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
      // Exclude minified files and known vendor directories
      const isMinified = file.includes('.min.');
      const isVendor = filePath.includes('/asciinema/') || filePath.includes('/katex/');
      
      if (!isMinified && !isVendor) {
        fileList.push(filePath);
      }
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
      // Ensure the file is writable so we can overwrite it if fixing
      fs.chmodSync(destPath, 0o644);
    }
  }
}

async function lintCSSFiles() {
  console.log(`Linting CSS files in ${inputDir}`);
  console.log(`Mode: ${shouldFix ? 'fix' : 'check'}`);

  // Copy directory first
  copyDirectory(inputDir, outputDir);

  // Find all CSS files in the output directory (writable copies)
  const cssFiles = findCSSFiles(outputDir);
  console.log(`Found ${cssFiles.length} CSS files to process`);

  if (cssFiles.length === 0) {
    console.log('No CSS files found to lint');
    return;
  }

  try {
    const result = await stylelint.lint({
      files: cssFiles,
      config: config,
      configBasedir: process.cwd(),
      fix: shouldFix,
      formatter: 'string',
      allowEmptyInput: true,
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
          // fileResult.source is now absolute path in outputDir
          const outputPath = fileResult.source;
          const fixedCss = fileResult._postcssResult.css;

          fs.writeFileSync(outputPath, fixedCss);
          // Calculate relative path for logging
          const relativePath = path.relative(outputDir, outputPath);
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