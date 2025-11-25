# pashage - age-backed POSIX password manager
# Copyright (C) 2025  Natasha Kerensikova
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

# TODO: incompatible options

function __fish_pashage_any_command
    set -l cmd (commandline -poc)
    set -q cmd[2] && string match -vq -- '-*' $cmd[2]
end

function __fish_pashage_command
    set -l cmd (commandline -poc)
    set -q cmd[2] && contains -- $cmd[2] $argv
end

function __fish_pashage_opt_command
    set -l cmd (commandline -poc)
    not set -q cmd[2] \
      || string match -q -- '-*' $cmd[2] \
      || contains -- $cmd[2] $argv
end

function __fish_pashage_list_dirs
    if set -q PASHAGE_DIR
        set -f prefix $PASHAGE_DIR
    else if set -q PASSAGE_DIR
        set -f prefix $PASSAGE_DIR
    else if set -q PASSWORD_STORE_DIR
        set -f prefix $PASSWORD_STORE_DIR
    else
        set -f prefix "$HOME/.passage/store"
    end
    set -l result $prefix/**/
    set -q result[1]
    and string sub -s (string length $prefix/x) $result
end

function __fish_pashage_list_entries
    if set -q PASHAGE_DIR
        set -f prefix $PASHAGE_DIR
    else if set -q PASSAGE_DIR
        set -f prefix $PASSAGE_DIR
    else if set -q PASSWORD_STORE_DIR
        set -f prefix $PASSWORD_STORE_DIR
    else
        set -f prefix "$HOME/.passage/store"
    end
    set -l result $prefix/**.age
    set -q result[1]
    and string sub -s (string length $prefix/x) -e -4 $result
end

# Command completion
complete -f -c pashage -n 'not __fish_pashage_any_command' \
    -a 'copy cp' -d 'Command: Copy password'
complete -f -c pashage -n 'not __fish_pashage_any_command' \
    -a 'delete remove rm' -d 'Command: Remove password'
complete -f -c pashage -n 'not __fish_pashage_any_command' \
    -a 'edit' -d 'Command: Edit password'
complete -f -c pashage -n 'not __fish_pashage_any_command' \
    -a 'find' -d 'Command: Find password by name'
complete -f -c pashage -n 'not __fish_pashage_any_command' \
    -a 'generate gen' -d 'Command: Generate a new password'
complete -f -c pashage -n 'not __fish_pashage_any_command' \
    -a 'git' -d 'Command: Repository actions'
complete -f -c pashage -n 'not __fish_pashage_any_command' \
    -a 'gitconfig' -d 'Command: Repository setup'
complete -f -c pashage -n 'not __fish_pashage_any_command' \
    -a 'grep' -d 'Command: Grep into decrypted secrets'
complete -f -c pashage -n 'not __fish_pashage_any_command' \
    -a 'help' -d 'Command: Display help'
complete -f -c pashage -n 'not __fish_pashage_any_command' \
    -a 'init' -d 'Command: Init recipient list'
complete -f -c pashage -n 'not __fish_pashage_any_command' \
    -a 'insert' -d 'Command: Insert existing secret'
complete -f -c pashage -n 'not __fish_pashage_any_command' \
    -a 'list ls' -d 'Command: List passwords'
complete -f -c pashage -n 'not __fish_pashage_any_command' \
    -a 'move mv' -d 'Command: Move password'
complete -f -c pashage -n 'not __fish_pashage_any_command' \
    -a 'random' -d 'Command: Generate password without storage'
complete -f -c pashage -n 'not __fish_pashage_any_command' \
    -a 're-encrypt reencrypt' -d 'Command: Re-encrypt passwords'
complete -f -c pashage -n 'not __fish_pashage_any_command' \
    -a 'show' -d 'Command: Show a password'
complete -f -c pashage -n 'not __fish_pashage_any_command' \
    -a 'version' -d 'Command: Display version'

# Option completion
complete -f -c pashage -n '__fish_pashage_opt_command gen generate show' \
    -s 'c' -l 'clip' -d 'paste secret into clipboard'
complete -f -c pashage -n '__fish_pashage_command re-encrypt reencrypt' \
    -s 'd' -l 'deep' -d 're-encrypt subfolders with their own recipients'
complete -f -c pashage -n '__fish_pashage_command insert' \
    -s 'e' -l 'echo' -d 'non-hidden password entry'
complete -f -c pashage -n '__fish_pashage_command copy cp move mv' \
    -s 'e' -l 'reencrypt' -d 'always re-encrypt secrets'
complete -f -c pashage -n '__fish_pashage_command copy cp move mv' \
    -s 'f' -l 'force' -d 'overwrite existing secrets without confirmation'
complete -f -c pashage -n '__fish_pashage_command delete remove rm' \
    -s 'f' -l 'force' -d 'delete without asking for confirmation'
complete -f -c pashage -n '__fish_pashage_command gen generate insert' \
    -s 'f' -l 'force' -d 'replace secret without confirmation'
complete -f -c pashage -n '__fish_pashage_command gen generate' \
    -s 'i' -l 'in-place' -d 'replace first line of existing secret'
complete -f -c pashage \
    -n '__fish_pashage_command copy cp init move mv re-encrypt reencrypt' \
    -s 'i' -l 'interactive' -d 'ask whether to re-encrypt or not'
complete -f -c pashage -n '__fish_pashage_command copy cp init move mv' \
    -s 'k' -l 'keep' -d 'never re-encrypt secrets'
complete -f -c pashage -n '__fish_pashage_command gen generate' \
    -s 'm' -l 'multiline' -d 'append extra lines after generated secret'
complete -f -c pashage -n '__fish_pashage_command insert' \
    -s 'm' -l 'multiline' -d 'import multiple lines per secret'
complete -f -c pashage -n '__fish_pashage_command init' \
    -s 'p' -l 'path' -r -a '(__fish_pashage_list_dirs)' \
    -d 'initialize subfolder'
complete -f -c pashage -n '__fish_pashage_opt_command gen generate show' \
    -s 'q' -l 'qrcode' -d 'display secret as QR-code'
complete -f -c pashage -n '__fish_pashage_command delete remove rm' \
    -s 'r' -l 'recursive' -d 'recursively delete subfolders'
complete -f -c pashage -n '__fish_pashage_opt_command list ls find' \
    -s 'r' -l 'raw' -d 'raw list output'
complete -f -c pashage -n '__fish_pashage_command gen generate' \
    -s 't' -l 'try' -d 'ask confirmation before storing new password'

# Secret completion
complete -f -c pashage -n '__fish_pashage_command insert list ls' \
    -a '(__fish_pashage_list_dirs)' -d 'Subfolder'
complete -f -c pashage \
    -n '__fish_pashage_opt_command copy cp delete edit gen generate move mv re-encrypt reencrypt remve rm show' \
    -a '(__fish_pashage_list_entries)' -d 'Secret'
