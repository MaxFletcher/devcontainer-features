#!/bin/bash
set -e

TARGET_VERSION=${VERSION:-"latest"}
INSTALL_DIR="/opt/agones-sdk"
SYMLINK_PATH="/usr/local/bin/sdk-server"

echo "Activating Devcontainer Feature: Agones SDK Server"

# Safely check for tools without letting set -e crash the engine
HAS_CURL=$(type curl > /dev/null 2>&1 && echo "yes" || echo "no")
HAS_JQ=$(type jq > /dev/null 2>&1 && echo "yes" || echo "no")

if [ "${HAS_CURL}" = "no" ] || [ "${HAS_JQ}" = "no" ]; then
    echo "Installing missing dependencies..."
    if [ -x "$(command -v apt-get)" ]; then
        apt-get update && apt-get install -y curl ca-certificates jq
    elif [ -x "$(command -v apk)" ]; then
        apk add --no-cache curl ca-certificates jq
    else
        echo "Warning: Could not determine package manager to install curl/jq."
    fi
fi

# Detect host system architecture
ARCH=$(uname -m)
case ${ARCH} in
    x86_64)  AGONES_ARCH="amd64" ;;
    aarch64|arm64) AGONES_ARCH="arm64" ;;
    *) echo "Unsupported architecture: ${ARCH}"; exit 1 ;;
esac

# Resolve version via GitHub API if "latest" requested
if [ "${TARGET_VERSION}" = "latest" ]; then
    echo "Fetching latest version string from GitHub..."
    # Run inline subshells inside conditional blocks to protect set -e
    LATEST_JSON=$(curl -s https://github.com || echo "")
    if [ -n "${LATEST_JSON}" ]; then
        TARGET_VERSION=$(echo "${LATEST_JSON}" | jq -r '.tag_name')
    else
        echo "Error: Failed to fetch latest release metadata from GitHub API."
        exit 1
    fi
fi

# Clean string formatting (e.g., v1.61.0 -> 1.61.0)
VERSION_NUM=$(echo "${TARGET_VERSION}" | sed 's/^v//')

echo "Downloading Agones SDK Server: ${TARGET_VERSION} (${AGONES_ARCH})"

# Point directly to the standalone uncompressed binary release asset mapped by Agones
DOWNLOAD_URL="https://github.com{TARGET_VERSION}/agonessdk-server-${VERSION_NUM}-linux-${AGONES_ARCH}"

# Create target isolation directories
mkdir -p "${INSTALL_DIR}"
TARGET_EXEC="${INSTALL_DIR}/sdk-server"

# Download the standalone binary directly
HTTP_STATUS=$(curl -sSL -w "%{http_code}" -o "${TARGET_EXEC}" "${DOWNLOAD_URL}")

if [ "${HTTP_STATUS}" -ne 200 ]; then
    echo "Error: Failed to download asset. GitHub API returned HTTP Status: ${HTTP_STATUS}"
    echo "Attempted URL: ${DOWNLOAD_URL}"
    exit 1
fi

# Ensure executable flags are raised
chmod +x "${TARGET_EXEC}"

# Establish the global symlink layer cleanly
if [ -L "${SYMLINK_PATH}" ] || [ -f "${SYMLINK_PATH}" ]; then
    rm "${SYMLINK_PATH}"
fi
ln -s "${TARGET_EXEC}" "${SYMLINK_PATH}"

echo "Agones SDK Server successfully verified and configured at ${SYMLINK_PATH}"
