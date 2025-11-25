# completion file for bash

# Copyright (C) 2025  Natasha Kerensikova, based on password-store completion:
# Copyright (C) 2012 - 2014 Jason A. Donenfeld <Jason@zx2c4.com> and
# Brian Mattern <rephorm@rephorm.com>. All Rights Reserved.
# This file is licensed under the GPLv2+. Please see COPYING for more information.

_pashage_complete_entries () {
	local prefix="${PASHAGE_DIR:-${PASSAGE_DIR:-${PASSWORD_STORE_DIR:-${HOME}/.passage/store}}}"
	prefix="${prefix%/}/"
	local suffix=".age"
	local autoexpand=${1:-0}

	local IFS=$'\n'
	local items=($(compgen -f $prefix$cur))

	# Remember the value of the first item, to see if it is a directory. If
	# it is a directory, then don't add a space to the completion
	local firstitem=""
	# Use counter, can't use ${#items[@]} as we skip hidden directories
	local i=0 item

	for item in ${items[@]}; do
		[[ $item =~ /\.[^/]*$ ]] && continue

		# if there is a unique match, and it is a directory with one entry
		# autocomplete the subentry as well (recursively)
		if [[ ${#items[@]} -eq 1 && $autoexpand -eq 1 ]]; then
			while [[ -d $item ]]; do
				local subitems=($(compgen -f "$item/"))
				local filtereditems=( ) item2
				for item2 in "${subitems[@]}"; do
					[[ $item2 =~ /\.[^/]*$ ]] && continue
					filtereditems+=( "$item2" )
				done
				if [[ ${#filtereditems[@]} -eq 1 ]]; then
					item="${filtereditems[0]}"
				else
					break
				fi
			done
		fi

		# append / to directories
		[[ -d $item ]] && item="$item/"

		item="${item%$suffix}"
		COMPREPLY+=("${item#$prefix}")
		if [[ $i -eq 0 ]]; then
			firstitem=$item
		fi
		let i+=1
	done

	# The only time we want to add a space to the end is if there is only
	# one match, and it is not a directory
	if [[ $i -gt 1 || ( $i -eq 1 && -d $firstitem ) ]]; then
		compopt -o nospace
	fi
}

_pashage_complete_folders () {
	local prefix="${PASHAGE_DIR:-${PASSAGE_DIR:-${PASSWORD_STORE_DIR:-${HOME}/.passage/store}}}"
	prefix="${prefix%/}/"

	local IFS=$'\n'
	local items=($(compgen -d $prefix$cur))
	for item in ${items[@]}; do
		[[ $item == $prefix.* ]] && continue
		COMPREPLY+=("${item#$prefix}/")
	done
}

_pashage()
{
	COMPREPLY=()
	local cur="${COMP_WORDS[COMP_CWORD]}"
	local commands="copy cp delete edit find generate git gitconfig grep help init insert list ls move mv random re-encrypt reencrypt remove rm show version"
	if [[ $COMP_CWORD -gt 1 ]]; then
		local lastarg="${COMP_WORDS[$COMP_CWORD-1]}"
		case "${COMP_WORDS[1]}" in
			init)
				if [[ $lastarg == "-p" || $lastarg == "--path" ]]; then
					_pashage_complete_folders
					compopt -o nospace
				else
					COMPREPLY+=($(compgen -W "-i --interactive -k --keep -p --path" -- ${cur}))
				fi
				;;
			ls|list|edit)
				_pashage_complete_entries
				;;
			show|-*)
				COMPREPLY+=($(compgen -W "-c --clip -q --qrcode" -- ${cur}))
				_pashage_complete_entries 1
				;;
			insert)
				COMPREPLY+=($(compgen -W "-e --echo -m --multiline -f --force" -- ${cur}))
				_pashage_complete_entries
				;;
			generate)
				COMPREPLY+=($(compgen -W "-n --no-symbols -c --clip -f --force -i --in-place -m --multiline -q --qrcode -t --try" -- ${cur}))
				_pashage_complete_entries
				;;
			cp|copy|move|mv|rename)
				COMPREPLY+=($(compgen -W "-f --force -e --reencrypt -i --interactive -k --keep" -- ${cur}))
				_pashage_complete_entries
				;;
			rm|remove|delete)
				COMPREPLY+=($(compgen -W "-r --recursive -f --force" -- ${cur}))
				_pashage_complete_entries
				;;
			re-encrypt|reencrypt)
				COMPREPLY+=($(compgen -W "-d --deep -i --interactive" -- ${cur}))
				_pashage_complete_entries
				;;
			git)
				COMPREPLY+=($(compgen -W "init push pull config log reflog rebase" -- ${cur}))
				;;
		esac
	else
		COMPREPLY+=($(compgen -W "${commands}" -- ${cur}))
		_pashage_complete_entries 1
	fi
}

complete -o filenames -F _pashage pashage
