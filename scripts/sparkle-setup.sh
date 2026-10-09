#!/bin/bash
# Sparkle EdDSA Key Setup
#
# This script generates an EdDSA key pair for Sparkle update signing.
# Run this ONCE during initial setup.
#
# Usage: ./scripts/sparkle-setup.sh
#
# After running:
# 1. Copy the PUBLIC key to Sources/App/Info.plist (SUPublicEDKey)
# 2. Store the PRIVATE key as a GitHub secret (SPARKLE_EDDSA_PRIVATE_KEY)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Find Sparkle's generate_keys tool
GENERATE_KEYS=""
for path in \
    "$PROJECT_ROOT/Tuist/.build/artifacts/sparkle/Sparkle/bin/generate_keys" \
    "$PROJECT_ROOT/.build/artifacts/sparkle/Sparkle/bin/generate_keys" \
    "$PROJECT_ROOT/.build/checkouts/Sparkle/generate_keys"
do
    if [ -x "$path" ]; then
        GENERATE_KEYS="$path"
        break
    fi
done

if [ -z "$GENERATE_KEYS" ]; then
    echo "Error: generate_keys not found. Run "tuist install" first."
    exit 1
fi

echo "=== Sparkle EdDSA Key Generation ==="
echo ""
echo "This will generate a new EdDSA key pair for signing Sparkle updates."
echo ""

# Generate the keys
# The generate_keys tool outputs to stderr, so we capture it
OUTPUT=$("$GENERATE_KEYS" 2>&1)

echo "$OUTPUT"
echo ""
echo "=== IMPORTANT: Save these keys! ==="
echo ""
echo "1. PUBLIC KEY (for Info.plist):"
echo "   Add to Sources/App/Info.plist under SUPublicEDKey"
echo ""
echo "2. PRIVATE KEY (for GitHub Secrets):"
echo "   Add as repository secret: SPARKLE_EDDSA_PRIVATE_KEY"
echo ""
echo "The private key is sensitive - never commit it to the repository!"
