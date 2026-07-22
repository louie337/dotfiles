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
custom agents in `.codex/agents/`. The active end-to-end workflows are `$ticket-loop` and
`$mr-loop`; `$mission` and `$foreman` provide general parallel and serialized plan execution.
OpenCode definitions under `.config/opencode/` are retained temporarily as migration reference and
rollback material.

Validate the Codex-managed files with:

```sh
sh tests/codex-migration-test.sh
```

## Resources
- stow man page: https://www.gnu.org/software/stow/manual/
- Enjoy using my dotfiles!
