# GWM Installation and Setup

This document provides instructions for installing and configuring GWM (Git Worktree Manager) with shell integration and tab completion.

## Shell Integration

GWT supports automatic directory switching through shell wrapper functions. These wrappers capture GWM's output and execute it in your shell.

### Bash

Add the following to your `~/.bashrc`:

```bash
gwt() { eval "$(command gwm "$@")"; }
```

### Zsh

Add the following to your `~/.zshrc`:

```zsh
gwt() { eval "$(command gwm "$@")" }
```

### Fish

Add the following to your `~/.config/fish/config.fish`:

```fish
function gwt
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

GWT provides tab completion for worktree names (in `list` and `switch` commands) and branch names (in `add` command).

### Bash

Source the completion script in your `~/.bashrc`:

```bash
source /path/to/gwt/docs/completion/bash/gwt-completion.bash
```

### Zsh

Either source the completion script or place it in your `$fpath`:

```zsh
source /path/to/gwt/docs/completion/zsh/_gwt
```

Or copy the file to a directory in your `$fpath` (e.g., `/usr/local/share/zsh/site-functions/`) and run `compinit`.

### Fish

Copy the completion file to your fish completions directory:

```fish
cp /path/to/gwt/docs/completion/fish/gwt.fish ~/.config/fish/completions/
```

Or to the system directory:

```fish
sudo cp /path/to/gwt/docs/completion/fish/gwt.fish /usr/share/fish/vendor_completions.d/
```

## Configuration

GWT can be configured to disable shell integration if needed. Set the following in your configuration:

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