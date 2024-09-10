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

PLATFORM != uname | cut -d _ -f 1 | tr '[:upper:]' '[:lower:]'

pashage: bin/pashage-$(PLATFORM).sh
	cp -i "$>" "$@"

.PHONY: all check clean cov tests validate

all: bin/pashage-freebsd.sh

check: bin/pashage-freebsd.sh
	shellcheck -o all $>

clean:
	rm -rf pashage bin/

cov:
	shellspec --kcov -s bash

tests:
	shellspec

validate: check tests cov

bin/pashage-freebsd.sh: src/platform-freebsd.sh src/pashage.sh src/run.sh
	mkdir -p bin
	sed '1{;x;d;};/^###########$$/{;x;q;};x' src/run.sh >|"$@"
	sed '1,/^$$/d' src/platform-freebsd.sh >>"$@"
	echo >>"$@"
	sed '1,/^$$/d' src/pashage.sh >>"$@"
	echo >>"$@"
	echo '############' >>"$@"
	sed '1,/^############$$/d' src/run.sh >>"$@"
