#!/bin/bash
set -e

TARGET_VERSION=${VERSION:-"latest"}
INSTALL_DIR="/opt/agones-sdk"
SYMLINK_PATH="/usr/local/bin/sdk-server"

echo "Activating Devcontainer Feature: Agones SDK Server"

# Ensure runtime tools are installed safely
HAS_CURL=$(type curl > /dev/null 2>&1 && echo "yes" || echo "no")
HAS_UNZIP=$(type unzip > /dev/null 2>&1 && echo "yes" || echo "no")

if [ "${HAS_CURL}" = "no" ] || [ "${HAS_UNZIP}" = "no" ]; then
    echo "Installing missing runtime utility dependencies (curl, unzip)..."
    if [ -x "$(command -v apt-get)" ]; then
        apt-get update && apt-get install -y curl ca-certificates unzip
    elif [ -x "$(command -v apk)" ]; then
        apk add --no-cache curl ca-certificates unzip
    fi
fi

# Detect system architecture layer
ARCH=$(uname -m)
case ${ARCH} in
    x86_64)  AGONES_ARCH="amd64" ;;
    aarch64|arm64) AGONES_ARCH="arm64" ;;
    *) echo "Unsupported architecture: ${ARCH}"; exit 1 ;;
esac

# Resolve version via git tags if "latest" requested to completely avoid API rate limits
if [ "${TARGET_VERSION}" = "latest" ]; then
    echo "Resolving latest version via git repository remote tags..."
    
    # Safely ensure git tool baseline layer is present
    if ! type git > /dev/null 2>&1; then
        if [ -x "$(command -v apt-get)" ]; then
            apt-get update && apt-get install -y git
        elif [ -x "$(command -v apk)" ]; then
            apk add --no-cache git
        fi
    fi

    # Query tags from remote origin sorting by semantic version formats, taking the top record
    TARGET_VERSION=$(git ls-remote --tags --refs --sort='v:refname' https://github.com | tail -n1 | awk -F/ '{print $3}')
    
    if [ -z "${TARGET_VERSION}" ]; then
        echo "Error: Failed to resolve the latest version tag from remote repository."
        exit 1
    fi
    echo "Resolved latest version to: ${TARGET_VERSION}"
fi

# Format the version tags cleanly (e.g., v1.61.0 -> 1.61.0)
VERSION_NUM=$(echo "${TARGET_VERSION}" | sed 's/^v//')

echo "Downloading official Agones SDK distribution payload: ${TARGET_VERSION}"

# Target the official zip bundle mapped by the project deployment pipeline
DOWNLOAD_URL="https://github.com{TARGET_VERSION}/agonessdk-server-${VERSION_NUM}.zip"

# Establish a temporary workspace environment 
TMP_DIR=$(mktemp -d)
ZIP_FILE="${TMP_DIR}/agones_sdk.zip"

# Fetch release package asset
HTTP_STATUS=$(curl -sSL -w "%{http_code}" -o "${ZIP_FILE}" "${DOWNLOAD_URL}")

if [ "${HTTP_STATUS}" -ne 200 ]; then
    echo "Error: Failed to download asset target. GitHub returned Status Code: ${HTTP_STATUS}"
    echo "Attempted URL target context: ${DOWNLOAD_URL}"
    rm -rf "${TMP_DIR}"
    exit 1
fi

# Unzip target payload package bundle into local workspace
EXTRACT_DIR="${TMP_DIR}/extracted"
mkdir -p "${EXTRACT_DIR}"
unzip -q "${ZIP_FILE}" -d "${EXTRACT_DIR}"

# Locate the right cross-compiled target binary inside the extracted package directory tree
TARGET_SOURCE_PATH=$(find "${EXTRACT_DIR}" -type f -name "agonessdk-server-linux-${AGONES_ARCH}" | head -n 1)

if [ -z "${TARGET_SOURCE_PATH}" ] || [ ! -f "${TARGET_SOURCE_PATH}" ]; then
    echo "Error: Could not locate matching 'agonessdk-server-linux-${AGONES_ARCH}' binary within package payload."
    rm -rf "${TMP_DIR}"
    exit 1
fi

# Install binary footprint cleanly into target /opt storage allocation path
mkdir -p "${INSTALL_DIR}"
TARGET_EXEC="${INSTALL_DIR}/sdk-server"
cp "${TARGET_SOURCE_PATH}" "${TARGET_EXEC}"

# Elevate process execution execution mask permissions 
chmod 0755 "${TARGET_EXEC}"

# Wire up structural system layer symlink target execution layer smoothly
if [ -L "${SYMLINK_PATH}" ] || [ -f "${SYMLINK_PATH}" ]; then
    rm "${SYMLINK_PATH}"
fi
ln -s "${TARGET_EXEC}" "${SYMLINK_PATH}"

# Clear temporary staging footprint directory completely
rm -rf "${TMP_DIR}"

echo "Agones SDK Server successfully verified and configured globally at ${SYMLINK_PATH}"
