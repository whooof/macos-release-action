#!/bin/bash
# create-bundle.sh - Create macOS .app bundle
#
# Environment variables:
#   APP_NAME     - Application name (required)
#   BINARY_PATH  - Path to compiled binary (required)
#   PLIST_PATH   - Path to Info.plist (default: "Info.plist")
#   ICON_PATH    - Path to .icns icon (optional)
#   RESOURCES    - Additional resources to copy, space-separated (optional)
#   OUTPUT_DIR   - Output directory (default: directory of binary)
#
# Outputs (via GITHUB_OUTPUT):
#   bundle_path  - Path to created .app bundle

set -euo pipefail

APP_NAME="${APP_NAME:?APP_NAME is required}"
BINARY_PATH="${BINARY_PATH:?BINARY_PATH is required}"
PLIST_PATH="${PLIST_PATH:-Info.plist}"
ICON_PATH="${ICON_PATH:-}"
RESOURCES="${RESOURCES:-}"
OUTPUT_DIR="${OUTPUT_DIR:-}"

# Resolve paths
BINARY_PATH=$(realpath "$BINARY_PATH" 2>/dev/null || echo "$BINARY_PATH")

if [ ! -f "$BINARY_PATH" ]; then
    echo "Error: Binary not found at: $BINARY_PATH"
    exit 1
fi

if [ ! -f "$PLIST_PATH" ]; then
    echo "Error: Info.plist not found at: $PLIST_PATH"
    exit 1
fi

# Determine output directory
if [ -z "$OUTPUT_DIR" ]; then
    OUTPUT_DIR=$(dirname "$BINARY_PATH")
fi

# Create bundle structure
APP_DIR="${OUTPUT_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "Creating app bundle: $APP_DIR"

# Clean up existing bundle
rm -rf "$APP_DIR"

# Create directories
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy binary
BINARY_NAME=$(basename "$BINARY_PATH")
echo "Copying binary: $BINARY_NAME"
cp "$BINARY_PATH" "${MACOS_DIR}/${BINARY_NAME}"
chmod +x "${MACOS_DIR}/${BINARY_NAME}"

# Copy Info.plist
echo "Copying Info.plist"
cp "$PLIST_PATH" "${CONTENTS_DIR}/Info.plist"

# Copy icon if provided
if [ -n "$ICON_PATH" ] && [ -f "$ICON_PATH" ]; then
    ICON_NAME=$(basename "$ICON_PATH")
    echo "Copying icon: $ICON_NAME"
    cp "$ICON_PATH" "${RESOURCES_DIR}/${ICON_NAME}"
fi

# Copy additional resources
if [ -n "$RESOURCES" ]; then
    for resource in $RESOURCES; do
        if [ -e "$resource" ]; then
            echo "Copying resource: $resource"
            cp -R "$resource" "${RESOURCES_DIR}/"
        else
            echo "Warning: Resource not found: $resource"
        fi
    done
fi

# Verify bundle structure
echo ""
echo "Bundle structure:"
find "$APP_DIR" -type f | sed "s|$OUTPUT_DIR/||"

# Get absolute path
BUNDLE_PATH=$(realpath "$APP_DIR")

echo ""
echo "Bundle created: $BUNDLE_PATH"

# Output for GitHub Actions
if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "bundle_path=$BUNDLE_PATH" >> "$GITHUB_OUTPUT"
fi

echo "Done!"
