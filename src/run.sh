#!/bin/sh
# pashage - age-backed POSIX password manager
# Copyright (C) 2024  Natasha Kerensikova
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

# Set pipefail if it works in a subshell, disregard if unsupported
# shellcheck disable=SC3040
(set -o pipefail 2> /dev/null) && set -o pipefail
set -Cue
set +x

#################
# CONFIGURATION #
#################

### Pashage/passage specific configuration
AGE="${PASHAGE_AGE:-${PASSAGE_AGE:-age}}"
IDENTITIES_FILE="${PASHAGE_IDENTITIES_FILE:-${PASSAGE_IDENTITIES_FILE:-${HOME}/.passage/identities}}"
PREFIX="${PASHAGE_DIR:-${PASSAGE_DIR:-${PASSWORD_STORE_DIR:-${HOME}/.passage/store}}}"

### Configuration inherited from password-store
CHARACTER_SET="${PASSWORD_STORE_CHARACTER_SET:-[:punct:][:alnum:]}"
CHARACTER_SET_NO_SYMBOLS="${PASSWORD_STORE_CHARACTER_SET_NO_SYMBOLS:-[:alnum:]}"
CLIP_TIME="${PASSWORD_STORE_CLIP_TIME:-45}"
GENERATED_LENGTH="${PASSWORD_STORE_GENERATED_LENGTH:-25}"
X_SELECTION="${PASSWORD_STORE_X_SELECTION:-clipboard}"

### UTF-8 or ASCII tree
TREE__='   '
TREE_I='|  '
TREE_T='|- '
TREE_L='`- '
if [ -n "${LC_CTYPE-}" ] && ! [ "${LC_CTYPE}" = "${LC_CTYPE#*UTF}" ]; then
	TREE_I='│  '
	TREE_T='├─ '
	TREE_L='└─ '
fi

### Terminal color support
BOLD_TEXT=""
NORMAL_TEXT=""
RED_TEXT=""
BLUE_TEXT=""
UNDERLINE_TEXT=""
NO_UNDERLINE_TEXT=""
if [ -n "${CLICOLOR-}" ]; then
	BOLD_TEXT="$(printf '\033[1m')"
	NORMAL_TEXT="$(printf '\033[0m')"
	RED_TEXT="$(printf '\033[31m')"
	BLUE_TEXT="$(printf '\033[34m')"
	UNDERLINE_TEXT="$(printf '\033[4m')"
	NO_UNDERLINE_TEXT="$(printf '\033[24m')"
fi

### Git environment clean-up
unset GIT_DIR
unset GIT_WORK_TREE
unset GIT_NAMESPACE
unset GIT_INDEX_FILE
unset GIT_INDEX_VERSION
unset GIT_OBJECT_DIRECTORY
unset GIT_COMMON_DIR
export GIT_CEILING_DIRECTORIES="${PREFIX}/.."

###########
# IMPORTS #
###########

: "${PASHAGE_SRC_DIR:=$(dirname "$0")}"
PLATFORM="$(uname | tr '[:upper:]' '[:lower:]')"
. "${PASHAGE_SRC_DIR}/platform-${PLATFORM%%_*}.sh"
. "${PASHAGE_SRC_DIR}/pashage.sh"

############
# DISPATCH #
############

PROGRAM="$0"
COMMAND="${1-}"
umask "${PASSWORD_STORE_UMASK:-077}"

case "${COMMAND}" in
    copy|cp)	shift; cmd_copy "$@" ;;
    delete)	shift; cmd_delete "$@" ;;
    edit)	shift; cmd_edit "$@" ;;
    find)	shift; cmd_find "$@" ;;
    gen)	shift; cmd_generate "$@" ;;
    generate)	shift; cmd_generate "$@" ;;
    git)	shift; cmd_git "$@" ;;
    gitconfig)	shift; cmd_gitconfig ;;
    grep)	shift; cmd_grep "$@" ;;
    help)	shift; cmd_help ;;
    -h)		shift; cmd_help ;;
    --help)	shift; cmd_help ;;
    init)	shift; cmd_init "$@" ;;
    insert)	shift; cmd_insert "$@" ;;
    list)	shift; cmd_list_or_show "$@" ;;
    ls)		shift; cmd_list_or_show "$@" ;;
    move|mv)	shift; cmd_move "$@" ;;
    random)	shift; cmd_random "$@" ;;
    re-encrypt)	shift; cmd_reencrypt "$@" ;;
    reencrypt)	shift; cmd_reencrypt "$@" ;;
    remove)	shift; cmd_delete "$@" ;;
    rm)		shift; cmd_delete "$@" ;;
    show)	shift; cmd_list_or_show "$@" ;;
    --version)	shift; cmd_version ;;
    version)	shift; cmd_version ;;
    *)		       cmd_list_or_show "$@" ;;
esac
