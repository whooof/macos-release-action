#!/bin/bash
# update-plist.sh - Update version in Info.plist
#
# Environment variables:
#   VERSION             - New version (required)
#   PLIST_PATH          - Path to Info.plist (default: "Info.plist")
#   BUILD_NUMBER        - Build number (default: GITHUB_RUN_NUMBER or timestamp)
#   UPDATE_BUILD_NUMBER - Update CFBundleVersion (default: "true")

set -euo pipefail

VERSION="${VERSION:?VERSION is required}"
PLIST_PATH="${PLIST_PATH:-Info.plist}"
UPDATE_BUILD_NUMBER="${UPDATE_BUILD_NUMBER:-true}"

# Default build number
if [ -z "${BUILD_NUMBER:-}" ]; then
    if [ -n "${GITHUB_RUN_NUMBER:-}" ]; then
        BUILD_NUMBER="$GITHUB_RUN_NUMBER"
    else
        BUILD_NUMBER=$(date +%Y%m%d%H%M)
    fi
fi

if [ ! -f "$PLIST_PATH" ]; then
    echo "Error: Info.plist not found at: $PLIST_PATH"
    exit 1
fi

echo "Updating $PLIST_PATH to version $VERSION (build: $BUILD_NUMBER)"

# Check if PlistBuddy is available (macOS)
if command -v /usr/libexec/PlistBuddy &> /dev/null; then
    PLIST_BUDDY="/usr/libexec/PlistBuddy"
    
    # Update CFBundleShortVersionString (marketing version)
    echo "Setting CFBundleShortVersionString to $VERSION"
    "$PLIST_BUDDY" -c "Set :CFBundleShortVersionString $VERSION" "$PLIST_PATH" 2>/dev/null || \
    "$PLIST_BUDDY" -c "Add :CFBundleShortVersionString string $VERSION" "$PLIST_PATH"
    
    # Update CFBundleVersion (build number)
    if [ "$UPDATE_BUILD_NUMBER" = "true" ]; then
        echo "Setting CFBundleVersion to $BUILD_NUMBER"
        "$PLIST_BUDDY" -c "Set :CFBundleVersion $BUILD_NUMBER" "$PLIST_PATH" 2>/dev/null || \
        "$PLIST_BUDDY" -c "Add :CFBundleVersion string $BUILD_NUMBER" "$PLIST_PATH"
    fi
else
    # Fallback to sed (less reliable)
    echo "Warning: PlistBuddy not found, using sed fallback"
    
    # Backup
    cp "$PLIST_PATH" "${PLIST_PATH}.bak"
    
    # Update CFBundleShortVersionString
    # This is tricky with plists - look for the key and update the next <string> tag
    sed -i '' '/<key>CFBundleShortVersionString<\/key>/{ n; s/<string>[^<]*<\/string>/<string>'"$VERSION"'<\/string>/; }' "$PLIST_PATH"
    
    if [ "$UPDATE_BUILD_NUMBER" = "true" ]; then
        sed -i '' '/<key>CFBundleVersion<\/key>/{ n; s/<string>[^<]*<\/string>/<string>'"$BUILD_NUMBER"'<\/string>/; }' "$PLIST_PATH"
    fi
    
    rm "${PLIST_PATH}.bak"
fi

# Verify changes
echo "Verification:"
if command -v /usr/libexec/PlistBuddy &> /dev/null; then
    echo "  CFBundleShortVersionString: $("$PLIST_BUDDY" -c "Print :CFBundleShortVersionString" "$PLIST_PATH")"
    if [ "$UPDATE_BUILD_NUMBER" = "true" ]; then
        echo "  CFBundleVersion: $("$PLIST_BUDDY" -c "Print :CFBundleVersion" "$PLIST_PATH")"
    fi
else
    grep -A1 "CFBundleShortVersionString\|CFBundleVersion" "$PLIST_PATH"
fi

echo "Done!"
