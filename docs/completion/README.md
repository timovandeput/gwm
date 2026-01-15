# GWM Tab Completion Scripts

This directory contains tab completion scripts for the GWM (Git Worktree Manager) CLI tool.

## Installation

### Bash

**Option 1: Source in your shell profile**
```bash
# Add to ~/.bashrc or ~/.bash_profile
source /path/to/gwm/docs/completion/gwm.bash
```

**Option 2: Install system-wide**
```bash
sudo cp gwm.bash /usr/local/share/bash-completion/completions/gwm
# or for local user:
mkdir -p ~/.local/share/bash-completion/completions
cp gwm.bash ~/.local/share/bash-completion/completions/gwm
```

### Zsh

**Option 1: Add to fpath (recommended)**
```bash
# Create completions directory if it doesn't exist
mkdir -p ~/.zsh/completions

# Copy the completion script
cp gwm.zsh ~/.zsh/completions/_gwm

# Add to your fpath in ~/.zshrc
fpath=(~/.zsh/completions $fpath)

# Reload completions
autoload -Uz compinit && compinit
```

**Option 2: Source directly (for testing)**
```bash
# In any ZSH shell
source path/to/gwm.zsh

# Now test completions
gwm <Tab>
```

**Option 3: Use a completion manager like zplug**
```bash
# Add to ~/.zshrc
zplug "path/to/gwm.zsh", from:local, use:_gwm
```

### Fish

```bash
# Copy to fish completions directory
cp gwm.fish ~/.config/fish/completions/gwm.fish
```

## Features

The completion scripts provide intelligent tab completion for:

- **Commands**: `add`, `switch`, `delete`, `list`
- **Branch names**: For `gwm add <TAB>`
- **Worktree names**: For `gwm switch <TAB>` (includes "." for main workspace)
- **Command flags**: Appropriate flags for each command

## How It Works

The completion scripts call `gwm --complete <command> <partial> <position>` to get dynamic completion candidates based on the current Git repository state. This ensures completions are always up-to-date with available branches and worktrees.