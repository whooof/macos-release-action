#!/bin/bash
# create-universal.sh - Create universal binary from arm64 and x86_64
#
# Environment variables:
#   ARM64_BINARY  - Path to arm64 binary (required)
#   X86_64_BINARY - Path to x86_64 binary (required)
#   OUTPUT_PATH   - Output path for universal binary (required)

set -euo pipefail

ARM64_BINARY="${ARM64_BINARY:?ARM64_BINARY is required}"
X86_64_BINARY="${X86_64_BINARY:?X86_64_BINARY is required}"
OUTPUT_PATH="${OUTPUT_PATH:?OUTPUT_PATH is required}"

# Verify binaries exist
if [ ! -f "$ARM64_BINARY" ]; then
    echo "Error: arm64 binary not found: $ARM64_BINARY"
    exit 1
fi

if [ ! -f "$X86_64_BINARY" ]; then
    echo "Error: x86_64 binary not found: $X86_64_BINARY"
    exit 1
fi

# Verify architectures
echo "Verifying architectures..."

ARM64_ARCH=$(lipo -info "$ARM64_BINARY" 2>/dev/null | grep -o 'arm64' || echo "")
X86_ARCH=$(lipo -info "$X86_64_BINARY" 2>/dev/null | grep -o 'x86_64' || echo "")

if [ -z "$ARM64_ARCH" ]; then
    echo "Warning: $ARM64_BINARY may not be arm64"
    lipo -info "$ARM64_BINARY" || true
fi

if [ -z "$X86_ARCH" ]; then
    echo "Warning: $X86_64_BINARY may not be x86_64"
    lipo -info "$X86_64_BINARY" || true
fi

# Create output directory if needed
OUTPUT_DIR=$(dirname "$OUTPUT_PATH")
mkdir -p "$OUTPUT_DIR"

# Create universal binary
echo "Creating universal binary..."
echo "  arm64:  $ARM64_BINARY"
echo "  x86_64: $X86_64_BINARY"
echo "  output: $OUTPUT_PATH"

lipo -create -output "$OUTPUT_PATH" "$ARM64_BINARY" "$X86_64_BINARY"

# Verify result
echo ""
echo "Verifying universal binary:"
lipo -info "$OUTPUT_PATH"

# Set executable permissions
chmod +x "$OUTPUT_PATH"

echo ""
echo "Universal binary created: $OUTPUT_PATH"
echo "Done!"
