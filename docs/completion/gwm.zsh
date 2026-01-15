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
#   Works with: gwm add <TAB>, gwm switch <TAB>, etc.

_gwm() {
    if (( CURRENT == 2 )); then
        # Completing the command
        _gwm_commands
    elif (( CURRENT > 2 )); then
        # Completing arguments - check what command was entered
        case $words[2] in
            add) _gwm_add_args ;;
            switch) _gwm_switch_args ;;
            delete) _gwm_delete_args ;;
            list) _gwm_list_args ;;
        esac
    fi
}

_gwm_args() {
    case $line[2] in
        add) _gwm_add_args ;;
        switch) _gwm_switch_args ;;
        delete) _gwm_delete_args ;;
        list) _gwm_list_args ;;
        *) _message 'unknown command' ;;
    esac
}

_gwm_commands() {
    # Use simple compadd to avoid issues with _describe
    compadd add switch delete list
}

_gwm_add_args() {
    # For add command: gwm add [options] [branch]
    if (( CURRENT == 3 )); then
        # Complete branch names
        local -a branches
        if branches=($(gwm --complete add "${words[CURRENT]}" 0 2>/dev/null)); then
            _describe -t branches 'git branches' branches
        fi
    else
        # Complete options
        compadd --create-branch --help
    fi
}

_gwm_switch_args() {
    # For switch command: gwm switch [options] [worktree]
    if (( CURRENT == 3 )); then
        # Complete worktree names
        local -a worktrees
        if worktrees=($(gwm --complete switch "${words[CURRENT]}" 0 2>/dev/null)); then
            _describe -t worktrees 'worktrees' worktrees
        fi
    else
        # Complete options
        compadd --reconfigure --help
    fi
}

_gwm_delete_args() {
    # For delete command: gwm delete [options] [worktree]
    if (( CURRENT == 3 )); then
        # Complete worktree names
        local -a worktrees
        if worktrees=($(gwm --complete delete "${words[CURRENT]}" 0 2>/dev/null)); then
            _describe -t worktrees 'worktrees' worktrees
        fi
    else
        # Complete options
        compadd --force --help
    fi
}

_gwm_list_args() {
    compadd --verbose --json --help
}

# Register the completion function
compdef _gwm gwm