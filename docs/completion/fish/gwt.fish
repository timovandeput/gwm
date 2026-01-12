# GWT (Git Worktree Manager) fish completion
# Place this file in ~/.config/fish/completions/ or /usr/share/fish/vendor_completions.d/

function __gwt_complete_worktrees
    gwt list 2>/dev/null | grep -v '^Found' | sed 's/^[[:space:]]*//' | cut -d' ' -f1
end

function __gwt_complete_branches
    git branch --all 2>/dev/null | grep -v 'HEAD' | sed 's/^[[:space:]]*//' | sed 's/^[*[:space:]]*//' | sed 's|^remotes/[^/]*/||' | sort | uniq
end

# Complete subcommands
complete -c gwt -f -n '__fish_is_first_arg' -a 'add' -d 'Add a new worktree'
complete -c gwt -f -n '__fish_is_first_arg' -a 'switch' -d 'Switch to an existing worktree'
complete -c gwt -f -n '__fish_is_first_arg' -a 'clean' -d 'Delete current worktree and return to main repo'
complete -c gwt -f -n '__fish_is_first_arg' -a 'list' -d 'List all worktrees'

# Complete worktree names for switch and list commands
complete -c gwt -f -n '__fish_seen_subcommand_from switch list' -a '(__gwt_complete_worktrees)' -d 'Worktree name'

# Complete branch names for add command
complete -c gwt -f -n '__fish_seen_subcommand_from add' -a '(__gwt_complete_branches)' -d 'Branch name'