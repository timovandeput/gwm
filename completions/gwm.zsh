#compdef gwm
# GWM (Git Worktree Manager) zsh completion script
#
# Installation:
#   Option 1 - System-wide (recommended):
#     1. Place this file in a directory in your fpath, e.g.:
#        cp gwm.zsh ~/.zsh/completions/_gwm
#     2. Add the directory to your fpath in ~/.zshrc:
#        fpath=(~/.zsh/completions $fpath)
#     3. Reload completions:
#        autoload -Uz compinit && compinit
#
#   Option 2 - For testing (source directly):
#     source gwm.zsh
#
# Usage:
#   Complete commands, subcommands, worktree names, and branch names.
#   Works with: gwm create <TAB>, gwm switch <TAB>, etc.

_gwm() {
    local completions
    local position=$((CURRENT - 3))
    if (( position < 0 )); then position=0; fi

    if (( CURRENT == 2 )); then
        # Completing the command
        completions=($(gwm --complete "" "${words[CURRENT]}" 0 2>/dev/null))
        _describe -t commands 'commands' completions
    elif (( CURRENT > 2 )); then
        # Completing arguments for the command
        completions=($(gwm --complete "${words[2]}" "${words[CURRENT]}" $position 2>/dev/null))
        _describe -t completions 'completions' completions
    fi
}

# Register the completion function
compdef _gwm gwm