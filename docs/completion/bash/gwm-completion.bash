#!/bin/bash

# GWM (Git Worktree Manager) bash completion
# Source this file in your ~/.bashrc:
#   source /path/to/gwm-completion.bash

_gwm_complete_worktrees() {
    local cur prev
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    case "${prev}" in
        switch|list)
            # Complete worktree names for switch and list commands
            local worktrees
            worktrees=$(gwm list 2>/dev/null | grep -v '^Found' | sed 's/^[[:space:]]*//' | cut -d' ' -f1)
            COMPREPLY=( $(compgen -W "${worktrees}" -- "${cur}") )
            ;;
        add)
            # Complete branch names for add command
            local branches
            branches=$(git branch --all 2>/dev/null | grep -v 'HEAD' | sed 's/^[[:space:]]*//' | sed 's/^[*[:space:]]*//' | sed 's|^remotes/[^/]*/||' | sort | uniq)
            COMPREPLY=( $(compgen -W "${branches}" -- "${cur}") )
            ;;
        *)
            # Default completion - command names
            COMPREPLY=( $(compgen -W "add switch delete list" -- "${cur}") )
            ;;
    esac
}

# Register completion function
complete -F _gwm_complete_worktrees gwm