#!/usr/bin/env bash
# GWM (Git Worktree Manager) bash completion script
#
# Installation:
#   1. Source this file in your ~/.bashrc:
#      source /path/to/gwm.bash
#   2. Or copy it to your bash completion directory:
#      cp gwm.bash /usr/local/share/bash-completion/completions/gwm
#      # or for local user:
#      cp gwm.bash ~/.local/share/bash-completion/completions/gwm
#
# Usage:
#   Complete commands, subcommands, worktree names, and branch names.
#   Works with: gwm add <TAB>, gwm switch <TAB>, etc.

_gwm_complete() {
    local cur prev words cword
    _init_completion || return

    local commands opts
    # Get commands dynamically for consistency
    if commands=$(gwm --complete 2>/dev/null); then
        commands=$(echo "$commands" | tr '\n' ' ')
    else
        commands="add switch delete list"
    fi
    opts="--help --verbose --version --no-eval-check"

    # Get the current command being completed
    local cmd=""
    local arg_pos=0

    # Find which command we're in by checking all words
    for ((i=1; i <= cword; i++)); do
        if [[ "${commands}" =~ (^|[[:space:]])"${words[i]}"($|[[:space:]]) ]]; then
            cmd="${words[i]}"
            arg_pos=$((i + 1))
            break
        fi
    done

    # If we found a command, complete based on that command and position
    if [[ -n "$cmd" ]]; then
        case "$cmd" in
            add)
                # Complete branch names for add command
                if [[ $cword -ge $arg_pos ]]; then
                    local branches
                    if branches=$(gwm --complete add "$cur" $((cword - arg_pos)) 2>/dev/null); then
                        COMPREPLY=($(compgen -W "$branches" -- "$cur"))
                    fi
                fi
                ;;
            switch)
                # Complete worktree names for switch command
                if [[ $cword -ge $arg_pos ]]; then
                    local worktrees
                    if worktrees=$(gwm --complete switch "$cur" $((cword - arg_pos)) 2>/dev/null); then
                        COMPREPLY=($(compgen -W "$worktrees" -- "$cur"))
                    fi
                fi
                ;;
             delete)
                 # Complete worktree names for delete command
                 if [[ $cword -ge $arg_pos ]]; then
                     local worktrees
                     if worktrees=$(gwm --complete delete "$cur" $((cword - arg_pos)) 2>/dev/null); then
                         COMPREPLY=($(compgen -W "$worktrees" -- "$cur"))
                     fi
                 else
                     # Complete flags for delete command
                     COMPREPLY=($(compgen -W "--force --help" -- "$cur"))
                 fi
                 ;;
            list)
                # Complete flags for list command
                COMPREPLY=($(compgen -W "--verbose --json --help" -- "$cur"))
                ;;
        esac
    else
        # No command found, complete global options or commands
        COMPREPLY=($(compgen -W "$commands $opts" -- "$cur"))
    fi
}

# Register the completion function
complete -F _gwm_complete gwm