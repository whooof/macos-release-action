#!/bin/bash
# bump-version.sh - Calculate new semantic version
# 
# Environment variables:
#   RELEASE_TYPE    - patch | minor | major | custom (required)
#   CUSTOM_VERSION  - Custom version (required if RELEASE_TYPE=custom)
#   TAG_PREFIX      - Tag prefix (default: "v")
#
# Outputs (via GITHUB_OUTPUT):
#   version          - New version (e.g., 1.2.3)
#   tag              - New tag (e.g., v1.2.3)
#   previous_version - Previous version
#   previous_tag     - Previous tag
#   is_prerelease    - "true" if version contains "-"

set -euo pipefail

# Defaults
TAG_PREFIX="${TAG_PREFIX:-v}"
RELEASE_TYPE="${RELEASE_TYPE:-patch}"
CUSTOM_VERSION="${CUSTOM_VERSION:-}"

# Validate release type
if ! [[ "$RELEASE_TYPE" =~ ^(patch|minor|major|custom)$ ]]; then
    echo "Error: Invalid release type: $RELEASE_TYPE"
    echo "Expected: patch | minor | major | custom"
    exit 1
fi

# Validate tag prefix (alphanumeric and limited special chars only)
if ! [[ "$TAG_PREFIX" =~ ^[a-zA-Z0-9._-]*$ ]]; then
    echo "Error: Invalid tag prefix: $TAG_PREFIX"
    exit 1
fi

# Get latest tag
LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "${TAG_PREFIX}0.0.0")
echo "Latest tag: $LATEST_TAG"

# Store previous values
PREVIOUS_TAG="$LATEST_TAG"
PREVIOUS_VERSION="${LATEST_TAG#$TAG_PREFIX}"

# Handle custom version
if [ "$RELEASE_TYPE" = "custom" ]; then
    if [ -z "$CUSTOM_VERSION" ]; then
        echo "Error: CUSTOM_VERSION is required when RELEASE_TYPE=custom"
        exit 1
    fi
    # Remove tag prefix if provided
    NEW_VERSION="${CUSTOM_VERSION#$TAG_PREFIX}"
    
    # Validate custom version format
    if ! [[ "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$ ]]; then
        echo "Error: Invalid custom version format: $NEW_VERSION"
        echo "Expected format: X.Y.Z or X.Y.Z-prerelease"
        exit 1
    fi
else
    # Parse current version
    CURRENT="${LATEST_TAG#$TAG_PREFIX}"
    
    # Split version into components (handle prerelease)
    # 1.2.3-beta.1 -> MAJOR=1, MINOR=2, PATCH=3, PRERELEASE=beta.1
    if [[ "$CURRENT" == *"-"* ]]; then
        BASE_VERSION="${CURRENT%%-*}"
        PRERELEASE="${CURRENT#*-}"
    else
        BASE_VERSION="$CURRENT"
        PRERELEASE=""
    fi
    
    IFS='.' read -r MAJOR MINOR PATCH <<< "$BASE_VERSION"
    
    # Default to 0 if not set
    MAJOR=${MAJOR:-0}
    MINOR=${MINOR:-0}
    PATCH=${PATCH:-0}
    
    echo "Current: $MAJOR.$MINOR.$PATCH (prerelease: ${PRERELEASE:-none})"
    
    # Bump version
    case "$RELEASE_TYPE" in
        major)
            MAJOR=$((MAJOR + 1))
            MINOR=0
            PATCH=0
            ;;
        minor)
            MINOR=$((MINOR + 1))
            PATCH=0
            ;;
        patch)
            PATCH=$((PATCH + 1))
            ;;
        *)
            echo "Error: Unknown release type: $RELEASE_TYPE"
            exit 1
            ;;
    esac
    
    NEW_VERSION="$MAJOR.$MINOR.$PATCH"
fi

# Create new tag
NEW_TAG="${TAG_PREFIX}${NEW_VERSION}"

# Check if tag already exists
if git tag -l "$NEW_TAG" | grep -q "^$NEW_TAG$"; then
    echo "Error: Tag $NEW_TAG already exists!"
    exit 1
fi

# Determine if prerelease
IS_PRERELEASE="false"
if [[ "$NEW_VERSION" == *"-"* ]]; then
    IS_PRERELEASE="true"
fi

echo "New version: $NEW_VERSION"
echo "New tag: $NEW_TAG"
echo "Is prerelease: $IS_PRERELEASE"

# Output for GitHub Actions
if [ -n "${GITHUB_OUTPUT:-}" ]; then
    {
        echo "version=$NEW_VERSION"
        echo "tag=$NEW_TAG"
        echo "previous_version=$PREVIOUS_VERSION"
        echo "previous_tag=$PREVIOUS_TAG"
        echo "is_prerelease=$IS_PRERELEASE"
    } >> "$GITHUB_OUTPUT"
fi

# Also output to stdout for local testing
echo "---"
echo "version=$NEW_VERSION"
echo "tag=$NEW_TAG"
echo "previous_version=$PREVIOUS_VERSION"
echo "previous_tag=$PREVIOUS_TAG"
echo "is_prerelease=$IS_PRERELEASE"
