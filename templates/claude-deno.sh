#!/bin/sh
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export CLAUDE_CONFIG_DIR="$HOME/.config/claude"
export CLAUDE_CONFIG_FILE="$CLAUDE_CONFIG_DIR/.claude.json"
export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
export CLAUDE_CODE_ENABLE_TELEMETRY=0
exec "$SCRIPT_DIR/deno/deno" run --allow-all --unstable-bare-node-builtins --node-modules-dir=auto "$SCRIPT_DIR/deno-shim.js" "$@"
