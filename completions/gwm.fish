# GWM (Git Worktree Manager) fish completion script
#
# Installation:
#   1. Copy this file to your fish completions directory:
#      cp gwm.fish ~/.config/fish/completions/gwm.fish
#
# Usage:
#   Complete commands, subcommands, worktree names, and branch names.
#   Works with: gwm create <TAB>, gwm switch <TAB>, etc.

# Complete subcommands dynamically (only when no subcommand has been seen)
complete -c gwm -f -n '__fish_use_subcommand' -a '(gwm --complete 2>/dev/null)' -d 'GWM subcommands'

# Complete global options (only when no subcommand has been seen)
complete -c gwm -f -n '__fish_use_subcommand' -l 'help' -d 'Print usage information'
complete -c gwm -f -n '__fish_use_subcommand' -l 'verbose' -d 'Show additional command output'
complete -c gwm -f -n '__fish_use_subcommand' -l 'version' -d 'Print the tool version'
complete -c gwm -f -n '__fish_use_subcommand' -l 'no-eval-check' -d 'Skip shell wrapper validation check'
complete -c gwm -f -n '__fish_use_subcommand' -l 'complete' -d 'Generate tab completion candidates'

# Complete create command options and arguments
complete -c gwm -f -n '__fish_seen_subcommand_from create' -l 'branch' -s 'b' -d 'Create the branch if it does not exist'
complete -c gwm -f -n '__fish_seen_subcommand_from create' -l 'help' -s 'h' -d 'Print usage information for this command'
complete -c gwm -A -f -n '__fish_seen_subcommand_from create' -a '(gwm --complete create (commandline -ct) (__fish_number_of_cmd_args) 2>/dev/null)' -d 'Branch name'

# Complete switch command options and arguments
complete -c gwm -f -n '__fish_seen_subcommand_from switch' -l 'help' -s 'h' -d 'Print usage information for this command'
complete -c gwm -f -n '__fish_seen_subcommand_from switch' -l 'reconfigure' -s 'r' -d 'Reconfigure the worktree by copying files and running create hooks'
complete -c gwm -A -f -n '__fish_seen_subcommand_from switch' -a '(gwm --complete switch (commandline -ct) (__fish_number_of_cmd_args) 2>/dev/null)' -d 'Worktree name'

# Complete delete command options and arguments
complete -c gwm -f -n '__fish_seen_subcommand_from delete' -l 'force' -s 'f' -d 'Bypass safety checks and delete immediately'
complete -c gwm -f -n '__fish_seen_subcommand_from delete' -l 'help' -s 'h' -d 'Print usage information for this command'
complete -c gwm -A -f -n '__fish_seen_subcommand_from delete' -a '(gwm --complete delete (commandline -ct) (__fish_number_of_cmd_args) 2>/dev/null)' -d 'Worktree name'

# Complete list command options
complete -c gwm -f -n '__fish_seen_subcommand_from list' -l 'verbose' -s 'v' -d 'Show detailed information about each worktree'
complete -c gwm -f -n '__fish_seen_subcommand_from list' -l 'json' -s 'j' -d 'Output in JSON format'
complete -c gwm -f -n '__fish_seen_subcommand_from list' -l 'help' -s 'h' -d 'Print usage information for this command'