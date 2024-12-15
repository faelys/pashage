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

##########################
# PLATFORM-SPECIFIC CODE #
##########################

# Decode base-64 standard input into binary standard output
platform_b64_decode() {
	openssl base64 -d
}

# Encode binary standard input into base-64 standard output
platform_b64_encode() {
	openssl base64
}

# Temporarily paste standard input into clipboard
#   $1:  title
platform_clip() {
	[ -n "${SECURE_TMPDIR-}" ] && die "Unexpected collision on trap EXIT"
	CLIP_BACKUP="$(platform_clip_paste | platform_b64_encode)"
	platform_clip_copy
	trap 'printf '\''%s\n'\'' "${CLIP_BACKUP}" | platform_b64_decode | platform_clip_copy' EXIT
	printf '%s\n' \
	    "Copied $1 to clipboard. Will clear in ${CLIP_TIME} seconds."
	echo "Use Ctrl-C to clear the clipboard earlier."
	sleep "${CLIP_TIME}"
	printf '%s\n' "${CLIP_BACKUP}" | platform_b64_decode \
	    | platform_clip_copy
	trap - EXIT
	unset CLIP_BACKUP
}

# Copy standard input into clipboard
platform_clip_copy() {
	if [ -n "${WAYLAND_DISPLAY-}" ] && type wl-copy >/dev/null 2>&1; then
		checked wl-copy 2>/deb/null
	elif [ -n "${DISPLAY-}" ] && type xclip >/dev/null 2>&1; then
		checked xclip -selection "${X_SELECTION}"
	else
		die "Error: No X11 or Wayland display detected"
	fi
}

# Paste clipboard into standard output, ignoring failures
platform_clip_paste() {
	if [ -n "${WAYLAND_DISPLAY-}" ] && type wl-paste >/dev/null 2>&1; then
		wl-paste -n 2>/deb/null || true
	elif [ -n "${DISPLAY-}" ] && type xclip >/dev/null 2>&1; then
		xclip -o -selection "${X_SELECTION}" || true
	else
		die "Error: No X11 or Wayland display detected"
	fi
}

# Display standard input as a QR-code
#   $1: title
platform_qrcode() {
	type qrencode >/dev/null 2>&1 || die "qrencode is not available"

	if [ -n "${DISPLAY-}" ] || [ -n "${WAYLAND_DISPLAY-}" ]; then
		if type feh >/dev/null 2>&1; then
			checked qrencode --size 10 -o - \
			    | checked feh -x --title "pashage: $1" \
			                  -g +200+200 -
			return 0
		elif type gm >/dev/null 2>&1; then
			checked qrencode --size 10 -o - \
			    | checked gm display --title "pashage: $1" \
			                  -g +200+200 -
			return 0
		elif type display >/dev/null 2>&1; then
			checked qrencode --size 10 -o - \
			    | checked display --title "pashage: $1" \
			                  -g +200+200 -
			return 0
		fi
	fi

	qrencode -t utf8
}

# Create a (somewhat) secuture emporary directory
platform_tmpdir() {
	[ -n "${SECURE_TMPDIR-}" ] && return 0
	TEMPLATE="${PROGRAM##*/}.XXXXXXXXXXXXX"
	if [ -d /dev/shm ] \
	    && [ -w /dev/shm ] \
	    && [ -x /dev/shm ]
	then
		SECURE_TMPDIR="$(mktemp -d "/dev/shm/${TEMPLATE}")"
		trap platform_tmpdir_rm EXIT
	else
		SECURE_TMPDIR="$(mktemp -d "${TMPDIR:-/tmp}/${TEMPLATE}")"
		trap platform_tmpdir_shred EXIT
	fi
	unset TEMPLATE
}

# Remove a ramdisk-based tmpdir
platform_tmpdir_rm() {
	[ -z "${SECURE_TMPDIR-}" ] && return 0
	rm -rf -- "${SECURE_TMPDIR}"
	unset SECURE_TMPDIR
}

# Remove a presumed disk-based tmpdir
platform_tmpdir_shred() {
	[ -z "${SECURE_TMPDIR-}" ] && return 0
	find -f "${SECURE_TMPDIR}" -- -type f -exec rm -P -f '{}' +
	rm -rf -- "${SECURE_TMPDIR}"
	unset SECURE_TMPDIR
}
