# Claude Code — Portable Builds

## Changelog

┌────────────┬──────────────────────────────────────────────┐
│ Date       │ Summary                                      │
├────────────┼──────────────────────────────────────────────┤
│ 2026-02-19 │ Added Bun runtime, updated build matrix      │
│ 2026-02-19 │ Initial creation                             │
└────────────┴──────────────────────────────────────────────┘

## Overview

Automated packaging of [Claude Code](https://github.com/anthropics/claude-code) into self-contained, portable bundles. Bundles include a JavaScript runtime (Node.js, Deno, or Bun) so no global install is needed. Builds run daily via GitHub Actions, detecting upstream version changes and producing 17 artifacts per release cycle.

## Key Files

┌──────────────────────────────────────────┬─────────────────────────────────────────────────┐
│ Path                                     │ Purpose                                         │
├──────────────────────────────────────────┼─────────────────────────────────────────────────┤
│ scripts/build.sh                         │ Unified build script (all platforms/arches)      │
│ .github/workflows/build.yml              │ CI: version check, build matrix, release         │
│ .github/dependabot.yml                   │ Weekly SHA updates for pinned actions             │
│ versions.json                            │ Tracks last-released versions (cc/node/deno/bun) │
│ templates/claude-{node,deno,bun}.cmd     │ Windows wrapper scripts                          │
│ templates/claude-{node,deno,bun}.sh      │ Linux wrapper scripts                            │
│ debian/control.{node,deno,bun}.template  │ DEBIAN/control templates for .deb packaging      │
│ scoop/claude-code-npm.json               │ Scoop manifest for Node variant                  │
│ scoop/claude-code-deno.json              │ Scoop manifest for Deno variant                  │
│ scoop/claude-code-bun.json               │ Scoop manifest for Bun variant (64bit only)      │
└──────────────────────────────────────────┴─────────────────────────────────────────────────┘

## Build Matrix

┌─────────┬─────────────┬───────────────┬──────────────────┬────────────────────┐
│ Runtime │ Windows x64 │ Windows arm64 │ Linux x64        │ Linux arm64        │
├─────────┼─────────────┼───────────────┼──────────────────┼────────────────────┤
│ Node.js │ zip         │ zip           │ tar.gz + deb     │ tar.gz + deb       │
│ Deno    │ zip         │ zip           │ tar.gz + deb     │ tar.gz + deb       │
│ Bun     │ zip         │ —             │ tar.gz + deb     │ tar.gz + deb       │
└─────────┴─────────────┴───────────────┴──────────────────┴────────────────────┘

Runner mapping: `windows-latest` builds win-x64 and win-arm64 (cross-build), `ubuntu-latest` builds linux-x64, `ubuntu-24.04-arm` builds linux-arm64. Bun has no Windows arm64 build.

## Build Script

`scripts/build.sh` — parameterised by `--runtime`, `--os`, `--arch`, `--cc-version`, `--runtime-version`, `--output-dir`. Runs on both Git Bash (Windows) and native Linux.

Steps: download runtime binary → `npm install` with platform flags → strip non-target ripgrep vendors → copy wrapper → archive (7z on Windows, tar on Linux) → build .deb (Linux only).

## Workflow Jobs

┌────────────────┬─────────────────────────────────────────────────────────┐
│ Job            │ What it does                                            │
├────────────────┼─────────────────────────────────────────────────────────┤
│ check-versions │ Fetches latest cc/node/deno/bun versions, compares      │
│                │ with versions.json, sets needs_build flags              │
│ build-node     │ 4-runner matrix, produces 6 artifacts                   │
│ build-deno     │ 4-runner matrix, produces 6 artifacts                   │
│ build-bun      │ 3-runner matrix, produces 5 artifacts (no win-arm64)    │
│ release-node   │ Creates GH release, updates versions.json + scoop       │
│ release-deno   │ Creates GH release, updates versions.json + scoop       │
│ release-bun    │ Creates GH release, updates versions.json + scoop       │
└────────────────┴─────────────────────────────────────────────────────────┘

Release jobs fetch+reset to latest remote main before committing to handle concurrent pushes.

## Version Tags

- Node: `claude-code-v{CC}-node-v{NODE}` (e.g. `claude-code-v2.1.47-node-v24.13.1`)
- Deno: `claude-code-v{CC}-deno-v{DENO}` (e.g. `claude-code-v2.1.47-deno-v2.6.10`)
- Bun: `claude-code-v{CC}-bun-v{BUN}` (e.g. `claude-code-v2.1.47-bun-v1.3.9`)

## Conventions

- All GitHub Actions pinned to full commit SHAs.
- Top-level `permissions: {}` (deny-all); `contents: write` only on release jobs.
- LF line endings enforced via `.gitattributes`.
- Wrappers disable telemetry (`CLAUDE_CODE_ENABLE_TELEMETRY=0`) and non-essential traffic.
- `.deb` packages use `Conflicts:` so only one variant installs at a time.
- Scoop manifests use `checkver` regex with capture groups; `$version` = cc version, `$match2` = runtime version.
