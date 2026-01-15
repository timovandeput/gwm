#compdef gwm
# GWM (Git Worktree Manager) zsh completion script
#
# Installation:
#   1. Place this file in a directory in your fpath, e.g.:
#      cp gwm.zsh ~/.zsh/completions/_gwm
#   2. Add the directory to your fpath in ~/.zshrc:
#      fpath=(~/.zsh/completions $fpath)
#   3. Reload completions:
#      autoload -Uz compinit && compinit
#
# Usage:
#   Complete commands, subcommands, worktree names, and branch names.
#   Works with: gwm add <TAB>, gwm switch <TAB>, etc.

_gwm() {
    local -a commands opts
    commands=(
        'add:Add a new Git worktree'
        'switch:Switch to an existing worktree'
        'clean:Delete current worktree'
        'list:List all worktrees'
    )

    opts=(
        '--help[Print usage information]'
        '--verbose[Show additional command output]'
        '--version[Print the tool version]'
        '--no-eval-check[Skip shell wrapper validation check]'
    )

    # Determine which command we're completing for
    local cmd=""
    for ((i=2; i <= $#words; i++)); do
        if [[ -n "${commands[(r)$words[i]]}" ]]; then
            cmd="$words[i]"
            break
        fi
    done

    # If we found a command, complete its arguments
    if [[ -n "$cmd" ]]; then
        case $cmd in
            add)
                _gwm_add_args
                ;;
            switch)
                _gwm_switch_args
                ;;
            clean)
                _gwm_clean_args
                ;;
            list)
                _gwm_list_args
                ;;
        esac
    else
        # No command found, complete commands or global options
        _arguments -C \
            $opts \
            '1: :_gwm_commands' \
            && return 0
    fi
}

_gwm_commands() {
    local -a commands
    if commands=($(gwm --complete 2>/dev/null)); then
        # Convert to zsh description format
        local -a descriptions
        for cmd in "${commands[@]}"; do
            case $cmd in
                add) descriptions+=("$cmd:Add a new Git worktree") ;;
                switch) descriptions+=("$cmd:Switch to an existing worktree") ;;
                clean) descriptions+=("$cmd:Delete current worktree") ;;
                list) descriptions+=("$cmd:List all worktrees") ;;
                *) descriptions+=("$cmd") ;;
            esac
        done
        _describe -t commands 'gwm commands' descriptions
    else
        # Fallback to hardcoded if completion fails
        local -a fallback
        fallback=(
            'add:Add a new Git worktree'
            'switch:Switch to an existing worktree'
            'clean:Delete current worktree'
            'list:List all worktrees'
        )
        _describe -t commands 'gwm commands' fallback
    fi
}

_gwm_add_args() {
    local -a add_opts
    add_opts=(
        '--create-branch[Create the branch if it does not exist]'
        '--help[Print usage information for this command]'
    )

    # Calculate argument position (1-based, after command)
    local arg_pos=0
    for ((i=2; i <= $#words; i++)); do
        if [[ $words[i] == 'add' ]]; then
            arg_pos=$i
            break
        fi
    done

    if (( CURRENT > arg_pos + 1 )); then
        # Complete branch names for positional arguments
        local -a branches
        if branches=($(gwm --complete add "${words[CURRENT]}" $((CURRENT - arg_pos - 1)) 2>/dev/null)); then
            _describe -t branches 'git branches' branches
        fi
    else
        _arguments $add_opts
    fi
}

_gwm_switch_args() {
    local -a switch_opts
    switch_opts=(
        '--reconfigure[Reconfigure the worktree by copying files and running add hooks]'
        '--help[Print usage information for this command]'
    )

    # Calculate argument position (1-based, after command)
    local arg_pos=0
    for ((i=2; i <= $#words; i++)); do
        if [[ $words[i] == 'switch' ]]; then
            arg_pos=$i
            break
        fi
    done

    if (( CURRENT > arg_pos + 1 )); then
        # Complete worktree names for positional arguments
        local -a worktrees
        if worktrees=($(gwm --complete switch "${words[CURRENT]}" $((CURRENT - arg_pos - 1)) 2>/dev/null)); then
            _describe -t worktrees 'worktrees' worktrees
        fi
    else
        _arguments $switch_opts
    fi
}

_gwm_clean_args() {
    local -a clean_opts
    clean_opts=(
        '--force[Bypass safety checks and delete immediately]'
        '--help[Print usage information for this command]'
    )

    _arguments $clean_opts
}

_gwm_list_args() {
    local -a list_opts
    list_opts=(
        '--verbose[Show detailed information about each worktree]'
        '--json[Output in JSON format]'
        '--help[Print usage information for this command]'
    )

    _arguments $list_opts
}