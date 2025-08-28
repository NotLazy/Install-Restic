#!/bin/bash
set -euo pipefail

# --- Check dependencies ---
missing=()
for cmd in curl bunzip2; do
    if ! command -v "$cmd" &>/dev/null; then
        missing+=("$cmd")
    fi
done

if [ ${#missing[@]} -ne 0 ]; then
    echo "Missing required packages: ${missing[*]}"
    read -rp "Do you want me to install them automatically? [y/N] " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
        if command -v apt-get &>/dev/null; then
            sudo apt-get update
            sudo apt-get install -y "${missing[@]}"
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y "${missing[@]}"
        elif command -v yum &>/dev/null; then
            sudo yum install -y "${missing[@]}"
        elif command -v pacman &>/dev/null; then
            sudo pacman -S --noconfirm "${missing[@]}"
        else
            echo "Unsupported package manager. Please install manually: ${missing[*]}"
            exit 1
        fi
    else
        echo "Cannot continue without: ${missing[*]}"
        exit 1
    fi
fi

# --- Get latest restic release ---
latest=$(curl -s https://api.github.com/repos/restic/restic/releases/latest \
  | grep browser_download_url \
  | grep 'restic_[0-9].*_linux_amd64.bz2' \
  | cut -d '"' -f 4)

echo "Downloading: $latest"
tmpfile=$(mktemp /tmp/restic.XXXXXX.bz2)
curl -L -o "$tmpfile" "$latest"

# --- Decompress ---
echo "Decompressing..."
bunzip2 -f "$tmpfile"

# bunzip2 strips .bz2 -> final path
binfile="${tmpfile%.bz2}"

# --- Install ---
echo "Installing to /usr/local/sbin..."
sudo mv "$binfile" /usr/local/sbin/restic
sudo chmod +x /usr/local/sbin/restic

# --- Verify ---
echo "Installation complete. Version installed:"
/usr/local/sbin/restic version

# --- Cleanup ---
echo "Cleaning up..."
rm -f "$tmpfile" 2>/dev/null || true
echo "All done."
