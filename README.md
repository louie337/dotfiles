# Louie's dotfiles

Welcome! This repository contains my personal dotfiles for various tools and applications. You can use them with the `stow` tool to manage and link them to your desired locations.

## Prerequisites

* A Linux system
* [stow](https://www.gnu.org/software/stow/manual/) installed 

## Installation

1. Clone this repository:

```bash
git clone git@github.com:louielyl/dotfiles.git
```

2. Apply the dotfiles to your home directory

```bash
stow .
```

## Customization:

- You can customize dotfiles by editing the symlinks in your target directory.

## Additional Notes
- This repository uses symlinks to avoid modifying original files.
- Be aware of potential conflicts with existing configurations.
- Report any issues or suggest improvements on the GitHub repository.

## Codex

Global Codex configuration lives in `.codex/`, reusable skills in `.agents/skills/`, and Codex
custom agents in `.codex/agents/`. The active Subanana workflows are `$ticket-loop`, `$mr-loop`,
`$test-loop`, and `$double-check`; `$mission` and `$foreman` provide general parallel and
serialized plan execution.
OpenCode definitions under `.config/opencode/` are retained temporarily as migration reference and
rollback material.

Validate the Codex-managed files with:

```sh
sh tests/codex-migration-test.sh
```

## Shared OpenConnector MCP

The local OpenConnector gateway runs from `/Users/louie/Documents/open-connector` with Docker Compose and exposes its MCP endpoint at `http://127.0.0.1:3456/mcp`.

The shared topology is:

- Codex: `.codex/config.toml` → `mcp_servers.openconnector`
- OpenCode: `.config/opencode/opencode.json` → `mcp.openconnector`
- Hermes: `~/.hermes/config.yaml` → `mcp_servers.openconnector`
- Claude Code: user-scoped `openconnector` MCP server

OpenConnector is a connector gateway for provider Actions; it does not proxy arbitrary MCP servers. Existing MCP servers therefore remain configured directly in each client, while provider credentials managed by OpenConnector are reused through the single `/mcp` endpoint.

Start the gateway:

```sh
cd /Users/louie/Documents/open-connector
docker compose up -d
docker compose ps
curl http://127.0.0.1:3456/health
```

Runtime secrets are stored in `/Users/louie/Documents/open-connector/.env` with mode `0600`; do not commit that file. Hermes receives the OpenConnector runtime token through `~/.hermes/.env` as `MCP_OPENCONNECTOR_API_KEY`.

OpenConnector's MCP tools are `list_apps`, `list_connections`, `search_actions`, `get_action_guide`, and `execute_action`. Use `search_actions` and `get_action_guide` before executing provider Actions.

- stow man page: https://www.gnu.org/software/stow/manual/
- Enjoy using my dotfiles!
