# Claude Code NPM - Automated Build System

Automated builds of self-contained Claude Code bundles (Node.js + Deno) for Windows and Linux.

## Repo Structure

- `scripts/build.sh` - Unified build script for all runtime/OS/arch combinations
- `templates/` - Wrapper scripts (.cmd for Windows, .sh for Linux)
- `debian/` - DEBIAN/control templates for .deb packaging
- `scoop/` - Scoop manifests (auto-updated by CI)
- `versions.json` - Tracks last released versions
- `.github/workflows/build.yml` - CI/CD pipeline

## Build Matrix

Two runtimes (Node, Deno) x two platforms (Windows, Linux) x two architectures (x64, arm64).
12 artifacts per release cycle: 4 zips + 4 tar.gz + 4 .deb packages.

## Version Tags

- Node: `claude-code-v{CC}-node-v{NODE}`
- Deno: `claude-code-v{CC}-deno-v{DENO}`

## Key Conventions

- All GitHub Actions pinned to full commit SHAs
- Top-level `permissions: {}` in workflows
- Build script runs on both Git Bash (Windows) and native Linux
- Windows arm64 is cross-built on x64 runners
