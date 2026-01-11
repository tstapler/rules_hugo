#!/bin/bash
# Hugo site minification script using shell tools
# Supports HTML, CSS, JS, XML, JSON file types

set -euo pipefail

# Minification functions using sed and shell tools

# HTML minification: remove comments and collapse whitespace
minify_html() {
    local input_file="$1"
    local output_file="$2"

    # Remove HTML comments (<!-- ... -->) but preserve conditional comments
    # Remove extra whitespace between tags
    # Collapse multiple spaces/tabs to single space
    sed -e 's/<!--[^!]*-->//g' \
        -e 's/>[[:space:]]\+</></g' \
        -e 's/^[[:space:]]\+//' \
        -e 's/[[:space:]]\+$//' \
        -e '/^[[:space:]]*$/d' \
        "$input_file" > "$output_file"
}

# CSS minification: remove comments and reduce whitespace
minify_css() {
    local input_file="$1"
    local output_file="$2"

    # Remove CSS comments (lines starting with /*) and extra whitespace
    grep -v '^[[:space:]]*/\*' "$input_file" | \
    sed 's/[[:space:]]\+/ /g' | \
    sed 's/; /;/g' | \
    sed 's/: /:/g' | \
    sed 's/ {/{/g' | \
    sed 's/{ /{/g' | \
    sed 's/ }/}/g' | \
    tr -d '\n' | \
    sed 's/}/}\n/g' > "$output_file"
}

# JavaScript minification: remove comments and reduce whitespace
minify_js() {
    local input_file="$1"
    local output_file="$2"

    # Remove single-line comments (// ...)
    # Remove comment lines (/* ... */)
    # Collapse whitespace
    sed 's|//.*$||g' "$input_file" | \
    grep -v '^[[:space:]]*/\*' | \
    sed 's/[[:space:]]\+/ /g' | \
    sed 's/; /;/g' | \
    sed 's/, /,/g' | \
    sed 's/( /(/g' | \
    sed 's/ )/)/g' | \
    sed 's/{ /{/g' | \
    sed 's/ }/}/g' | \
    sed 's/= /=/g' | \
    sed 's/ =/=/g' > "$output_file"
}

# XML minification: remove comments and collapse whitespace
minify_xml() {
    local input_file="$1"
    local output_file="$2"

    # Remove XML comments (<!-- ... -->)
    # Collapse whitespace between tags
    sed -e 's/<!--[^>]*-->//g' \
        -e 's/>[[:space:]]\+</></g' \
        -e 's/^[[:space:]]\+//' \
        -e 's/[[:space:]]\+$//' \
        "$input_file" > "$output_file"
}

# JSON minification: remove comments and collapse whitespace
minify_json() {
    local input_file="$1"
    local output_file="$2"

    # Remove JSON comments (// ... and /* ... */)
    # Collapse whitespace
    sed -e 's|//.*$||g' \
        -e 's|/\*[^*]*\*\+\([^/*][^*]*\*\+\)*/||g' \
        -e 's|/\*[^*]*\*\+\([^/*][^*]*\*\+\)*/||g' \
        -e 's/[[:space:]]\+/ /g' \
        "$input_file" > "$output_file"
}

# Main minification function
minify_file() {
    local input_file="$1"
    local output_file="$2"
    local extension="$3"

    # Create output directory if it doesn't exist
    mkdir -p "$(dirname "$output_file")"

    case "$extension" in
        html)
            minify_html "$input_path" "$output_path"
            ;;
        css)
            minify_css "$input_path" "$output_path"
            ;;
        js)
            minify_js "$input_path" "$output_path"
            ;;
        xml)
            minify_xml "$input_path" "$output_path"
            ;;
        json)
            minify_json "$input_path" "$output_path"
            ;;
        *)
            # Copy file unchanged for unsupported extensions
            cp "$input_path" "$output_path"
            ;;
    esac
}

# Main script logic
main() {
    local site_dir="$1"
    local output_dir="$2"
    local extensions="$3"

    # Convert to absolute paths
    site_dir="$(cd "$site_dir" && pwd)"
    output_dir="$(cd "$(dirname "$output_dir")" && pwd)/$(basename "$output_dir")"

    echo "Minifying files from $site_dir to $output_dir"
    echo "Processing extensions: $extensions"

    # Create output directory
    mkdir -p "$output_dir"

    # Create directory structure in output
    find "$site_dir" -type d | while read -r dir; do
        relative_dir="${dir#$site_dir/}"
        if [ -n "$relative_dir" ]; then
            mkdir -p "$output_dir/$relative_dir"
        fi
    done

    # Build find arguments for extensions
    local find_args=()
    IFS=',' read -ra EXT_ARRAY <<< "$extensions"
    for ext in "${EXT_ARRAY[@]}"; do
        if [ ${#find_args[@]} -gt 0 ]; then
            find_args+=(-o)
        fi
        find_args+=(-name "*.${ext}")
    done

    find -L "$site_dir" -type f \( "${find_args[@]}" \) 2>/dev/null | while read -r input_path; do
        # Get relative path from site_dir
        local relative_path="${input_path#$site_dir/}"
        local output_path="$output_dir/$relative_path"
        local file_extension="${input_path##*.}"

        minify_file "$input_path" "$output_path" "$file_extension"
    done

    echo "Minification complete"
}

# Check arguments
if [ $# -ne 3 ]; then
    echo "Usage: $0 <site_dir> <output_dir> <extensions>"
    echo "Example: $0 /path/to/site /path/to/output html,css,js,xml,json"
    exit 1
fi

main "$@"