#!/usr/bin/env bash

# Config
REPO="NVIDIA-RTX/Streamline"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${SCRIPT_DIR}/streamline"
WORKDIR="$(mktemp -d -t streamline_dl_XXXXXX)"
ZIPFILE="${WORKDIR}/release.zip"
EXTRACTDIR="${WORKDIR}/extracted"

cleanup() {
    if [[ -d "$WORKDIR" ]]; then
        rm -rf "$WORKDIR"
        echo -e "\nTemp files cleaned up."
    fi
}

echo "=========================="
echo " Streamline files fetcher"
echo "=========================="
echo "v1.0"
echo

# Detect non-interactive mode (e.g. executed from file manager)
if [[ ! -t 0 ]]; then
    echo "Non-interactive environment detected (file manager execution)."
    echo "Auto-selecting Option [1]: Download latest Streamline DLLs."
    echo
    CHOICE="1"
else
    echo "[1] Download latest Streamline DLLs"
    echo
    echo "[2] Delete \"streamline\" folder"
    echo
    read -r -p "Select an option (1 or 2): " CHOICE
    echo
fi

case "$CHOICE" in
    2)
        echo
        if [[ -d "$DEST" ]]; then
            echo "Deleting \"streamline\" folder and all its contents..."
            rm -rf "$DEST"
            echo "Done."
        else
            echo "Folder \"streamline\" does not exist. Nothing to delete."
        fi
        echo
        [[ -t 0 ]] && read -r -p "Press Enter to exit..."
        exit 0
        ;;
    1)
        ;;
    *)
        echo "Invalid selection. Exiting."
        rm -rf "$WORKDIR"
        exit 1
        ;;
esac

mkdir -p "$EXTRACTDIR" "$DEST"

# Locate the latest ZIP release
echo "--- Looking up latest release info ---"
echo

RELEASE_JSON=$(curl -sL -H "User-Agent: bash-script" "https://api.github.com/repos/${REPO}/releases/latest")

if command -v jq >/dev/null 2>&1; then
    ASSET_URL=$(echo "$RELEASE_JSON" | jq -r '.assets[] | select(.name | endswith(".zip")) | .browser_download_url' | head -n 1)
    ASSET_NAME=$(echo "$RELEASE_JSON" | jq -r '.assets[] | select(.name | endswith(".zip")) | .name' | head -n 1)
else
    ASSET_URL=$(echo "$RELEASE_JSON" | grep -o 'https://[^\"]*\.zip' | head -n 1)
    ASSET_NAME=$(basename "$ASSET_URL")
fi

if [[ -z "$ASSET_URL" || "$ASSET_URL" == "null" ]]; then
    echo "ERROR: Could not determine the latest release asset URL."
    echo "Temp files kept at: $WORKDIR"
    exit 1
fi

echo "Found asset: $ASSET_NAME"
echo "Download URL: $ASSET_URL"
echo

# Download the ZIP
echo "--- Downloading ${ASSET_NAME} ---"
echo
if ! curl -L --fail -o "$ZIPFILE" "$ASSET_URL"; then
    echo "ERROR: Download failed."
    echo "Temp files kept at: $WORKDIR"
    exit 1
fi
echo

# ZIP extraction
echo "--- Extracting archive ---"
if ! unzip -q -o "$ZIPFILE" -d "$EXTRACTDIR"; then
    echo "ERROR: Extraction failed."
    echo "Temp files kept at: $WORKDIR"
    exit 1
fi
echo

# Locate DLL files and transfer to folder
echo "--- Searching for bin/x64 folders and copying .dll files ---"
FOUND=0

while IFS= read -r -d '' BIN_DIR; do
    FOUND=1
    echo "   Found: $BIN_DIR"
    find "$BIN_DIR" -maxdepth 1 -iname "*.dll" -exec cp -f {} "$DEST/" \;
done < <(find "$EXTRACTDIR" -type d -iwholename "*/bin/x64" -print0)

if [[ $FOUND -eq 0 ]]; then
    echo "WARNING: No bin/x64 folder was found inside the archive."
    echo "The archive layout may have changed - check \"$EXTRACTDIR\" manually."
    echo "Temp files kept at: $WORKDIR"
    exit 1
fi

echo
echo "Done. DLLs copied to: $DEST"
echo
ls -1 "$DEST"/*.dll 2>/dev/null

cleanup

# Only pause for Enter if standard input is attached to a terminal
if [[ -t 0 ]]; then
    read -r -p "Press Enter to exit..."
fi

exit 0
