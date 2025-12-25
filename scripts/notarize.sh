#!/bin/bash
# notarize.sh - Notarize macOS app bundle with Apple
#
# Environment variables:
#   BUNDLE_PATH  - Path to .app bundle (required)
#   APPLE_ID     - Apple ID email (required)
#   TEAM_ID      - Apple Developer Team ID (required)
#   APP_PASSWORD - App-specific password (required)
#
# Outputs (via GITHUB_OUTPUT):
#   notarized    - "true" if notarization succeeded

set -euo pipefail

BUNDLE_PATH="${BUNDLE_PATH:?BUNDLE_PATH is required}"
APPLE_ID="${APPLE_ID:?APPLE_ID is required}"
TEAM_ID="${TEAM_ID:?TEAM_ID is required}"
APP_PASSWORD="${APP_PASSWORD:?APP_PASSWORD is required}"

if [ ! -d "$BUNDLE_PATH" ]; then
    echo "Error: Bundle not found: $BUNDLE_PATH"
    exit 1
fi

echo "Notarizing bundle: $BUNDLE_PATH"

# Create a temporary directory for the zip
TEMP_DIR=$(mktemp -d)
BUNDLE_NAME=$(basename "$BUNDLE_PATH")
APP_NAME="${BUNDLE_NAME%.app}"
ZIP_PATH="${TEMP_DIR}/${APP_NAME}.zip"

# Create ZIP archive
echo "Creating ZIP archive..."
ditto -c -k --keepParent "$BUNDLE_PATH" "$ZIP_PATH"
echo "ZIP created: $ZIP_PATH ($(du -h "$ZIP_PATH" | cut -f1))"

# Submit for notarization
echo ""
echo "Submitting for notarization..."
SUBMIT_OUTPUT=$(xcrun notarytool submit "$ZIP_PATH" \
    --apple-id "$APPLE_ID" \
    --team-id "$TEAM_ID" \
    --password "$APP_PASSWORD" \
    --wait \
    --timeout 30m \
    2>&1) || true

echo "$SUBMIT_OUTPUT"

# Check result
if echo "$SUBMIT_OUTPUT" | grep -q "status: Accepted"; then
    echo ""
    echo "Notarization accepted!"
    
    # Staple the ticket
    echo "Stapling ticket to bundle..."
    if xcrun stapler staple "$BUNDLE_PATH"; then
        echo "Ticket stapled successfully"
        NOTARIZED="true"
    else
        echo "Warning: Failed to staple ticket"
        NOTARIZED="true"  # Still notarized, just not stapled
    fi
elif echo "$SUBMIT_OUTPUT" | grep -q "status: Invalid"; then
    echo ""
    echo "Error: Notarization failed - Invalid"
    
    # Try to get the log
    SUBMISSION_ID=$(echo "$SUBMIT_OUTPUT" | grep -o 'id: [a-f0-9-]*' | head -1 | cut -d' ' -f2)
    if [ -n "$SUBMISSION_ID" ]; then
        echo ""
        echo "Fetching notarization log..."
        xcrun notarytool log "$SUBMISSION_ID" \
            --apple-id "$APPLE_ID" \
            --team-id "$TEAM_ID" \
            --password "$APP_PASSWORD" || true
    fi
    
    NOTARIZED="false"
else
    echo ""
    echo "Error: Notarization status unknown"
    NOTARIZED="false"
fi

# Cleanup
rm -rf "$TEMP_DIR"

# Output for GitHub Actions
if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "notarized=$NOTARIZED" >> "$GITHUB_OUTPUT"
fi

echo ""
if [ "$NOTARIZED" = "true" ]; then
    echo "Notarization complete!"
else
    echo "Notarization failed"
    exit 1
fi
