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

NL="$(printf '\nend')"
NL="${NL%end}"

#############################
# INTERNAL HELPER FUNCTIONS #
#############################

# Check a path and abort if it looks suspicious
#   $1: path to check
check_sneaky_path() {
	if [ "$1" = ".." ] \
	    || [ "$1" = "../${1#../}" ] \
	    || [ "$1" = "${1%/..}/.." ] \
	    || ! [ "$1" = "${1##*/../}" ] \
	    && [ -n "$1" ]
	then
		die "Encountered path considered sneaky: \"$1\""
	fi
}

# Check paths and abort if any looks suspicious
check_sneaky_paths() {
	for ARG in "$@"; do
		check_sneaky_path "${ARG}"
	done
	unset ARG
}

# Run the arguments as a command an die on failure
checked() {
	if "$@"; then
		:
	else
		CODE="$?"
		printf '%s\n' "Fatal(${CODE}): $*" >&2
		exit "${CODE}"
	fi
}

# Output an error message and quit immediately
die() {
	printf '%s\n' "$*" >&2
	exit 1
}

# Checks whether a globs expands correctly
# This lets the shell expand the glob as an argument list, and counts on
# the glob being passed unchanged as $1 otherwise.
glob_exists() {
	if [ -e "$1" ]; then
		ANSWER=y
	else
		ANSWER=n
	fi
}

# Always-successful grep filter
#   ... grep arguments
grep_filter() {
	grep "$@" || true
}

# Generate random characters
#   $1: number of characters
#   $2: allowed character set
random_chars() {
	LC_ALL=C tr -dc -- "$2" </dev/urandom | dd ibs=1 obs=1 count="$1" \
	    2>/dev/null || true
}

# Find the deepest recipient file above the given path
set_LOCAL_RECIPIENT_FILE() {
	LOCAL_RECIPIENT_FILE="/$1"

	while [ -n "${LOCAL_RECIPIENT_FILE}" ] \
	   && ! [ -f "${PREFIX}${LOCAL_RECIPIENT_FILE}/.age-recipients" ]
	do
		LOCAL_RECIPIENT_FILE="${LOCAL_RECIPIENT_FILE%/*}"
	done

	if ! [ -f "${PREFIX}${LOCAL_RECIPIENT_FILE}/.age-recipients" ]; then
		LOCAL_RECIPIENT_FILE=
		LOCAL_RECIPIENTS=
		return 0
	fi

	LOCAL_RECIPIENT_FILE="${PREFIX}${LOCAL_RECIPIENT_FILE}/.age-recipients"
	LOCAL_RECIPIENTS="$(cat "${LOCAL_RECIPIENT_FILE}")"
}

# Count how many characters are in the first argument
#   $1: string to measure
strlen(){
	RESULT=0
	STR="$1"
	while [ -n "${STR}" ]; do
		RESULT=$((RESULT + 1))
		STR="${STR#?}"
	done
	printf '%s\n' "${RESULT}"
	unset RESULT
	unset STR
}

# Ask for confirmation
#   $1: Prompt
yesno() {
	printf '%s [y/n]' "$1"

	if type stty >/dev/null 2>&1 && stty >/dev/null 2>&1; then

		# Enable raw input to allow for a single byte to be read from
		# stdin without needing to wait for the user to press Return.
		stty -icanon

		ANSWER=''

		while [ "${ANSWER}" = "${ANSWER#[NnYy]}" ]; do
			# Read a single byte from stdin using 'dd'.
			# POSIX 'read' has no support for single/'N' byte
			# based input from the user.
			ANSWER=$(dd ibs=1 count=1 2>/dev/null)
		done

		# Disable raw input, leaving the terminal how we *should*
		# have found it.
		stty icanon

		printf '\n'
	else
		read -r ANSWER
		ANSWER="${ANSWER%"${ANSWER#?}"}"
	fi

	if [ "${ANSWER}" = Y ]; then
		ANSWER=y
	fi
}


##################
# SCM MANAGEMENT #
##################

# Add a file or directory to pending changes
#   $1: path
scm_add() {
	[ -d "${PREFIX}/.git" ] || return 0
	git -C "${PREFIX}" add -- "$1"
}

# Start a sequence of changes, asserting nothing is pending
scm_begin() {
	[ -d "${PREFIX}/.git" ] || return 0
	if [ -n "$(git -C "${PREFIX}" status --porcelain || true)" ]; then
		die "There are already pending changes."
	fi
}

# Commit pending changes
#   $1: commit message
scm_commit() {
	[ -d "${PREFIX}/.git" ] || return 0
	if [ -n "$(git -C "${PREFIX}" status --porcelain || true)" ]; then
		git -C "${PREFIX}" commit -m "$1" >/dev/null
	fi
}

# Copy a file or directory in the filesystem and put it in pending changes
#   $1: source
#   $2: destination
scm_cp() {
	cp -rf -- "${PREFIX}/$1" "${PREFIX}/$2"
	scm_add "$2"
}

# Add deletion of a file or directory to pending changes
#   $1: path
scm_del() {
	[ -d "${PREFIX}/.git" ] || return 0
	git -C "${PREFIX}" rm -qr -- "$1"
}

# Move a file or directory in the filesystem and put it in pending changes
#   $1: source
#   $2: destination
scm_mv() {
	if [ -d "${PREFIX}/.git" ]; then
		git -C "${PREFIX}" mv -f -- "$1" "$2"
	else
		mv -f -- "${PREFIX}/$1" "${PREFIX}/$2"
	fi
}

# Delete a file or directory from filesystem and put it in pending changes
scm_rm() {
	rm -rf -- "${PREFIX:?}/$1"
	scm_del "$1"
}


###########
# ACTIONS #
###########

# Copy or move (depending on ${ACTION}) a secret file or directory
#   $1: source name
#   $2: destination name
#   ACTION: Copy or Move
#   DECISION: whether to re-encrypt or copy/move
#   OVERWRITE: whether to overwrite without confirmation
#   SCM_ACTION: scm_cp or scm_mv
do_copy_move() {
	if [ "$1" = "${1%/}/" ]; then
		if ! [ -d "${PREFIX}/$1" ]; then
			die "Error: $1 is not in the password store."
		fi
		SRC="$1"
	elif [ -e "${PREFIX}/$1.age" ] && ! [ -d "${PREFIX}/$1.age" ]; then
		SRC="$1.age"
	elif [ -n "$1" ] && [ -d "${PREFIX}/$1" ]; then
		SRC="$1/"
	elif [ -e "${PREFIX}/$1" ]; then
		SRC="$1"
	else
		die "Error: $1 is not in the password store."
	fi

	if [ -z "${SRC}" ] || [ "${SRC}" = "${SRC%/}/" ]; then
		LOCAL_ACTION=do_copy_move_dir
		if [ -d "${PREFIX}/$2" ]; then
			DEST="${2%/}${2:+/}$(basename "${SRC%/}")/"
			if [ -e "${PREFIX}/${DEST}" ] \
			    && [ "${ACTION}" = Move ]
			then
				die "Error: $2 already contains" \
				    "$(basename "${SRC%/}")"
			fi
		else
			DEST="${2%/}${2:+/}"
			if [ -e "${PREFIX}/${DEST%/}" ]; then
				die "Error: ${DEST%/} is not a directory"
			fi
		fi

	elif [ "$2" = "${2%/}/" ] || [ -d "${PREFIX}/$2" ]; then
		[ -d "${PREFIX}/$2" ] || mkdir -p -- "${PREFIX}/$2"
		[ -d "${PREFIX}/$2" ] || die "Error: $2 is not a directory"

		DEST="${2%/}/$(basename "${SRC}")"
		if [ -d "${PREFIX}/${DEST}" ]; then
			die "Error: $2 already contains $(basename "${SRC}")/"
		fi
		LOCAL_ACTION=do_copy_move_file

	else
		if [ "${SRC}" = "${SRC%.age}.age" ] \
		    && ! [ "$2" = "${2%.age}.age" ]
		then
			DEST="$2.age"
		else
			DEST="$2"
		fi

		mkdir -p -- "$(dirname "${PREFIX}/${DEST}")"
		LOCAL_ACTION=do_copy_move_file
	fi

	scm_begin
	SCM_COMMIT_MSG="${ACTION} ${SRC} to ${DEST}"

	"${LOCAL_ACTION}" "${SRC}" "${DEST}"

	scm_commit "${SCM_COMMIT_MSG}"

	unset LOCAL_ACTION
	unset SRC
	unset DEST
	unset SCM_COMMIT_MSG
}

# Copy or move a secret directory (depending on ${ACTION})
#   $1: source directory name (with a trailing slash)
#   $2: destination directory name (with a trailing slash)
#   DECISION: whether to re-encrypt or copy/move
#   SCM_ACTION: scm_cp or scm_mv
do_copy_move_dir() {
	[ "$1" = "${1%/}/" ] || [ -z "$1" ] || die 'Internal error'
	[ "$2" = "${2%/}/" ] || [ -z "$2" ] || die 'Internal error'
	[ -d "${PREFIX}/$1" ] || die 'Internal error'

	[ -d "${PREFIX}/$2" ] || mkdir -p -- "${PREFIX}/${2%/}"

	for ARG in "${PREFIX}/$1".* "${PREFIX}/$1"*; do
		SRC="${ARG#"${PREFIX}/"}"
		DEST="$2$(basename "${ARG}")"

		if [ -f "${ARG}" ]; then
			do_copy_move_file "${SRC}" "${DEST}"
		elif [ -d "${ARG}" ] && [ "${ARG}" = "${ARG%/.*}" ]
		then
			do_copy_move_dir "${SRC}/" "${DEST}/"
		fi
	done

	unset ARG
	rmdir -p -- "${PREFIX}/$1" 2>/dev/null || true
}

# Copy or move a secret file (depending on ${ACTION})
#   $1: source file name
#   $2: destination file name
#   ACTION: Copy or Move
#   DECISION: whether to re-encrypt or copy/move
#   OVERWRITE: whether to overwrite without confirmation
#   SCM_ACTION: scm_cp or scm_mv
do_copy_move_file() {
	if [ -e "${PREFIX}/$2" ]; then
		if ! [ "${OVERWRITE}" = yes ]; then
			yesno "$2 already exists. Overwrite?"
			[ "${ANSWER}" = y ] || return 0
			unset ANSWER
		fi

		rm -f -- "${PREFIX}/$2"
	fi

	if [ "$1" = "${1%.age}.age" ]; then
		case "${DECISION}" in
		    keep)
			ANSWER=n
			;;
		    interactive)
			yesno "Reencrypt ${1%.age} into ${2%.age}?"
			;;
		    default)
			set_LOCAL_RECIPIENT_FILE "$1"
			SRC_RCPT="${LOCAL_RECIPIENTS}"
			set_LOCAL_RECIPIENT_FILE "$2"
			DST_RCPT="${LOCAL_RECIPIENTS}"

			if [ "${SRC_RCPT}" = "${DST_RCPT}" ]; then
				ANSWER=n
			else
				ANSWER=y
			fi

			unset DST_RCPT
			unset SRC_RCPT
			;;
		    force)
			ANSWER=y
			;;
		    *)
			die "Unexpected DECISION value \"${DECISION}\""
			;;
		esac
	else
		ANSWER=n
	fi

	if [ "${ANSWER}" = y ]; then
		do_decrypt "${PREFIX}/$1" | do_encrypt "$2"
		if [ "${ACTION}" = Move ]; then
			scm_rm "$1"
		fi
		scm_add "$2"
	else
		"${SCM_ACTION}" "$1" "$2"
	fi

	unset ANSWER
}

# Decrypt a secret file into standard output
#   $1: full path of the encrypted file
#   IDENTITIES_FILE: full path of age identity
do_decrypt() {
	checked "${AGE}" -d -i "${IDENTITIES_FILE}" -- "$1"
}

# Decrypt a GPG secret file into standard output
#   $1: pull path of the encrypted file
#   GPG: (optional) gpg command
do_decrypt_gpg() {
	if [ -z "${GPG-}" ]; then
		if type gpg2 >/dev/null 2>&1; then
			GPG=gpg2
		elif type gpg >/dev/null 2>&1; then
			GPG=gpg
		else
			die "GPG does not seem available"
		fi
	fi

	set -- -- "$@"
	if [ -n "${GPG_AGENT_INFO-}" ] || [ "${GPG}" = "gpg2" ]; then
		set -- "--batch" "--use-agent" "$@"
	fi
	set -- "--quiet" \
	    "--yes" \
	    "--compress-algo=none" \
	    "--no-encrypt-to" \
	    "$@"

	checked "${GPG}" -d "$@"
}

# Remove identities from a subdirectory
#   $1: relative subdirectory (may be empty)
#   DECISION: whether to re-encrypt or not
do_deinit() {
	LOC="${1:-store root}"
	TARGET="${1%/}${1:+/}.age-recipients"

	if ! [ -f "${PREFIX}/${TARGET}" ]; then
		die "No existing recipient to remove at ${LOC}"
	fi

	scm_begin
	scm_rm "${TARGET}"
	if ! [ "${DECISION}" = keep ]; then
		do_reencrypt_dir "${PREFIX}/$1"
	fi
	scm_commit "Deinitialize ${LOC}"
	rmdir -p -- "${PREFIX}/$1" 2>/dev/null || true

	unset LOC
	unset TARGET
}

# Delete a file or directory from the password store
#   $1: file or directory name
#   DECISION: whether to ask before deleting
#   RECURSIVE: whether to delete directories
do_delete() {
	# Distinguish between file or directory
	if [ "$1" = "${1%/}/" ]; then
		NAME="$1"
		TARGET="$1"
		if ! [ -e "${PREFIX}/${NAME%/}" ]; then
			die "Error: $1 is not in the password store."
		fi
		if ! [ -d "${PREFIX}/${NAME%/}" ]; then
			die "Error: $1 is not a directory."
		fi
		if ! [ "${RECURSIVE}" = yes ]; then
			die "Error: $1 is a directory"
		fi
	elif [ -f "${PREFIX}/$1.age" ]; then
		NAME="$1"
		TARGET="$1.age"
	elif [ -d "${PREFIX}/$1" ]; then
		if ! [ "${RECURSIVE}" = yes ]; then
			die "Error: $1/ is a directory"
		fi
		NAME="$1/"
		TARGET="$1/"
	else
		die "Error: $1 is not in the password store."
	fi

	if [ "${DECISION}" = force ]; then
		printf '%s\n' "Removing ${NAME}"
	else
		yesno "Are you sure you would like to delete ${NAME}?"
		[ "${ANSWER}" = y ] || return 0
		unset ANSWER
	fi

	# Perform the deletion
	scm_begin
	scm_rm "${TARGET}"
	scm_commit "Remove ${NAME} from store."
	rmdir -p -- "$(dirname "${PREFIX}/${TARGET}")" 2>/dev/null || true
}

# Edit a secret interactively
#   $1: pass-name
#   EDIT_CMD, EDITOR, VISUAL: editor command
do_edit() {
	NAME="${1#/}"
	TARGET="${PREFIX}/${NAME}.age"

	TMPNAME="${NAME}"
	while ! [ "${TMPNAME}" = "${TMPNAME#*/}" ]; do
		TMPNAME="${TMPNAME%%/*}-${TMPNAME#*/}"
	done

	TMPFILE="$(mktemp -u "${SECURE_TMPDIR}/XXXXXX")-${TMPNAME}.txt"

	if [ -f "${TARGET}" ]; then
		ACTION="Edit"
		do_decrypt "${TARGET}" >"${TMPFILE}"
		OLD_VALUE="$(cat "${TMPFILE}")"
	else
		ACTION="Add"
		OLD_VALUE=
	fi

	scm_begin

	if [ -z "${EDIT_CMD-}" ]; then
		if [ -n "${VISUAL-}" ] && ! [ "${TERM:-dumb}" = dumb ]; then
			EDIT_CMD="${VISUAL}"
		elif [ -n "${EDITOR-}" ]; then
			EDIT_CMD="${EDITOR}"
		else
			EDIT_CMD="vi"
		fi
	fi

	if ${EDIT_CMD} "${TMPFILE}"; then
		:
	else
		CODE="$?"
		printf 'Editor "%s" exited with code %s\n' \
		    "${EDIT_CMD}" "${CODE}" >&2
		exit "${CODE}"
	fi

	if ! [ -f "${TMPFILE}" ]; then
		printf '%s\n' "New password for ${NAME} not saved."
	elif [ -n "${OLD_VALUE}" ] \
	    && printf '%s\n' "${OLD_VALUE}" \
	        | diff -- - "${TMPFILE}" >/dev/null 2>&1
	then
		printf '%s\n' "Password for ${NAME} unchanged."
		rm "${TMPFILE}"
	else
		OVERWRITE=once
		do_encrypt "${NAME}.age" <"${TMPFILE}"
		scm_add "${NAME}.age"
		scm_commit "${ACTION} password for ${NAME} using ${EDIT_CMD}."
		rm "${TMPFILE}"
	fi

	unset ACTION
	unset OLD_VALUE
	unset NAME
	unset TARGET
	unset TMPNAME
	unset TMPFILE
}

# Encrypt a secret on standard input into a file
#   $1: relative path of the encrypted file
do_encrypt() {
	TARGET="$1"
	set --

	if [ -n "${PASHAGE_RECIPIENTS_FILE-}" ]; then
		set -- "$@" -R "${PASHAGE_RECIPIENTS_FILE}"

	elif [ -n "${PASSAGE_RECIPIENTS_FILE-}" ]; then
		set -- "$@" -R "${PASSAGE_RECIPIENTS_FILE}"

	elif [ -n "${PASHAGE_RECIPIENTS-}" ]; then
		for ARG in ${PASHAGE_RECIPIENTS}; do
			set -- "$@" -r "${ARG}"
		done
		unset ARG

	elif [ -n "${PASSAGE_RECIPIENTS-}" ]; then
		for ARG in ${PASSAGE_RECIPIENTS}; do
			set -- "$@" -r "${ARG}"
		done
		unset ARG

	else
		set_LOCAL_RECIPIENT_FILE "${TARGET}"

		if [ -n "${LOCAL_RECIPIENT_FILE}" ]; then
			set -- "$@" -R "${LOCAL_RECIPIENT_FILE}"
		else
			set -- "$@" -i "${IDENTITIES_FILE}"
		fi
	fi

	unset LOCAL_RECIPIENT_FILE

	if [ -e "${PREFIX}/${TARGET}" ] && ! [ "${OVERWRITE}" = yes ]; then
		if [ "${OVERWRITE}" = once ]; then
			OVERWRITE=no
		else
			die "Refusing to overwite ${TARGET}"
		fi
	fi
	mkdir -p "$(dirname "${PREFIX}/${TARGET}")"
	"${AGE}" -e "$@" -o "${PREFIX}/${TARGET}"
	unset TARGET
}

# Generate a new secret
#   $1: secret name
#   $2: new password length
#   $3: new password charset
#   DECISION: when interactive, show-ask-commit instead of commit-show
#   OVERWRITE: whether to overwrite with confirmation ("no"), without
#              confirmation ("yes"), or with existing secret data ("reuse")
#   SELECTED_LINE: which line to paste or diplay as qr-code
#   SHOW: how to show the secret
do_generate() {
	NEW_PASS="$(random_chars "$2" "$3")"
	NEW_PASS_LEN="$(strlen "${NEW_PASS}")"

	if [ "${NEW_PASS_LEN}" -ne "$2" ]; then
		die "Error while generating password:" \
		    "${NEW_PASS_LEN}/$2 bytes read"
	fi
	unset NEW_PASS_LEN

	if [ "${DECISION}" = interactive ]; then
		do_generate_show "$@"
		yesno "Save generated password for $1?"
		[ "${ANSWER}" = y ] && do_generate_commit "$@"
	else
		do_generate_commit "$@"
		[ "${ANSWER-y}" = y ] && do_generate_show "$@"
	fi

	unset NEW_PASS
}

# SCM-committing part of do_generate
do_generate_commit() {
	scm_begin
	mkdir -p -- "$(dirname "${PREFIX}/$1.age")"
	EXTRA=

	if [ -d "${PREFIX}/$1.age" ]; then
		die "Cannot replace directory $1.age"

	elif [ -e "${PREFIX}/$1.age" ] && [ "${OVERWRITE}" = reuse ]; then
		printf '%s\n' "Decrypting previous secret for $1"
		OLD_SECRET_FULL="$(do_decrypt "${PREFIX}/$1.age")"
		OLD_SECRET="${OLD_SECRET_FULL#*"${NL}"}"
		if ! [ "${OLD_SECRET}" = "${OLD_SECRET_FULL}" ]; then
			EXTRA="${OLD_SECRET}"
		fi
		unset OLD_SECRET
		unset OLD_SECRET_FULL
		OVERWRITE=once
		VERB="Replace"

	else
		if [ -e "${PREFIX}/$1.age" ] && ! [ "${OVERWRITE}" = yes ]; then
			yesno "An entry already exists for $1. Overwrite it?"
			[ "${ANSWER}" = y ] || return 0
			unset ANSWER
			OVERWRITE=once
		fi

		VERB="Add"
	fi

	if [ "${MULTILINE}" = yes ]; then
		while IFS='' read -r LINE; do
			EXTRA="${EXTRA}${EXTRA:+${NL}}${LINE}"
		done
	fi

	do_encrypt "$1.age" <<-EOF
		${NEW_PASS}${EXTRA:+${NL}}${EXTRA}
	EOF

	unset EXTRA

	scm_add "${PREFIX}/$1.age"
	scm_commit "${VERB} generated password for $1."

	unset VERB
}

# Showing part of do_generate
do_generate_show() {
	if [ "${SHOW}" = text ]; then
		printf '%sThe generated password for %s%s%s is:%s\n' \
		    "${BOLD_TEXT}" \
		    "${UNDERLINE_TEXT}" \
		    "$1" \
		    "${NO_UNDERLINE_TEXT}" \
		    "${NORMAL_TEXT}"
	fi

	do_show "$1" <<-EOF
		${NEW_PASS}
	EOF
}

# Recursively grep decrypted secrets in current directory
#   $1: current subdirectory name
#   ... grep arguments
do_grep() {
	SUBDIR="$1"
	shift

	glob_exists ./*
	[ "${ANSWER}" = y ] || return 0
	unset ANSWER

	for ARG in *; do
		if [ -d "${ARG}" ]; then
			( cd "${ARG}" && do_grep "${SUBDIR}${ARG}/" "$@" )
		elif [ "${ARG}" = "${ARG%.age}.age" ]; then
			HEADER="${BLUE_TEXT}${SUBDIR}${BOLD_TEXT}"
			HEADER="${HEADER}${ARG%.age}${NORMAL_TEXT}:"
			SECRET="$(do_decrypt "${ARG}")"
			do_grep_filter "$@" <<-EOF
				${SECRET}
			EOF
		fi
	done

	unset ARG
	unset HEADER
}

# Wrapper around grep filter to added a header when a match is found
#   ... grep arguments
#   HEADER header to print before matches, if any
do_grep_filter() {
	unset SECRET

	grep_filter "$@" | while IFS= read -r LINE; do
		[ -n "${HEADER}" ] && printf '%s\n' "${HEADER}"
		printf '%s\n' "${LINE}"
		HEADER=''
	done
}

# Add identities to a subdirectory
#   $1: relative subdirectory (may be empty)
#   ... identities
#   DECISION: whether to re-encrypt or not
do_init() {
	LOC="${1:-store root}"
	SUBDIR="${PREFIX}${1:+/}${1%/}"
	TARGET="${SUBDIR}/.age-recipients"
	shift

	mkdir -p -- "${SUBDIR}"

	scm_begin

	if ! [ -f "${TARGET}" ] || [ "${OVERWRITE}" = yes ]; then
		: >|"${TARGET}"
	fi

	printf '%s\n' "$@" >>"${TARGET}"
	scm_add "${TARGET#"${PREFIX}/"}"
	if ! [ "${DECISION}" = keep ]; then
		do_reencrypt_dir "${SUBDIR}"
	fi
	scm_commit "Set age recipients at ${LOC}"
	printf '%s\n' "Password store recipients set at ${LOC}"

	unset LOC
	unset TARGET
	unset SUBDIR
}

# Insert a new secret from standard input
#   $1: entry name
#   ECHO: whether interactive echo is kept
#   MULTILINE: whether whole standard input is used
#   OVERWRITE: whether to overwrite without confirmation
do_insert() {
	if [ -e "${PREFIX}/$1.age" ] && [ "${OVERWRITE}" = no ]; then
		yesno "An entry already exists for $1. Overwrite it?"
		[ "${ANSWER}" = y ] || return 0
		unset ANSWER
		OVERWRITE=once
	fi

	scm_begin
	mkdir -p -- "$(dirname "${PREFIX}/$1.age")"

	if [ "${MULTILINE}" = yes ]; then
		printf '%s\n' \
		    "Enter contents of $1 and" \
		    "press Ctrl+D or enter an empty line when finished:"
		while IFS= read -r LINE; do
			if [ -n "${LINE}" ]; then
				printf '%s\n' "${LINE}"
			else
				break
			fi
		done | do_encrypt "$1.age"

	elif [ "${ECHO}" = yes ] \
	    || ! type stty >/dev/null 2>&1 \
	    || ! stty >/dev/null 2>&1
	then
		printf 'Enter password for %s: ' "$1"
		IFS= read -r LINE
		do_encrypt "$1.age" <<-EOF
			${LINE}
		EOF
		unset LINE

	else
		while true; do
			printf 'Enter password for %s:  ' "$1"
			stty -echo
			read -r LINE1
			printf '\nRetype password for %s: ' "$1"
			read -r LINE2
			stty echo
			printf '\n'

			if [ "${LINE1}" = "${LINE2}" ]; then
				break
			else
				unset LINE1 LINE2
				echo "Passwords don't match"
			fi
		done

		do_encrypt "$1.age" <<-EOF
			${LINE1}
		EOF
		unset LINE1 LINE2
	fi

	scm_add "$1.age"
	scm_commit "Add given password for $1 to store."
}

# Display a single directory or entry
#   $1: entry name
do_list_or_show() {
	if [ -z "$1" ]; then
		do_tree "${PREFIX}" "Password Store"
	elif [ -f "${PREFIX}/$1.age" ]; then
		SECRET="$(do_decrypt "${PREFIX}/$1.age")"
		do_show "$1" <<-EOF
			${SECRET}
		EOF
		unset SECRET
	elif [ -d "${PREFIX}/$1" ]; then
		do_tree "${PREFIX}/$1" "$1"
	elif [ -f "${PREFIX}/$1.gpg" ]; then
		SECRET="$(do_decrypt_gpg "${PREFIX}/$1.gpg")"
		do_show "$1" <<-EOF
			${SECRET}
		EOF
		unset SECRET
	else
		die "Error: $1 is not in the password store."
	fi
}

# Re-encrypts a file or a directory
#   $1: entry name
#   DECISION: whether to ask before re-encryption
do_reencrypt() {
	scm_begin

	if [ "$1" = "${1%/}/" ]; then
		if ! [ -d "${PREFIX}/${1%/}" ]; then
			die "Error: $1 is not in the password store."
		fi
		do_reencrypt_dir "${PREFIX}/${1%/}"
		LOC="$1"

	elif [ -f "${PREFIX}/$1.age" ]; then
		do_reencrypt_file "$1"
		LOC="$1"

	elif [ -d "${PREFIX}/$1" ]; then
		do_reencrypt_dir "${PREFIX}/$1"
		LOC="$1/"

	else
		die "Error: $1 is not in the password store."
	fi

	scm_commit "Re-encrypt ${LOC}"
	unset LOC
}

# Recursively re-encrypts a directory
#   $1: absolute directory path
#   DECISION: whether to ask before re-encryption
do_reencrypt_dir() {
	for ENTRY in "${1%/}"/*; do
		if [ -d "${ENTRY}" ]; then
			if ! [ -e "${ENTRY}/.age-recipients" ] \
			    || [ "${DECISION}" = force ]
			then
				( do_reencrypt_dir "${ENTRY}" )
			fi
		elif [ "${ENTRY}" = "${ENTRY%.age}.age" ]; then
			ENTRY="${ENTRY#"${PREFIX}"/}"
			do_reencrypt_file "${ENTRY%.age}"
		fi
	done
}

# Re-encrypts a file
#   $1: entry name
#   DECISION: whether to ask before re-encryption
do_reencrypt_file() {
	if [ "${DECISION}" = interactive ]; then
		yesno "Re-encrypt $1?"
		[ "${ANSWER}" = y ] || return 0
		unset ANSWER
	fi

	OVERWRITE=once
	WIP_FILE="$(mktemp -u "${PREFIX}/$1-XXXXXXXXX.age")"
	SECRET="$(do_decrypt "${PREFIX}/$1.age")"
	do_encrypt "${WIP_FILE#"${PREFIX}"/}" <<-EOF
		${SECRET}
	EOF
	mv -f -- "${WIP_FILE}" "${PREFIX}/$1.age"
	unset WIP_FILE
	scm_add "$1.age"
}

# Display a decrypted secret from standard input
#   $1: title
#   SELECTED_LINE: which line to paste or diplay as qr-code
#   SHOW: how to show the secret
do_show() {
	unset SECRET

	case "${SHOW}" in
	    text)
		cat
		;;
	    clip)
		tail -n "+${SELECTED_LINE}" \
		    | head -n 1 \
		    | tr -d '\n' \
		    | platform_clip "$1"
		;;
	    qrcode)
		tail -n "+${SELECTED_LINE}" \
		    | head -n 1 \
		    | tr -d '\n' \
		    | platform_qrcode "$1"
		;;
	    *)
		die "Unexpected SHOW value \"${SHOW}\""
		;;
	esac
}

# Display the tree rooted at the given directory
#   $1: root directory
#   $2: title
#  ...: (optional) grep arguments to filter
do_tree() {
	( cd "$1" && shift && do_tree_cwd "$@" )
}

# Display the subtree rooted at the current directory
#   $1: title
#  ...: (optional) grep arguments to filter
do_tree_cwd() {
	ACC=""
	PREV=""
	TITLE="$1"
	shift

	for ENTRY in *; do
		[ -e "${ENTRY}" ] || continue
		ITEM="$(do_tree_item "${ENTRY}" "$@")"
		[ -z "${ITEM}" ] && continue

		if [ -n "${PREV}" ]; then
			ACC="$(printf '%s\n' "${PREV}" | do_tree_prefix "${ACC}" "${TREE_T}" "${TREE_I}")"
		fi

		PREV="${ITEM}"
	done
	unset ENTRY

	if [ -n "${PREV}" ]; then
		ACC="$(printf '%s\n' "${PREV}" | do_tree_prefix "${ACC}" "${TREE_L}" "${TREE__}")"
	fi

	if [ $# -eq 0 ] || [ -n "${ACC}" ]; then
		[ -n "${TITLE}" ] && printf '%s\n' "${TITLE}"
	fi

	[ -n "${ACC}" ] && printf '%s\n' "${ACC}"

	unset ACC
	unset PREV
	unset TITLE
}

# Display a node in a tree
#   $1: item name
#  ...: (optional) grep arguments to filter
do_tree_item() {
	ITEM_NAME="$1"
	shift

	if [ -d "${ITEM_NAME}" ]; then
		do_tree "${ITEM_NAME}" \
		    "${BLUE_TEXT}${ITEM_NAME}${NORMAL_TEXT}" \
		    "$@"
	elif [ "${ITEM_NAME%.age}.age" = "${ITEM_NAME}" ]; then
		if [ $# -eq 0 ] \
		    || printf '%s\n' "${ITEM_NAME%.age}" | grep -q "$@"
		then
			printf '%s\n' "${ITEM_NAME%.age}"
		fi
	elif [ "${ITEM_NAME%.gpg}.gpg" = "${ITEM_NAME}" ]; then
		if [ $# -eq 0 ] \
		    || printf '%s\n' "${ITEM_NAME%.age}" | grep -q "$@"
		then
			printf '%s\n' \
			     "${RED_TEXT}${ITEM_NAME%.gpg}${NORMAL_TEXT}"
		fi
	fi

	unset ITEM_NAME
}

# Add a tree prefix
#   $1: optional title before the first line
#   $2: prefix of the first line
#   $3: prefix of the following lines
do_tree_prefix() {
	[ -n "$1" ] && printf '%s\n' "$1"
	IFS= read -r LINE
	printf '%s%s\n' "$2" "${LINE}"
	while IFS= read -r LINE; do
		printf '%s%s\n' "$3" "${LINE}"
	done
	unset LINE
}


############
# COMMANDS #
############

cmd_copy() {
	ACTION=Copy
	SCM_ACTION=scm_cp
	cmd_copy_move "$@"
}

cmd_copy_move() {
	DECISION=default
	OVERWRITE=no
	PARSE_ERROR=no

	while [ $# -ge 1 ]; do
		case "$1" in
		    -f|--force)
			OVERWRITE=yes
			shift ;;
		    -e|--reencrypt)
			[ "${DECISION}" = default ] || PARSE_ERROR=yes
			DECISION=force
			shift ;;
		    -i|--interactive)
			[ "${DECISION}" = default ] || PARSE_ERROR=yes
			DECISION=interactive
			shift ;;
		    -k|--keep)
			[ "${DECISION}" = default ] || PARSE_ERROR=yes
			DECISION=keep
			shift ;;
		    -[efik]?*)
			REST="${1#??}"
			FIRST="${1%"${REST}"}"
			shift
			set -- "${FIRST}" "-${REST}" "$@"
			unset FIRST
			unset REST
			;;
		    --)
			shift
			break ;;
		    -*)
			PARSE_ERROR=yes
			break ;;
		    *)
			break ;;
		esac
	done

	if [ "${PARSE_ERROR}" = yes ] || [ $# -lt 2 ]; then
		if [ "${COMMAND}" = "c${COMMAND#c}" ]; then
			cmd_usage 'Usage: ' copy >&2
			exit 1
		elif [ "${COMMAND}" = "m${COMMAND#m}" ]; then
			cmd_usage 'Usage: ' move >&2
			exit 1
		else
			cmd_usage 'Usage: ' copy move >&2
			exit 1
		fi
	fi
	unset PARSE_ERROR

	check_sneaky_paths "$@"

	if [ $# -gt 2 ]; then
		SHARED_DEST="$1"
		shift
		for ARG in "$@"; do
			shift
			set -- "$@" "${SHARED_DEST}"
			SHARED_DEST="${ARG}"
		done

		for ARG in "$@"; do
			do_copy_move "${ARG}" "${SHARED_DEST%/}/"
		done
	else
		do_copy_move "$@"
	fi
}

cmd_delete() {
	DECISION=default
	PARSE_ERROR=no
	RECURSIVE=no

	while [ $# -ge 1 ]; do
		case "$1" in
		    -f|--force)
			DECISION=force
			shift ;;
		    -r|--recursive)
			RECURSIVE=yes
			shift ;;
		    -[fr]?*)
			REST="${1#??}"
			FIRST="${1%"${REST}"}"
			shift
			set -- "${FIRST}" "-${REST}" "$@"
			unset FIRST
			unset REST
			;;
		    --)
			shift
			break ;;
		    -*)
			PARSE_ERROR=yes
			break ;;
		    *)
			break ;;
		esac
	done

	if [ "${PARSE_ERROR}" = yes ] || [ $# -eq 0 ]; then
		cmd_usage 'Usage: ' delete >&2
		exit 1
	fi
	unset PARSE_ERROR

	check_sneaky_paths "$@"

	for ARG in "$@"; do
		do_delete "${ARG}"
	done
}

cmd_edit() {
	if [ $# -eq 0 ]; then
		cmd_usage 'Usage: ' edit >&2
		exit 1
	fi

	check_sneaky_paths "$@"
	platform_tmpdir

	for ARG in "$@"; do
		do_edit "${ARG}"
	done
}

cmd_find() {
	if [ $# -eq 0 ]; then
		cmd_usage 'Usage: ' find >&2
		exit 1
	fi

	printf 'Search pattern: %s\n' "$*"
	do_tree "${PREFIX}" '' "$@"
}

cmd_generate() {
	CHARSET="${CHARACTER_SET}"
	DECISION=default
	MULTILINE=no
	OVERWRITE=no
	PARSE_ERROR=no
	SELECTED_LINE=1
	SHOW=text

	while [ $# -ge 1 ]; do
		case "$1" in
		    -c|--clip)
			if ! [ "${SHOW}" = text ]; then
				PARSE_ERROR=yes
				break
			fi
			SHOW=clip
			shift ;;
		    -f|--force)
			if ! [ "${OVERWRITE}" = no ]; then
				PARSE_ERROR=yes
				break
			fi
			OVERWRITE=yes
			shift ;;
		    -i|--in-place)
			if ! [ "${OVERWRITE}" = no ]; then
				PARSE_ERROR=yes
				break
			fi
			OVERWRITE=reuse
			shift ;;
		    -m|--multiline)
			MULTILINE=yes
			shift ;;
		    -n|--no-symbols)
			CHARSET="${CHARACTER_SET_NO_SYMBOLS}"
			shift ;;
		    -q|--qrcode)
			if ! [ "${SHOW}" = text ]; then
				PARSE_ERROR=yes
				break
			fi
			SHOW=qrcode
			shift ;;
		    -t|--try)
			DECISION=interactive
			shift ;;
		    -[cfimnqt]?*)
			REST="${1#-?}"
			ARG="${1%"${REST}"}"
			shift
			set -- "${ARG}" "-${REST}" "$@"
			unset ARG
			unset REST
			;;
		    --)
			shift
			break ;;
		    -*)
			PARSE_ERROR=yes
			break ;;
		    *)
			break ;;
		esac
	done

	if [ "${PARSE_ERROR}" = yes ] || [ $# -eq 0 ] || [ $# -gt 3 ]; then
		cmd_usage 'Usage: ' generate >&2
		exit 1
	fi

	unset PARSE_ERROR

	check_sneaky_path "$1"
	LENGTH="${2:-${GENERATED_LENGTH}}"
	[ -n "${LENGTH##*[!0-9]*}" ] \
	    || die "Error: passlength \"${LENGTH}\" must be a number."
	[ "${LENGTH}" -gt 0 ] \
	    || die "Error: pass-length must be greater than zero."

	do_generate "$1" "${LENGTH}" "${3:-${CHARSET}}"

	unset CHARSET
	unset LENGTH
}

cmd_git() {
	if [ -d "${PREFIX}/.git" ]; then
		platform_tmpdir
		TMPDIR="${SECURE_TMPDIR}" git -C "${PREFIX}" "$@"
	elif [ "${1-}" = init ]; then
		mkdir -p -- "${PREFIX}"
		git -C "${PREFIX}" "$@"
		scm_add '.'
		scm_commit "Add current contents of password store."
		cmd_gitconfig
	elif [ "${1-}" = clone ]; then
		git "$@" "${PREFIX}"
		cmd_gitconfig
	else
		die "Error: the password store is not a git repository." \
		    "Try \"${PROGRAM} git init\"."
	fi
}

cmd_grep() {
	if [ $# -eq 0 ]; then
		cmd_usage 'Usage: ' grep >&2
		exit 1
	fi

	( cd "${PREFIX}" && do_grep "" "$@" )
}

cmd_gitconfig() {
	[ -d "${PREFIX}/.git" ] || die "The store is not a git repository."

	if ! [ -f "${PREFIX}/.gitattributes" ] ||
	    ! grep -Fqx '*.age diff=age' "${PREFIX}/.gitattributes"
	then
		scm_begin
		printf '*.age diff=age\n' >>"${PREFIX}/.gitattributes"
		scm_add ".gitattributes"
		scm_commit "Configure git repository for age file diff."
	fi

	git -C "${PREFIX}" config --local diff.age.binary true
	git -C "${PREFIX}" config --local diff.age.textconv \
	    "${AGE} -d -i ${IDENTITIES_FILE}"
}

cmd_help() {
	cmd_version
	printf '\n'
	cmd_usage '    '
}

cmd_init() {
	DECISION=default
	OVERWRITE=yes
	PARSE_ERROR=no
	SUBDIR=''

	while [ $# -ge 1 ]; do
		case "$1" in
		    -i|--interactive)
			[ "${DECISION}" = default ] || PARSE_ERROR=yes
			DECISION=interactive
			shift ;;

		    -k|--keep)
			[ "${DECISION}" = default ] || PARSE_ERROR=yes
			DECISION=keep
			shift ;;

		    -p|--path)
			if [ $# -lt 2 ]; then
				PARSE_ERROR=yes
				break
			fi

			SUBDIR="$2"
			shift 2 ;;

		    -p?*)
			SUBDIR="${1#-p}"
			shift ;;

		    --path=*)
			SUBDIR="${1#--path=}"
			shift ;;

		    -[ik]?*)
			REST="${1#-?}"
			ARG="${1%"${REST}"}"
			shift
			set -- "${ARG}" "-${REST}" "$@"
			unset ARG
			unset REST
			;;

		    --)
			shift
			break ;;

		    -*)
			PARSE_ERROR=yes
			break ;;

		    *)
			break ;;
		esac
	done

	if [ "${PARSE_ERROR}" = yes ] || [ $# -eq 0 ]; then
		cmd_usage 'Usage: ' init >&2
		exit 1
	fi

	check_sneaky_path "${SUBDIR}"

	if [ $# -eq 1 ] && [ -z "$1" ]; then
		do_deinit "${SUBDIR}"
	else
		do_init "${SUBDIR}" "$@"
	fi

	unset PARSE_ERROR
	unset SUBDIR
}

cmd_insert() {
	ECHO=no
	MULTILINE=no
	OVERWRITE=no
	PARSE_ERROR=no

	while [ $# -ge 1 ]; do
		case "$1" in
		    -e|--echo)
			ECHO=yes
			shift ;;
		    -f|--force)
			OVERWRITE=yes
			shift ;;
		    -m|--multiline)
			MULTILINE=yes
			shift ;;
		    -[efm]?*)
			REST="${1#-?}"
			ARG="${1%"${REST}"}"
			shift
			set -- "${ARG}" "-${REST}" "$@"
			unset ARG
			unset REST
			;;
		    --)
			shift
			break ;;
		    -?*)
			PARSE_ERROR=yes
			break ;;
		    *)
			break ;;
		esac
	done

	if [ "${PARSE_ERROR}" = yes ] \
            || [ $# -lt 1 ] \
            || [ "${ECHO}${MULTILINE}" = yesyes ]
	then
		cmd_usage 'Usage: ' insert >&2
		exit 1
	fi
	unset PARSE_ERROR

	check_sneaky_paths "$@"

	for ARG in "$@"; do
		do_insert "${ARG}"
	done
	unset ARG
}

cmd_list_or_show() {
	PARSE_ERROR=no
	SELECTED_LINE=1
	USE_CLIP=no
	USE_QRCODE=no

	while [ $# -ge 1 ]; do
		case "$1" in
		    -c|--clip)
			USE_CLIP=yes
			shift ;;
		    -c?*)
			SELECTED_LINE="${1#-c}"
			USE_CLIP=yes
			shift ;;
		    --clip=*)
			SELECTED_LINE="${1#--clip=}"
			USE_CLIP=yes
			shift ;;
		    -q|--qrcode)
			USE_QRCODE=yes
			shift ;;
		    -q?*)
			SELECTED_LINE="${1#-q}"
			USE_QRCODE=yes
			shift ;;
		    --qrcode=*)
			SELECTED_LINE="${1#--qrcode=}"
			USE_QRCODE=yes
			shift ;;
		    --)
			shift
			break ;;
		    -*)
			PARSE_ERROR=yes
			break ;;
		    *)
			break ;;
		esac
	done

	case "${USE_CLIP}-${USE_QRCODE}" in
	    no-no)
		SHOW=text
		;;
	    yes-no)
		SHOW=clip
		;;
	    no-yes)
		SHOW=qrcode
		;;
	    *)
		PARSE_ERROR=yes
		;;
	esac

	if [ "${PARSE_ERROR}" = yes ]; then
		if [ "${COMMAND}" = "l${COMMAND#l}" ]; then
			cmd_usage 'Usage: ' list >&2
			exit 1
		elif [ "${COMMAND}" = "s${COMMAND#s}" ]; then
			cmd_usage 'Usage: ' show >&2
			exit 1
		else
			cmd_usage 'Usage: ' list show >&2
			exit 1
		fi
	fi
	unset PARSE_ERROR

	check_sneaky_paths "$@"

	if [ $# -eq 0 ]; then
		do_list_or_show ""
	else
		for ARG in "$@"; do
			do_list_or_show "${ARG}"
		done
	fi

	unset ARG
	unset PARSING
}

cmd_move() {
	ACTION=Move
	SCM_ACTION=scm_mv
	cmd_copy_move "$@"
}

cmd_random() {
	if [ $# -gt 2 ]; then
		cmd_usage 'Usage: ' random >&2
		exit 1
	fi

	random_chars "${1:-${GENERATED_LENGTH}}" "${2:-${CHARACTER_SET}}"
}

cmd_reencrypt() {
	DECISION=default
	OVERWRITE=yes
	PARSE_ERROR=no

	while [ $# -ge 1 ]; do
		case "$1" in
		    -i|--interactive)
			DECISION=interactive
			shift ;;
		    --)
			shift
			break ;;
		    -*)
			PARSE_ERROR=yes
			break ;;
		    *)
			break ;;
		esac
	done

	if [ "${PARSE_ERROR}" = yes ] || [ $# -eq 0 ]; then
		cmd_usage 'Usage: ' reencrypt >&2
		exit 1
	fi

	unset PARSE_ERROR

	check_sneaky_paths "$@"

	for ARG in "$@"; do
		do_reencrypt "${ARG}"
	done
	unset ARG
}

# Outputs the whole usage text
#   $1: indentation
#   ... commands to document
cmd_usage(){
	if [ $# -eq 0 ]; then
		F='    '
		I='    '
	else
		F="$1"
		NON_BLANK="$1"
		I=''
		while [ -n "${NON_BLANK}" ]; do
			I=" ${I}"
			NON_BLANK="${NON_BLANK#?}"
		done
		shift
	fi

	if [ $# -eq 0 ]; then
		echo 'Usage:'
		set -- list show copy delete edit find generate git gitconfig \
		    grep help init insert move random reencrypt version
		VERBOSE=yes
	else
		VERBOSE=no
	fi

	NON_BLANK="${PROGRAM}"
	BLANKPG=''
	while [ -n "${NON_BLANK}" ]; do
		BLANKPG=" ${BLANKPG}"
		NON_BLANK="${NON_BLANK#?}"
	done
	unset NON_BLANK

	for ARG in "$@"; do
		case "${ARG}" in
		    list)
			cat <<EOF
${F}${PROGRAM} [list] [subfolder]
EOF
			[ "${VERBOSE}" = yes ] && cat <<EOF
${I}    List passwords.
EOF
			;;
		    show)
			cat <<EOF
${F}${PROGRAM} [show] [--clip[=line-number],-c[line-number] |
${I}${BLANKPG}         --qrcode[=line-number],-q[line-number]] pass-name
EOF
			[ "${VERBOSE}" = yes ] && cat <<EOF
${I}    Show existing password and optionally put it on the clipboard
${I}    or display it as a QR-code.
${I}    If put on the clipboard, it will be cleared in ${CLIP_TIME:-45} seconds.
EOF
			;;
		    copy)
			cat <<EOF
${F}${PROGRAM} copy [--reencrypt,-e | --interactive,-i | --keep,-k ]
${I}${BLANKPG}      [--force,-f] old-path new-path
EOF
			[ "${VERBOSE}" = yes ] && cat <<EOF
${I}    Copies old-path to new-path, optionally forcefully,
${I}    reencrypting if needed or forced.
EOF
			;;
		    delete)
			cat <<EOF
${F}${PROGRAM} delete [--recursive,-r] [--force,-f] pass-name
EOF
			[ "${VERBOSE}" = yes ] && cat <<EOF
${I}    Remove existing passwords or directories, optionally forcefully.
EOF
			;;
		    edit)
			cat <<EOF
${F}${PROGRAM} edit pass-name
EOF
			[ "${VERBOSE}" = yes ] && cat <<EOF
${I}    Insert a new password or edit an existing password using an editor.
EOF
			;;
		    find)
			cat <<EOF
${F}${PROGRAM} find [GREP_OPTIONS] regex
EOF
			[ "${VERBOSE}" = yes ] && cat <<EOF
${I}    List passwords that match the given regex.
EOF
			;;
		    generate)
			cat <<EOF
${F}${PROGRAM} generate [--no-symbols,-n] [--clip,-c | --qrcode,-q]
${I}${BLANKPG}          [--in-place,-i | --force,-f] [--multiline,-m]
${I}${BLANKPG}          [--try,-t] pass-name [pass-length [character-set]]
EOF
			[ "${VERBOSE}" = yes ] && cat <<EOF
${I}    Generate a new password of pass-length (or ${GENERATED_LENGTH:-25} if unspecified)
${I}    with optionally no symbols.
${I}    Optionally put it on the clipboard and clear board after ${CLIP_TIME:-45} seconds
${I}    or display it as a QR-code.
${I}    Prompt before overwriting existing password unless forced.
${I}    Optionally replace only the first line of an existing file
${I}    with a new password.
${I}    Optionally prompt for confirmation between generation and saving.
EOF
			;;
		    git)
			cat <<EOF
${F}${PROGRAM} git git-command-args ...
EOF
			[ "${VERBOSE}" = yes ] && cat <<EOF
${I}    If the password store is a git repository, execute a git command
${I}    specified by git-command-args.
EOF
			;;
		    gitconfig)
			cat <<EOF
${F}${PROGRAM} gitconfig
EOF
			[ "${VERBOSE}" = yes ] && cat <<EOF
${I}    If the password store is a git repository, enforce local configuration.
EOF
			;;
		    grep)
			cat <<EOF
${F}${PROGRAM} grep [GREP_OPTIONS] search-regex
EOF
			[ "${VERBOSE}" = yes ] && cat <<EOF
${I}    Search for password files matching search-regex when decrypted.
EOF
			;;
		    help)
			cat <<EOF
${F}${PROGRAM} help
EOF
			[ "${VERBOSE}" = yes ] && cat <<EOF
${I}    Show this text.
EOF
			;;
		    init)
			cat <<EOF
${F}${PROGRAM} init [--interactive,-i | --keep,-k ]
${I}${BLANKPG}      [--path=subfolder,-p subfolder] age-recipient ...
EOF
			[ "${VERBOSE}" = yes ] && cat <<EOF
${I}    Initialize new password storage and use the given age recipients
${I}    for encryption.
${I}    Selectively reencrypt existing passwords using new recipients.
EOF
			;;
		    insert)
			cat <<EOF
${F}${PROGRAM} insert [--echo,-e | --multiline,-m] [--force,-f] pass-name
EOF
			[ "${VERBOSE}" = yes ] && cat <<EOF
${I}    Insert new password. Optionally, echo the password back to the console
${I}    during entry. Or, optionally, the entry may be multiline.
${I}    Prompt before overwriting existing password unless forced.
EOF
			;;
		    move)
			cat <<EOF
${F}${PROGRAM} move [--reencrypt,-e | --interactive,-i | --keep,-k ]
${I}${BLANKPG}      [--force,-f] old-path new-path
EOF
			[ "${VERBOSE}" = yes ] && cat <<EOF
${I}    Renames or moves old-path to new-path, optionally forcefully,
${I}    reencrypting if needed or forced.
EOF
			;;
		    random)
			cat <<EOF
${F}${PROGRAM} random [pass-length [character-set]]
EOF
			[ "${VERBOSE}" = yes ] && cat <<EOF
${I}    Generate a new password of pass-length (or ${GENERATED_LENGTH:-25} if unspecified)
${I}    using the given character set (or ${CHARACTER_SET} if unspecified)
${I}    without recording it in the password store.
EOF
			;;
		    reencrypt)
			cat <<EOF
${F}${PROGRAM} reencrypt [--interactive,-i] pass-name|subfolder ...
EOF
			[ "${VERBOSE}" = yes ] && cat <<EOF
${I}    Re-encrypt in-place a secret or all the secrets in a subfolder,
${I}    optionally asking before each one.
EOF
			;;
		    version)
			cat <<EOF
${F}${PROGRAM} version
EOF
			[ "${VERBOSE}" = yes ] && cat <<EOF
${I}    Show version information.
EOF
			;;
		    *)
			die "cmd_usage: unknown command \"${ARG}\""
			;;
		esac

		F="${I}"
	done
}

cmd_version() {
	cat <<-EOF
	==============================================
	= pashage: age-backed POSIX password manager =
	=                                            =
	=                   v0.1.0                   =
	=                                            =
	=            Natasha Kerensikova             =
	=                                            =
	=                 Based on:                  =
	=   password-store  by Jason A. Donenfeld    =
	=          passage  by Filippo Valsorda      =
	=             pash  by Dylan Araps           =
	==============================================
	EOF
}
