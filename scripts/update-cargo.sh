#!/bin/bash
# update-cargo.sh - Update version in Cargo.toml
#
# Environment variables:
#   VERSION          - New version (required)
#   CARGO_PATH       - Path to Cargo.toml (default: "Cargo.toml")
#   UPDATE_WORKSPACE - Update workspace version if present (default: "true")
#   UPDATE_LOCK      - Run cargo update after (default: "false")

set -euo pipefail

VERSION="${VERSION:?VERSION is required}"
CARGO_PATH="${CARGO_PATH:-Cargo.toml}"
UPDATE_WORKSPACE="${UPDATE_WORKSPACE:-true}"
UPDATE_LOCK="${UPDATE_LOCK:-false}"

# Validate version format (semver with optional prerelease)
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$ ]]; then
    echo "Error: Invalid version format: $VERSION"
    echo "Expected format: X.Y.Z or X.Y.Z-prerelease"
    exit 1
fi

if [ ! -f "$CARGO_PATH" ]; then
    echo "Error: Cargo.toml not found at: $CARGO_PATH"
    exit 1
fi

echo "Updating $CARGO_PATH to version $VERSION"

# Backup original
cp "$CARGO_PATH" "${CARGO_PATH}.bak"

# Check if this is a workspace Cargo.toml with [workspace.package]
if grep -q '^\[workspace\.package\]' "$CARGO_PATH" && [ "$UPDATE_WORKSPACE" = "true" ]; then
    echo "Found workspace.package section, updating workspace version..."
    
    # Update version in [workspace.package] section
    # This sed matches version = "..." after [workspace.package] section
    sed -i '' '/^\[workspace\.package\]/,/^\[/ s/^version = ".*"/version = "'"$VERSION"'"/' "$CARGO_PATH"
fi

# Check if this has a regular [package] section
if grep -q '^\[package\]' "$CARGO_PATH"; then
    # Check if version is inherited (version.workspace = true)
    if grep -q 'version\.workspace\s*=\s*true' "$CARGO_PATH"; then
        echo "Version is inherited from workspace, skipping [package] section"
    else
        echo "Updating [package] version..."
        # Update version in [package] section
        sed -i '' '/^\[package\]/,/^\[/ s/^version = ".*"/version = "'"$VERSION"'"/' "$CARGO_PATH"
    fi
fi

# Verify the change
if grep -q "version = \"$VERSION\"" "$CARGO_PATH"; then
    echo "Successfully updated version to $VERSION"
    rm "${CARGO_PATH}.bak"
else
    echo "Warning: Could not verify version update"
    echo "File contents:"
    grep -n "version" "$CARGO_PATH" | head -20
    # Restore backup
    mv "${CARGO_PATH}.bak" "$CARGO_PATH"
    exit 1
fi

# Optionally update Cargo.lock
if [ "$UPDATE_LOCK" = "true" ]; then
    echo "Running cargo update..."
    CARGO_DIR=$(dirname "$CARGO_PATH")
    (cd "$CARGO_DIR" && cargo update --workspace)
fi

echo "Done!"
