# GWM Installation and Setup

This document provides instructions for installing and configuring GWM (Git Worktree Manager) with shell integration and tab completion.

## Shell Integration

GWM supports automatic directory switching through shell wrapper functions. These wrappers capture GWM's output and execute it in your shell.

### Bash

Add the following to your `~/.bashrc`:

```bash
gwm() { eval "$(command gwm "$@")"; }
```

### Zsh

Add the following to your `~/.zshrc`:

```zsh
gwm() { eval "$(command gwm "$@")" }
```

### Fish

Add the following to your `~/.config/fish/config.fish`:

```fish
function gwm
    eval (command gwm $argv)
end
```

### PowerShell

Add the following to your PowerShell profile (run `$PROFILE` to find the path):

```powershell
function gwm { Invoke-Expression (& gwm $args) }
```

### Nushell

Add the following to your `~/.config/nushell/config.nu`:

```nu
def --env gwm [...args] {
    ^gwm ...$args | lines | each { |line| nu -c $line }
}
```

## Tab Completion

GWM provides intelligent tab completion for commands, flags, worktree names, and branch names. Completion is built into the Dart binary and works automatically once you've set up the shell wrapper function (see Shell Integration above).

The completion system dynamically provides:
- **Commands**: `add`, `switch`, `delete`, `list`
- **Branch names**: For `gwm add <TAB>`
- **Worktree names**: For `gwm switch <TAB>` and `gwm delete <TAB>` (excludes current worktree and main workspace where appropriate)
- **Command flags**: Appropriate flags for each command (e.g., `--force` for delete, `--verbose` for list)

No additional setup is required beyond the shell wrapper - completion works out of the box!

## Configuration

GWM can be configured to disable shell integration if needed. Set the following in your configuration:

```json
{
  "shellIntegration": {
    "enableEvalOutput": false
  }
}
```

## Testing the Installation

After setup, test the shell integration:

```bash
# Create a worktree
gwm add feature-test

# You should automatically switch to the new worktree directory
pwd  # Should show the worktree path

# Test tab completion
gwm switch <TAB>  # Should show available worktrees
gwm add <TAB>     # Should show available branches
```

## Troubleshooting

- **Shell integration not working**: Ensure the wrapper function is properly sourced in your shell configuration
- **Tab completion not working**: Make sure the completion scripts are properly installed and your shell supports completion
- **Permission denied**: Ensure the completion scripts are executable (`chmod +x`)

## Supported Shells

- Bash 4.0+
- Zsh 5.0+
- Fish 3.0+
- PowerShell 5.0+
- Nushell 0.80+