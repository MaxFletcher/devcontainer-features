#!/bin/bash
set -e

# The devcontainer CLI exposes options as environment variables prefixed with the option name in uppercase.
# Here, the option 'version' maps to the variable $VERSION.
TARGET_VERSION=${VERSION:-"latest"}
INSTALL_DIR="/opt/agones-sdk"
SYMLINK_PATH="/usr/local/bin/sdk-server"

echo "Activating Devcontainer Feature: Agones SDK Server"

# Ensure curl, ca-certificates, and jq are installed (required for fetching the release)
if ! type curl > /dev/null 2>&1 || ! type jq > /dev/null 2>&1; then
    if [ -x "$(command -v apt-get)" ]; then
        apt-get update && apt-get install -y curl ca-certificates jq
    elif [ -x "$(command -v apk)" ]; then
        apk add --no-cache curl ca-certificates jq
    fi
fi

# Detect system architecture
ARCH=$(uname -m)
case ${ARCH} in
    x86_64)  AGONES_ARCH="amd64" ;;
    aarch64|arm64) AGONES_ARCH="arm64" ;;
    *) echo "Unsupported architecture: ${ARCH}"; exit 1 ;;
esac

# Resolve version via GitHub API if "latest" is specified
if [ "${TARGET_VERSION}" = "latest" ]; then
    echo "Fetching latest version string from GitHub..."
    TARGET_VERSION=$(curl -s https://github.com | jq -r '.tag_name')
fi

# Remove the 'v' prefix if present to properly match the asset nomenclature (e.g., v1.61.0 -> 1.61.0)
VERSION_NUM=$(echo "${TARGET_VERSION}" | sed 's/^v//')

echo "Downloading Agones SDK Server version: ${TARGET_VERSION} (${AGONES_ARCH})"

# Define asset details based on typical Agones release tarball distributions
# Note: Ensure the target URL structure matches your architectural needs or falls back to standard go-runner archives
DOWNLOAD_URL="https://github.com{TARGET_VERSION}/agonessdk-server-${VERSION_NUM}-linux-${AGONES_ARCH}.tar.gz"

# Create a staging environment
TMP_DIR=$(mktemp -d)
TARBALL_PATH="${TMP_DIR}/agones_sdk.tar.gz"

# Download the release asset
curl -sSL -o "${TARBALL_PATH}" "${DOWNLOAD_URL}"

# Unpack and map binaries into /opt
mkdir -p "${INSTALL_DIR}"
tar -xzf "${TARBALL_PATH}" -C "${INSTALL_DIR}"

# Locate the actual executable inside the extracted payload
# Depending on the release layout, it might be nested under a specific folder pattern
EXEC_PATH=$(find "${INSTALL_DIR}" -type f -name "sdk-server" | head -n 1)

if [ -z "${EXEC_PATH}" ]; then
    echo "Error: Could not locate 'sdk-server' executable in the downloaded archive."
    exit 1
fi

# Make the target executable
chmod +x "${EXEC_PATH}"

# Generate the global symlink execution layer
if [ -L "${SYMLINK_PATH}" ] || [ -f "${SYMLINK_PATH}" ]; then
    rm "${SYMLINK_PATH}"
fi
ln -s "${EXEC_PATH}" "${SYMLINK_PATH}"

# Clean up temp assets
rm -rf "${TMP_DIR}"

echo "Agones SDK Server successfully installed to ${EXEC_PATH}"
echo "Symlink created at ${SYMLINK_PATH}"
