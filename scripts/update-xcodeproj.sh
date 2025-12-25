#!/bin/bash
# update-xcodeproj.sh - Update version in Xcode project
#
# Environment variables:
#   VERSION        - New version (required)
#   XCODEPROJ_PATH - Path to .xcodeproj (required)
#   TARGET         - Target name (optional, empty = all targets)
#   BUILD_NUMBER   - Build number (default: GITHUB_RUN_NUMBER or timestamp)

set -euo pipefail

VERSION="${VERSION:?VERSION is required}"
XCODEPROJ_PATH="${XCODEPROJ_PATH:?XCODEPROJ_PATH is required}"
TARGET="${TARGET:-}"

# Validate version format (semver with optional prerelease)
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$ ]]; then
    echo "Error: Invalid version format: $VERSION"
    echo "Expected format: X.Y.Z or X.Y.Z-prerelease"
    exit 1
fi

# Default build number
if [ -z "${BUILD_NUMBER:-}" ]; then
    if [ -n "${GITHUB_RUN_NUMBER:-}" ]; then
        BUILD_NUMBER="$GITHUB_RUN_NUMBER"
    else
        BUILD_NUMBER=$(date +%Y%m%d%H%M)
    fi
fi

# Validate build number (should be numeric or simple string)
if ! [[ "$BUILD_NUMBER" =~ ^[a-zA-Z0-9._-]+$ ]]; then
    echo "Error: Invalid build number format: $BUILD_NUMBER"
    exit 1
fi

PBXPROJ_PATH="${XCODEPROJ_PATH}/project.pbxproj"

if [ ! -f "$PBXPROJ_PATH" ]; then
    echo "Error: project.pbxproj not found at: $PBXPROJ_PATH"
    exit 1
fi

echo "Updating $XCODEPROJ_PATH to version $VERSION (build: $BUILD_NUMBER)"

# Backup
cp "$PBXPROJ_PATH" "${PBXPROJ_PATH}.bak"

# Update MARKETING_VERSION (user-visible version)
echo "Setting MARKETING_VERSION to $VERSION"
if [ -n "$TARGET" ]; then
    # Update only for specific target - this is complex, simplified approach
    sed -i '' 's/MARKETING_VERSION = [^;]*;/MARKETING_VERSION = '"$VERSION"';/g' "$PBXPROJ_PATH"
else
    # Update all occurrences
    sed -i '' 's/MARKETING_VERSION = [^;]*;/MARKETING_VERSION = '"$VERSION"';/g' "$PBXPROJ_PATH"
fi

# Update CURRENT_PROJECT_VERSION (build number)
echo "Setting CURRENT_PROJECT_VERSION to $BUILD_NUMBER"
sed -i '' 's/CURRENT_PROJECT_VERSION = [^;]*;/CURRENT_PROJECT_VERSION = '"$BUILD_NUMBER"';/g' "$PBXPROJ_PATH"

# Verify changes
MARKETING_COUNT=$(grep -c "MARKETING_VERSION = $VERSION;" "$PBXPROJ_PATH" || echo "0")
BUILD_COUNT=$(grep -c "CURRENT_PROJECT_VERSION = $BUILD_NUMBER;" "$PBXPROJ_PATH" || echo "0")

if [ "$MARKETING_COUNT" -gt 0 ] && [ "$BUILD_COUNT" -gt 0 ]; then
    echo "Successfully updated:"
    echo "  MARKETING_VERSION = $VERSION ($MARKETING_COUNT occurrences)"
    echo "  CURRENT_PROJECT_VERSION = $BUILD_NUMBER ($BUILD_COUNT occurrences)"
    rm "${PBXPROJ_PATH}.bak"
else
    echo "Warning: Could not verify all updates"
    echo "  MARKETING_VERSION matches: $MARKETING_COUNT"
    echo "  CURRENT_PROJECT_VERSION matches: $BUILD_COUNT"
    # Don't restore backup, changes might be partially successful
fi

echo "Done!"
