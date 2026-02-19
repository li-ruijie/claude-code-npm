# Claude Code — Portable Builds

Self-contained, portable bundles of [Claude Code](https://github.com/anthropics/claude-code) for Windows and Linux. No global Node.js install required.

Builds are automated via GitHub Actions. A daily check detects new releases of Claude Code, Node.js LTS, Deno, or Bun and triggers a fresh build cycle.

## Download

Grab the latest release for your platform from the [Releases](https://github.com/li-ruijie/claude-code/releases) page.

### Node.js runtime (recommended)

| Platform | Architecture | Format |
|----------|-------------|--------|
| Windows | x64 | `.zip` |
| Windows | arm64 | `.zip` |
| Linux | x64 | `.tar.gz` / `.deb` |
| Linux | arm64 | `.tar.gz` / `.deb` |

### Deno runtime (experimental)

Same matrix as above. Deno compatibility with Claude Code is not officially supported.

### Bun runtime (experimental)

Same as Node.js matrix except no Windows arm64 (Bun doesn't ship it). Bun compatibility with Claude Code is not officially supported.

## Install

### Windows (zip)

Extract and run `claude.cmd`. Optionally add the extracted directory to your `PATH`.

### Linux (tar.gz)

```bash
tar xzf claude-code-v*-linux-x64.tar.gz
./claude-code/claude --version
```

### Linux (deb)

```bash
sudo dpkg -i claude-code_*_amd64.deb
claude --version
```

## Build matrix

Three runtimes × two platforms × two architectures = 17 artifacts per release cycle.

```
             Windows x64   Windows arm64   Linux x64        Linux arm64
Node.js      zip           zip             tar.gz + deb     tar.gz + deb
Deno         zip           zip             tar.gz + deb     tar.gz + deb
Bun          zip           —               tar.gz + deb     tar.gz + deb
```

## Version tags

- Node: `claude-code-v{CC_VER}-node-v{NODE_VER}`
- Deno: `claude-code-v{CC_VER}-deno-v{DENO_VER}`
- Bun: `claude-code-v{CC_VER}-bun-v{BUN_VER}`

## License

Claude Code is developed by [Anthropic](https://anthropic.com). This repository only automates packaging and distribution of the official npm package.
