#!/usr/bin/env bash
set -euo pipefail

# Unified build script for Claude Code bundles.
# Runs on Linux and Windows (Git Bash / MSYS2).
#
# Usage:
#   ./scripts/build.sh \
#     --runtime node|deno \
#     --os win|linux \
#     --arch x64|arm64 \
#     --cc-version 2.1.47 \
#     --runtime-version 22.14.0 \
#     --output-dir ./build

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
RUNTIME=""
TARGET_OS=""
ARCH=""
CC_VERSION=""
RUNTIME_VERSION=""
OUTPUT_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --runtime)         RUNTIME="$2"; shift 2 ;;
    --os)              TARGET_OS="$2"; shift 2 ;;
    --arch)            ARCH="$2"; shift 2 ;;
    --cc-version)      CC_VERSION="$2"; shift 2 ;;
    --runtime-version) RUNTIME_VERSION="$2"; shift 2 ;;
    --output-dir)      OUTPUT_DIR="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

for var in RUNTIME TARGET_OS ARCH CC_VERSION RUNTIME_VERSION OUTPUT_DIR; do
  if [[ -z "${!var}" ]]; then
    echo "Error: --$(echo "$var" | tr '[:upper:]' '[:lower:]' | tr '_' '-') is required" >&2
    exit 1
  fi
done

# ---------------------------------------------------------------------------
# Derived variables
# ---------------------------------------------------------------------------
BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT

BUNDLE_NAME="claude-code"
BUNDLE_DIR="$BUILD_DIR/$BUNDLE_NAME"
mkdir -p "$BUNDLE_DIR"

# Map arch names
case "$ARCH" in
  x64)   NODE_ARCH="x64";     DENO_ARCH="x86_64"; BUN_ARCH="x64";      DEB_ARCH="amd64" ;;
  arm64) NODE_ARCH="arm64";   DENO_ARCH="aarch64"; BUN_ARCH="aarch64"; DEB_ARCH="arm64" ;;
  *) echo "Unsupported arch: $ARCH" >&2; exit 1 ;;
esac

case "$TARGET_OS" in
  win)   PLATFORM="win32";  NODE_OS="win";   DENO_SUFFIX="pc-windows-msvc" ;;
  linux) PLATFORM="linux";  NODE_OS="linux"; DENO_SUFFIX="unknown-linux-gnu" ;;
  *) echo "Unsupported OS: $TARGET_OS" >&2; exit 1 ;;
esac

mkdir -p "$OUTPUT_DIR"

echo "=== Building Claude Code v${CC_VERSION} ==="
echo "Runtime: $RUNTIME $RUNTIME_VERSION"
echo "Target:  $TARGET_OS-$ARCH"

# ---------------------------------------------------------------------------
# Step 1: Download runtime binary
# ---------------------------------------------------------------------------
echo "--- Downloading $RUNTIME runtime ---"

if [[ "$RUNTIME" == "node" ]]; then
  RUNTIME_DIR="$BUNDLE_DIR/node"
  mkdir -p "$RUNTIME_DIR"

  if [[ "$TARGET_OS" == "win" ]]; then
    NODE_URL="https://nodejs.org/dist/v${RUNTIME_VERSION}/node-v${RUNTIME_VERSION}-win-${NODE_ARCH}.zip"
    echo "Downloading $NODE_URL"
    curl -fsSL -o "$BUILD_DIR/node.zip" "$NODE_URL"
    # Extract only node.exe
    unzip -q -j "$BUILD_DIR/node.zip" "node-v${RUNTIME_VERSION}-win-${NODE_ARCH}/node.exe" -d "$RUNTIME_DIR"
  else
    NODE_URL="https://nodejs.org/dist/v${RUNTIME_VERSION}/node-v${RUNTIME_VERSION}-linux-${NODE_ARCH}.tar.xz"
    echo "Downloading $NODE_URL"
    curl -fsSL -o "$BUILD_DIR/node.tar.xz" "$NODE_URL"
    tar -xJf "$BUILD_DIR/node.tar.xz" -C "$BUILD_DIR" "node-v${RUNTIME_VERSION}-linux-${NODE_ARCH}/bin/node"
    cp "$BUILD_DIR/node-v${RUNTIME_VERSION}-linux-${NODE_ARCH}/bin/node" "$RUNTIME_DIR/node"
    chmod +x "$RUNTIME_DIR/node"
  fi

elif [[ "$RUNTIME" == "deno" ]]; then
  RUNTIME_DIR="$BUNDLE_DIR/deno"
  mkdir -p "$RUNTIME_DIR"

  DENO_ZIP="deno-${DENO_ARCH}-${DENO_SUFFIX}.zip"
  DENO_URL="https://github.com/denoland/deno/releases/download/v${RUNTIME_VERSION}/${DENO_ZIP}"
  echo "Downloading $DENO_URL"
  curl -fsSL -o "$BUILD_DIR/deno.zip" "$DENO_URL"

  if [[ "$TARGET_OS" == "win" ]]; then
    unzip -q "$BUILD_DIR/deno.zip" "deno.exe" -d "$RUNTIME_DIR"
  else
    unzip -q "$BUILD_DIR/deno.zip" "deno" -d "$RUNTIME_DIR"
    chmod +x "$RUNTIME_DIR/deno"
  fi

elif [[ "$RUNTIME" == "bun" ]]; then
  RUNTIME_DIR="$BUNDLE_DIR/bun"
  mkdir -p "$RUNTIME_DIR"

  if [[ "$TARGET_OS" == "win" ]]; then
    BUN_ZIP="bun-windows-${BUN_ARCH}.zip"
  else
    BUN_ZIP="bun-linux-${BUN_ARCH}.zip"
  fi
  BUN_URL="https://github.com/oven-sh/bun/releases/download/bun-v${RUNTIME_VERSION}/${BUN_ZIP}"
  echo "Downloading $BUN_URL"
  curl -fsSL -o "$BUILD_DIR/bun.zip" "$BUN_URL"

  if [[ "$TARGET_OS" == "win" ]]; then
    unzip -q -j "$BUILD_DIR/bun.zip" "*/bun.exe" -d "$RUNTIME_DIR"
  else
    unzip -q -j "$BUILD_DIR/bun.zip" "*/bun" -d "$RUNTIME_DIR"
    chmod +x "$RUNTIME_DIR/bun"
  fi
fi

# ---------------------------------------------------------------------------
# Step 2: Install claude-code via npm
# ---------------------------------------------------------------------------
echo "--- Installing @anthropic-ai/claude-code@${CC_VERSION} ---"

# We need npm available. On Windows runners npm is in PATH.
# On Linux runners we use the system npm (setup-node provides it).
# For cross-builds (e.g. win-arm64 on x64 runner), --cpu selects correct optional deps.

cat > "$BUNDLE_DIR/package.json" << EOF
{
  "name": "claude-code-bundle",
  "version": "1.0.0",
  "private": true,
  "dependencies": {
    "@anthropic-ai/claude-code": "${CC_VERSION}"
  }
}
EOF

# npm install with platform targeting
NPM_FLAGS=(--omit=dev --prefix "$BUNDLE_DIR")

# Set platform flags for cross-compilation
if [[ "$TARGET_OS" == "win" ]]; then
  NPM_FLAGS+=(--os=win32 "--cpu=$NODE_ARCH")
else
  NPM_FLAGS+=(--os=linux "--cpu=$NODE_ARCH")
fi

npm install "${NPM_FLAGS[@]}"

# ---------------------------------------------------------------------------
# Step 3: Strip non-target ripgrep vendors
# ---------------------------------------------------------------------------
echo "--- Stripping ripgrep vendors ---"

VENDOR_DIR="$BUNDLE_DIR/node_modules/@anthropic-ai/claude-code/vendor/ripgrep"
if [[ -d "$VENDOR_DIR" ]]; then
  # Determine which vendor dir to keep
  case "${ARCH}-${TARGET_OS}" in
    x64-win)    KEEP="x64-win32" ;;
    arm64-win)  KEEP="arm64-win32" ;;
    x64-linux)  KEEP="x64-linux" ;;
    arm64-linux) KEEP="arm64-linux" ;;
  esac

  for dir in "$VENDOR_DIR"/*/; do
    dir_name="$(basename "$dir")"
    if [[ "$dir_name" != "$KEEP" ]]; then
      echo "  Removing vendor/ripgrep/$dir_name"
      rm -rf "$dir"
    fi
  done
fi

# ---------------------------------------------------------------------------
# Step 4: Copy wrapper script
# ---------------------------------------------------------------------------
echo "--- Copying wrapper ---"

if [[ "$TARGET_OS" == "win" ]]; then
  cp "$REPO_ROOT/templates/claude-${RUNTIME}.cmd" "$BUNDLE_DIR/claude.cmd"
else
  cp "$REPO_ROOT/templates/claude-${RUNTIME}.sh" "$BUNDLE_DIR/claude"
  chmod +x "$BUNDLE_DIR/claude"
fi

# Remove package.json (not needed at runtime)
rm -f "$BUNDLE_DIR/package.json"

# ---------------------------------------------------------------------------
# Step 5: Create archive
# ---------------------------------------------------------------------------
echo "--- Creating archive ---"

ARCHIVE_BASE="claude-code-v${CC_VERSION}-${RUNTIME}-v${RUNTIME_VERSION}-${TARGET_OS}-${ARCH}"

if [[ "$TARGET_OS" == "win" ]]; then
  ARCHIVE_NAME="${ARCHIVE_BASE}.zip"
  # Windows runners don't have zip; use 7z which is pre-installed
  (cd "$BUILD_DIR" && 7z a -tzip -mx=5 "$OUTPUT_DIR/$ARCHIVE_NAME" "$BUNDLE_NAME" > /dev/null)
else
  ARCHIVE_NAME="${ARCHIVE_BASE}.tar.gz"
  tar -czf "$OUTPUT_DIR/$ARCHIVE_NAME" -C "$BUILD_DIR" "$BUNDLE_NAME"
fi

echo "Created: $OUTPUT_DIR/$ARCHIVE_NAME"

# ---------------------------------------------------------------------------
# Step 6: Build .deb (Linux only)
# ---------------------------------------------------------------------------
if [[ "$TARGET_OS" == "linux" ]]; then
  echo "--- Building .deb package ---"

  case "$RUNTIME" in
    node)
      DEB_PKG_NAME="claude-code"
      DEB_NAME="claude-code_${CC_VERSION}-node${RUNTIME_VERSION}_${DEB_ARCH}.deb"
      TEMPLATE="$REPO_ROOT/debian/control.node.template"
      RT_VER_LABEL="NODE_VER" ;;
    deno)
      DEB_PKG_NAME="claude-code-deno"
      DEB_NAME="claude-code-deno_${CC_VERSION}-deno${RUNTIME_VERSION}_${DEB_ARCH}.deb"
      TEMPLATE="$REPO_ROOT/debian/control.deno.template"
      RT_VER_LABEL="DENO_VER" ;;
    bun)
      DEB_PKG_NAME="claude-code-bun"
      DEB_NAME="claude-code-bun_${CC_VERSION}-bun${RUNTIME_VERSION}_${DEB_ARCH}.deb"
      TEMPLATE="$REPO_ROOT/debian/control.bun.template"
      RT_VER_LABEL="BUN_VER" ;;
  esac

  DEB_ROOT="$BUILD_DIR/${DEB_PKG_NAME}_${CC_VERSION}"
  mkdir -p "$DEB_ROOT/DEBIAN"
  mkdir -p "$DEB_ROOT/opt/claude-code"
  mkdir -p "$DEB_ROOT/usr/local/bin"

  # Copy bundle contents
  cp -a "$BUNDLE_DIR"/* "$DEB_ROOT/opt/claude-code/"

  # Create symlink
  ln -sf /opt/claude-code/claude "$DEB_ROOT/usr/local/bin/claude"

  # Calculate installed size in KB
  SIZE_KB=$(du -sk "$DEB_ROOT/opt" | cut -f1)

  # Get maintainer from git config or fallback
  MAINTAINER="${GITHUB_REPOSITORY_OWNER:-$(git config user.name 2>/dev/null || echo 'maintainer')}"

  # Generate control file
  sed \
    -e "s/{{CC_VER}}/$CC_VERSION/g" \
    -e "s/{{ARCH}}/$DEB_ARCH/g" \
    -e "s/{{SIZE_KB}}/$SIZE_KB/g" \
    -e "s/{{MAINTAINER}}/$MAINTAINER/g" \
    -e "s/{{${RT_VER_LABEL}}}/$RUNTIME_VERSION/g" \
    "$TEMPLATE" > "$DEB_ROOT/DEBIAN/control"

  dpkg-deb --build "$DEB_ROOT" "$OUTPUT_DIR/$DEB_NAME"
  echo "Created: $OUTPUT_DIR/$DEB_NAME"
fi

echo "=== Build complete ==="
