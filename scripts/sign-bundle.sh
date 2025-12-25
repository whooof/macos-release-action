#!/bin/bash
# sign-bundle.sh - Sign macOS app bundle
#
# Environment variables:
#   BUNDLE_PATH   - Path to .app bundle (required)
#   IDENTITY      - Signing identity (optional, empty = ad-hoc)
#   ENTITLEMENTS  - Path to entitlements.plist (optional)
#
# Outputs (via GITHUB_OUTPUT):
#   signed        - "true" if signing succeeded

set -euo pipefail

BUNDLE_PATH="${BUNDLE_PATH:?BUNDLE_PATH is required}"
IDENTITY="${IDENTITY:-}"
ENTITLEMENTS="${ENTITLEMENTS:-}"

if [ ! -d "$BUNDLE_PATH" ]; then
    echo "Error: Bundle not found: $BUNDLE_PATH"
    exit 1
fi

echo "Signing bundle: $BUNDLE_PATH"

# Build codesign command
CODESIGN_ARGS=(--force --deep)

if [ -n "$IDENTITY" ]; then
    echo "Using identity: $IDENTITY"
    CODESIGN_ARGS+=(--sign "$IDENTITY")
else
    echo "Using ad-hoc signing"
    CODESIGN_ARGS+=(--sign -)
fi

if [ -n "$ENTITLEMENTS" ]; then
    if [ -f "$ENTITLEMENTS" ]; then
        echo "Using entitlements: $ENTITLEMENTS"
        CODESIGN_ARGS+=(--entitlements "$ENTITLEMENTS")
    else
        echo "Warning: Entitlements file not found: $ENTITLEMENTS"
    fi
fi

# Enable hardened runtime for notarization compatibility
if [ -n "$IDENTITY" ]; then
    CODESIGN_ARGS+=(--options runtime)
fi

# Sign the bundle
echo "Running: codesign ${CODESIGN_ARGS[*]} $BUNDLE_PATH"
codesign "${CODESIGN_ARGS[@]}" "$BUNDLE_PATH"

# Verify signature
echo ""
echo "Verifying signature..."
if codesign --verify --verbose=2 "$BUNDLE_PATH"; then
    echo "Signature verified successfully"
    SIGNED="true"
else
    echo "Warning: Signature verification failed"
    SIGNED="false"
fi

# Display signature info
echo ""
echo "Signature info:"
codesign -dv "$BUNDLE_PATH" 2>&1 | head -10

# Output for GitHub Actions
if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "signed=$SIGNED" >> "$GITHUB_OUTPUT"
fi

echo ""
echo "Done!"
