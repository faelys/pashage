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

# This test file should pass with pashage, pass (the original password-store),
# or passage (the pass fork by Filippo Valsorda).

# The test suite also checks the internal of the store, thanks to mocked
# cryptography. This should ensure that pashage is indeed a drop-in replacement
# for passage, and that both of them can update interchangeably the same
# password store repository.

# The other password-store scripts can be added to the parameters list
# to run the cases against it.
# bash seems to escape the sandbox by resetting PATH on the slightest
# provocation, while the tests rely heavily on the mocked cryptography
# to check the store behavior.
# So it only works when using shellspec with bash and calling the `pass`
# or `password-store.sh` script directly
# (e.g. on FreeBSD `/usr/local/libexec/password-store/pass`
# instead of `/usr/local/bin/pass`).

Parameters # script/path           scriptname  encryption
# /usr/bin/pass                      pass         gpg
# /git/passage/src/password-store.sh passage      age
  ./src/run.sh                       pashage      age
End

Describe 'Pass-like command'
  check_skip() {
    [ -z "${1%%pass*}" ] && ! [ "${SHELLSPEC_SHELL_TYPE}" = bash ]
  }

  GITLOG="${SHELLSPEC_WORKDIR}/git-log.txt"
  PREFIX="${SHELLSPEC_WORKDIR}/store"

  export PASSWORD_STORE_DIR="${PREFIX}"
  export PASSAGE_DIR="${PREFIX}"
  export PASSAGE_IDENTITIES_FILE="${SHELLSPEC_WORKDIR}/age-identities"

  git_log() {
    @git -C "${PREFIX}" status --porcelain >&2
    @git -C "${PREFIX}" log --format='%s' --stat >|"${GITLOG}"
  }

  setup_log() { %text
    #|Initial setup
    #|
    #| -g.age                 | 2 ++
    #| -g.gpg                 | 2 ++
    #| .gpg-id                | 1 +
    #| extra.age              | 2 ++
    #| extra.gpg              | 2 ++
    #| extra/subdir/file.age  | 2 ++
    #| extra/subdir/file.gpg  | 2 ++
    #| fluff/.age-recipients  | 2 ++
    #| fluff/.gpg-id          | 2 ++
    #| fluff/one.age          | 3 +++
    #| fluff/one.gpg          | 3 +++
    #| fluff/three.age        | 5 +++++
    #| fluff/three.gpg        | 5 +++++
    #| fluff/two.age          | 4 ++++
    #| fluff/two.gpg          | 4 ++++
    #| shared/.age-recipients | 2 ++
    #| shared/.gpg-id         | 2 ++
    #| stale.age              | 3 +++
    #| stale.gpg              | 3 +++
    #| subdir/file.age        | 2 ++
    #| subdir/file.gpg        | 2 ++
    #| y.txt                  | 3 +++
    #| 22 files changed, 58 insertions(+)
  }

  setup_id() {
    @mkdir -p "${PREFIX}/$1"
    @cat >"${PREFIX}/$1/.age-recipients"
    @cp -i "${PREFIX}/$1/.age-recipients" "${PREFIX}/$1/.gpg-id"
  }

  setup_secret() {
    [ "$1" = "${1%/*}" ] || @mkdir -p "${PREFIX}/${1%/*}"
    @sed 's/^/age/' >"${PREFIX}/$1.age"
    @sed 's/^age/gpg/' "${PREFIX}/$1.age" >"${PREFIX}/$1.gpg"
  }

  setup() {
    @git init -q -b main "${PREFIX}"
    @git -C "${PREFIX}" config --local user.name 'Test User'
    @git -C "${PREFIX}" config --local user.email 'test@example.com'
    %putsn 'myself' >"${PASSAGE_IDENTITIES_FILE}"
    %putsn 'myself' >"${PREFIX}/.gpg-id"
    %text | setup_secret 'subdir/file'
    #|Recipient:myself
    #|:p4ssw0rd
    %text | setup_secret 'extra'
    #|Recipient:myself
    #|:ambiguous
    %text | setup_secret 'extra/subdir/file'
    #|Recipient:myself
    #|:Pa55worD
    %text | setup_id 'shared'
    #|myself
    #|friend
    %text | setup_id 'fluff'
    #|master
    #|myself
    %text | setup_secret 'fluff/one'
    #|Recipient:master
    #|Recipient:myself
    #|:1-password
    %text | setup_secret 'fluff/two'
    #|Recipient:master
    #|Recipient:myself
    #|:2-password
    #|:URL: https://example.com/login
    %text | setup_secret 'fluff/three'
    #|Recipient:master
    #|Recipient:myself
    #|:3-password
    #|:Username: 3Jane
    #|:URL: https://example.com/login
    %text | setup_secret 'stale'
    #|Recipient:master
    #|Recipient:myself
    #|:0-password
    %text | setup_secret '-g'
    #|Recipient:myself
    #|:--
    %text >"${PREFIX}/y.txt"
    #|Unencrypted line 1
    #|Unencrypted line 2
    #|Unencrypted line 3
    @git -C "${PREFIX}" add .
    @git -C "${PREFIX}" commit -m 'Initial setup' >/dev/null

    # Check setup_log consistency
    git_log
    setup_log | @diff -u - "${GITLOG}"
  }

  cleanup() {
    @rm -rf "${PREFIX}"
    @rm -f "${PASSAGE_IDENTITIES_FILE}"
  }

  BeforeEach setup
  AfterEach cleanup

  Mock age
    mock-age "$@"
  End

  Mock base64
    . "${SHELLSPEC_SUPPORT_BIN}"
    invoke base64 "$@"
  End

  Mock basename
    @basename "$@"
  End

  Mock cat
    @cat "$@"
  End

  Mock cp
    @cp "$@"
  End

  Mock cut
    . "${SHELLSPEC_SUPPORT_BIN}"
    invoke cut "$@"
  End

  Mock dd
    . "${SHELLSPEC_SUPPORT_BIN}"
    invoke dd "$@"
  End

  Mock diff
    @diff "$@"
  End

  Mock dirname
    @dirname "$@"
  End

  Mock ed
    . "${SHELLSPEC_SUPPORT_BIN}"
    if [ "${1-}" = '-c' ]; then
      shift
      invoke touch "$@"
    fi
    invoke ed "$@"
  End

  Mock feh
    printf '$ feh %s\n' "$*" >&2
    @cat >&2
  End

  Mock find
    . "${SHELLSPEC_SUPPORT_BIN}"
    invoke find "$@"
  End

  Mock git
    @git "$@"
  End

  Mock gpg
    mock-gpg "$@"
  End

  Mock grep
    @grep "$@"
  End

  Mock head
    @head "$@"
  End

  Mock mkdir
    @mkdir "$@"
  End

  Mock mv
    @mv "$@"
  End

  Mock openssl
    . "${SHELLSPEC_SUPPORT_BIN}"
    invoke openssl "$@"
  End

  Mock qrencode
    . "${SHELLSPEC_SUPPORT_BIN}"
    invoke od -v -t x1 | sed 's/  */ /g;s/ *$//'
  End

  Mock mktemp
    . "${SHELLSPEC_SUPPORT_BIN}"
    invoke mktemp "$@"
  End

  Mock rm
    @rm "$@"
  End

  Mock rmdir
    . "${SHELLSPEC_SUPPORT_BIN}"
    invoke rmdir "$@"
  End

  Mock sed
    @sed "$@"
  End

  Mock sleep
    :
  End

  Mock sort
    . "${SHELLSPEC_SUPPORT_BIN}"
    invoke sort "$@"
  End

  Mock tail
    @tail "$@"
  End

  Mock tr
    @tr "$@"
  End

  Mock tree
    . "${SHELLSPEC_SUPPORT_BIN}"
    invoke tree "$@"
  End

  Mock uname
    @uname "$@"
  End

  Mock which
    false
  End

  Mock xclip
    . "${SHELLSPEC_SUPPORT_BIN}"
    if [ "$1" = '-o' ]; then
      printf 'previous contents\n'
    else
      printf '$ xclip %s\n' "$*" >&2
      invoke od -v -t x1 | sed 's/  */ /g;s/ *$//' >&2
    fi
  End

  Describe 'init'
    It 're-encrypts the whole store using a new recipient id'
      Skip if 'pass(age) needs bash' check_skip $2
      Skip if 'passage has no init' [ "$2" = passage ]
      When run script $1 init 'new-id'
      The status should be success
      The output should include 'Password store'
      expected_log() {
        if [ "$2" = pashage ]; then
          %text
          #|Set age recipients at store root
          #|
          #| -g.age                | 2 +-
          #| .age-recipients       | 1 +
          #| extra.age             | 2 +-
          #| extra/subdir/file.age | 2 +-
          #| stale.age             | 3 +--
          #| subdir/file.age       | 2 +-
          #| 6 files changed, 6 insertions(+), 6 deletions(-)
        else
          %text:expand
          #|Reencrypt password store using new GPG id new-id.
          #|
          #| -g.$1                | 2 +-
          #| extra.$1             | 2 +-
          #| extra/subdir/file.$1 | 2 +-
          #| stale.$1             | 3 +--
          #| subdir/file.$1       | 2 +-
          #| 5 files changed, 5 insertions(+), 6 deletions(-)
          #|Set GPG id to new-id.
          #|
          #| .gpg-id | 2 +-
          #| 1 file changed, 1 insertion(+), 1 deletion(-)
        fi
        setup_log
      }
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(expected_log $3 $2)"
    End

    It 're-encrypts a subdirectory using a new recipient id'
      Skip if 'pass(age) needs bash' check_skip $2
      Skip if 'passage has no init' [ "$2" = passage ]
      When run script $1 init -p subdir 'new-id'
      The status should be success
      The output should start with 'Password store'
      The output should include 'subdir'
      expected_log() {
        if [ "$2" = pashage ]; then
          %text
          #|Set age recipients at subdir
          #|
          #| subdir/.age-recipients | 1 +
          #| subdir/file.age        | 2 +-
          #| 2 files changed, 2 insertions(+), 1 deletion(-)
        else
          %text:expand
          #|Reencrypt password store using new GPG id new-id (subdir).
          #|
          #| subdir/file.$1 | 2 +-
          #| 1 file changed, 1 insertion(+), 1 deletion(-)
          #|Set GPG id to new-id (subdir).
          #|
          #| subdir/.gpg-id | 1 +
          #| 1 file changed, 1 insertion(+)
        fi
        setup_log
      }
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(expected_log $3 $2)"
    End

    It 're-encrypts a subdirectory after replacing recipient ids'
      Skip if 'pass(age) needs bash' check_skip $2
      Skip if 'passage has no init' [ "$2" = passage ]
      When run script $1 init -p fluff 'new-id' 'new-master'
      The status should be success
      The output should start with 'Password store'
      The output should include 'fluff'
      expected_log() {
        if [ "$2" = pashage ]; then
          %text
          #|Set age recipients at fluff
          #|
          #| fluff/.age-recipients | 4 ++--
          #| fluff/one.age         | 4 ++--
          #| fluff/three.age       | 4 ++--
          #| fluff/two.age         | 4 ++--
          #| 4 files changed, 8 insertions(+), 8 deletions(-)
        else
          %text:expand
          #|Reencrypt password store using new GPG id new-id, new-master (fluff).
          #|
          #| fluff/one.$1   | 4 ++--
          #| fluff/three.$1 | 4 ++--
          #| fluff/two.$1   | 4 ++--
          #| 3 files changed, 6 insertions(+), 6 deletions(-)
          #|Set GPG id to new-id, new-master (fluff).
          #|
          #| fluff/.gpg-id | 4 ++--
          #| 1 file changed, 2 insertions(+), 2 deletions(-)
        fi
        setup_log
      }
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(expected_log $3 $2)"
    End

    It 're-encrypts a subdirectory after removing dedicated recipient ids'
      Skip if 'pass(age) needs bash' check_skip $2
      Skip if 'passage has no init' [ "$2" = passage ]
      When run script $1 init -p fluff ''
      The status should be successful
      expected_log() {
        if [ "$2" = pashage ]; then
          %text
          #|Deinitialize fluff
          #|
          #| fluff/.age-recipients | 2 --
          #| fluff/one.age         | 1 -
          #| fluff/three.age       | 1 -
          #| fluff/two.age         | 1 -
          #| 4 files changed, 5 deletions(-)
        else
          %text:expand
          #|Reencrypt password store using new GPG id  (fluff).
          #|
          #| fluff/one.$1   | 1 -
          #| fluff/three.$1 | 1 -
          #| fluff/two.$1   | 1 -
          #| 3 files changed, 3 deletions(-)
          #|Deinitialize ${PREFIX}/fluff/.gpg-id (fluff).
          #|
          #| fluff/.gpg-id | 2 --
          #| 1 file changed, 2 deletions(-)
        fi
        setup_log
      }
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(expected_log $3 $2)"
    End

    It 'creates a new subdirectory with recipient ids'
      Skip if 'pass(age) needs bash' check_skip $2
      Skip if 'passage has no init' [ "$2" = passage ]
      When run script $1 init -p newdir new-id new-master
      The status should be successful
      The output should include 'newdir'
      The directory "${PREFIX}/newdir" should be exist
      expected_log() {
        if [ "$2" = pashage ]; then
          %text
          #|Set age recipients at newdir
          #|
          #| newdir/.age-recipients | 2 ++
          #| 1 file changed, 2 insertions(+)
        else
          %text:expand
          #|Set GPG id to new-id, new-master (newdir).
          #|
          #| newdir/.gpg-id | 2 ++
          #| 1 file changed, 2 insertions(+)
        fi
        setup_log
      }
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(expected_log $3 $2)"
    End

    It 'does not create a new subdirectory without recipient id'
      Skip if 'pass(age) needs bash' check_skip $2
      Skip if 'passage has no init' [ "$2" = passage ]
      When run script $1 init -p newdir ''
      The status should be successful
      The output should be blank
      The error should include "newdir"
      The directory "${PREFIX}/newdir" should not be exist
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(setup_log)"
    End

    It 'displays usage when called without argument'
      Skip if 'pass(age) needs bash' check_skip $2
      Skip if 'passage has no init' [ "$2" = passage ]
      When run script $1 init
      The status should equal 1
      The output should be blank
      The error should include 'Usage:'
      The error should include ' init '
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(setup_log)"
    End

    It 'rejects a path containing ..'
      Skip if 'pass(age) needs bash' check_skip $2
      Skip if 'passage has no init' [ "$2" = passage ]
      When run script $1 init --path fluff/../newdir new-id
      The status should equal 1
      The output should be blank
      The error should include 'sneaky'
      The directory "${PREFIX}/newdir" should not be exist
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(setup_log)"
    End
  End

  Describe 'ls'
    It 'lists a directory'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 ls subdir
      The status should be success
      The line 1 of output should include 'subdir'
      The line 2 of output should include 'file'
    End

    It 'lists a directory implicitly'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 subdir
      The status should be success
      The line 1 of output should include 'subdir'
      The line 2 of output should include 'file'
    End

    It 'lists a directory when called as `show`'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 show subdir
      The status should be success
      The line 1 of output should include 'subdir'
      The line 2 of output should include 'file'
    End

    It 'lists the whole store without argument'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1
      The status should be success
      if [ $2 = passage ]; then
        The line 1 of output should equal 'Passage'
      else
        The line 1 of output should equal 'Password Store'
      fi
      The line  2 of output should include '-g'
      The line  3 of output should include '-g'
      The line  4 of output should include 'extra'
      The line  5 of output should include 'subdir'
      The line  6 of output should include 'file'
      The line  7 of output should include 'file'
      The line  8 of output should include 'extra'
      The line  9 of output should include 'extra'
      The line 10 of output should include 'fluff'
      The line 11 of output should include 'one'
      The line 12 of output should include 'one'
      The line 13 of output should include 'three'
      The line 14 of output should include 'three'
      The line 15 of output should include 'two'
      The line 16 of output should include 'two'
      The line 17 of output should include 'shared'
      The line 18 of output should include 'stale'
      The line 19 of output should include 'stale'
      The line 20 of output should include 'subdir'
      The line 21 of output should include 'file'
      The line 22 of output should include 'file'
      if [ $2 = pashage ]; then
        The lines of output should equal 22
      else
        The line 23 of output should include 'y.txt'
      fi
    End

    It 'does not list a file masquerading as a directory'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 subdir/file/
      The status should equal 1
      The error should equal 'Error: subdir/file/ is not in the password store.'
    End

    It 'lists a directory having an ambiguous name with `/` suffix'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 extra/
      The status should be success
      The line 1 of output should include 'extra'
      The line 2 of output should include 'subdir'
      The line 3 of output should include 'file'
      The line 4 of output should include 'file'
    End

    It 'fails to list a non-existent directory'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 non-existent/
      The status should equal 1
      The output should be blank
      The error should equal \
        'Error: non-existent/ is not in the password store.'
    End

    It 'fails to list a file masquerading as a directory'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 stale/
      The status should equal 1
      The output should be blank
      The error should equal 'Error: stale/ is not in the password store.'
    End

    It 'rejects a path containing ..'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 subdir/../fluff/
      The status should equal 1
      The output should be blank
      The error should include 'sneaky'
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(setup_log)"
    End
  End

  Describe 'find'
    It 'lists entries matching a substring'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 find o
      The status should be success
      The lines of output should equal 6
      The line 1 of output should match pattern 'Search *: o'
      The line 2 of output should include 'fluff'
      The line 3 of output should include 'one'
      The line 4 of output should include 'one'
      The line 5 of output should include 'two'
      The line 6 of output should include 'two'
    End

    It 'reports success even without match'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 find z
      The status should be success
      The lines of output should equal 1
      The line 1 of output should match pattern 'Search *: z'
      The error should be blank
    End

    It 'displays usage when called without argument'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 find
      The status should equal 1
      The output should be blank
      The error should include 'Usage:'
      The error should include ' find '
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(setup_log)"
    End
  End

  Describe 'show'
    It 'decrypts a password file'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 show subdir/file
      The status should be success
      The output should equal 'p4ssw0rd'
    End

    It 'decrypts a password file implicitly'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 subdir/file
      The status should be success
      The output should equal 'p4ssw0rd'
    End

    It 'fails to decrypt a flag'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 -g
      The status should equal 1
      The output should be blank
      The error should include 'Usage:'
    End

    It 'decrypts a password file named like a flag'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 -- -g
      The status should be success
      The output should equal '--'
    End

    It 'decrypts a password file even when called as `list`'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 ls subdir/file
      The status should be success
      The output should equal 'p4ssw0rd'
    End

    It 'decrypts a file having an ambiguous name without suffix'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 extra
      The status should be success
      The output should equal 'ambiguous'
    End

    It 'displays the password as a QR-code'
      DISPLAY=mock
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 -q fluff/one
      The status should be success
      expected_err() { %text:expand
        #|$ feh -x --title ${1}: fluff/one -g +200+200 -
        #|0000000 31 2d 70 61 73 73 77 6f 72 64
        #|0000012
      }
      if [ $2 = pashage ]; then
        The error should equal "$(expected_err 'pashage')"
      else
        The error should equal "$(expected_err 'pass')"
      fi
    End

    It 'displays the given line as a QR-code'
      DISPLAY=mock
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 --qrcode=2 fluff/three
      The status should be success
      expected_err() { %text:expand
        #|$ feh -x --title ${1}: fluff/three -g +200+200 -
        #|0000000 55 73 65 72 6e 61 6d 65 3a 20 33 4a 61 6e 65
        #|0000017
      }
      if [ $2 = pashage ]; then
        The error should equal "$(expected_err 'pashage')"
      else
        The error should equal "$(expected_err 'pass')"
      fi
    End

    It 'pastes into the clipboard'
      DISPLAY=mock
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 show -c fluff/three
      The status should be success
      The output should start with \
        'Copied fluff/three to clipboard. Will clear in 45 seconds.'
      expected_err() { %text
        #|$ xclip -selection clipboard
        #|0000000 33 2d 70 61 73 73 77 6f 72 64
        #|0000012
      }
      The error should start with "$(expected_err)"
    End

    It 'pastes a selected line into the clipboard'
      DISPLAY=mock
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 show -c2 fluff/three
      The status should be success
      The output should start with \
        'Copied fluff/three to clipboard. Will clear in 45 seconds.'
      expected_err() { %text
        #|$ xclip -selection clipboard
        #|0000000 55 73 65 72 6e 61 6d 65 3a 20 33 4a 61 6e 65
        #|0000017
      }
      The error should start with "$(expected_err)"
    End

    It 'fails to show a non-existent file'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 non-existent
      The status should equal 1
      The output should be blank
      The error should equal \
        'Error: non-existent is not in the password store.'
    End

    It 'does not show an unencrypted file in the store'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 show y.txt
      The status should equal 1
      The output should be blank
      The error should equal 'Error: y.txt is not in the password store.'
    End

    It 'rejects a path containing ..'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 subdir/../fluff/one
      The status should equal 1
      The output should be blank
      The error should include 'sneaky'
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(setup_log)"
    End
  End

  Describe 'grep'
    It 'shows decrypted lines matching a regex'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 grep -i Com
      The status should be success
      The lines of output should equal 4
      The line 1 of output should include 'fluff'
      The output should include 'three'
      The line 2 of output should include 'https://example.'
      The line 3 of output should include 'fluff'
      The output should include 'two'
      The line 4 of output should include 'https://example.'
    End

    It 'is successful even without match'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 grep nothing.matches
      The status should be success
      The output should be blank
    End

    It 'does not look into unencrypted files in the store'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 grep Unencrypted
      The status should be success
      The output should be blank
    End

    It 'displays usage when called without argument'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 grep
      The status should equal 1
      The output should be blank
      The error should include 'Usage:'
      The error should include ' grep '
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(setup_log)"
    End
  End

  Describe 'insert'
    It 'inserts a new multi-line entry'
      Skip if 'pass(age) needs bash' check_skip $2
      Data
        #|password
        #|Username: tester
        #|URL: https://example.com/login
      End
      When run script $1 insert -m rootpass
      The status should be success
      The output should include 'rootpass'
      The contents of file "${PREFIX}/rootpass.$3" \
        should include "$3:Username: tester"
      expected_log() { %text:expand
        #|Add given password for rootpass to store.
        #|
        #| rootpass.$1 | 4 ++++
        #| 1 file changed, 4 insertions(+)
        setup_log
      }
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(expected_log $3)"
    End

    It 'inserts a new single-line entry'
      Skip if 'pass(age) needs bash' check_skip $2
      Data
        #|pass-word
        #|pass-word
      End
      When run script $1 insert newdir/newpass
      The status should be success
      The output should include 'newdir/newpass'
      The contents of file "${PREFIX}/newdir/newpass.$3" \
        should include "$3:pass-word"
      expected_log() { %text:expand
        #|Add given password for newdir/newpass to store.
        #|
        #| newdir/newpass.$1 | 2 ++
        #| 1 file changed, 2 insertions(+)
        setup_log
      }
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(expected_log $3)"
    End

    It 'fails to insert an unescaped flag'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 insert -h
      The status should equal 1
      The output should be blank
      The error should include 'Usage:'
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(setup_log)"
    End

    It 'inserts a new single-line entry named like a flag'
      Skip if 'pass(age) needs bash' check_skip $2
      Data
        #|pass-word
        #|pass-word
      End
      When run script $1 insert -- -h
      The status should be success
      The output should include '-h'
      The contents of file "${PREFIX}/-h.$3" \
        should include "$3:pass-word"
      expected_log() { %text:expand
        #|Add given password for -h to store.
        #|
        #| -h.$1 | 2 ++
        #| 1 file changed, 2 insertions(+)
        setup_log
      }
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(expected_log $3)"
    End

    It 'inserts a new single-line entry with echo'
      Skip if 'pass(age) needs bash' check_skip $2
      Data "pass-word"
      When run script $1 insert -e newdir/newpass
      The status should be success
      The output should include 'newdir/newpass'
      The output should not include 'Retype'
      The contents of file "${PREFIX}/newdir/newpass.$3" \
        should include "$3:pass-word"
      expected_log() { %text:expand
        #|Add given password for newdir/newpass to store.
        #|
        #| newdir/newpass.$1 | 2 ++
        #| 1 file changed, 2 insertions(+)
        setup_log
      }
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(expected_log $3)"
    End

    It 'inserts an entry with local recipient list'
      Skip if 'pass(age) needs bash' check_skip $2
      Data "passWord"
      When run script $1 insert -e shared/newpass
      The status should be success
      The output should include 'shared/newpass'
      The contents of file "${PREFIX}/shared/newpass.$3" \
        should include 'friend'
      The contents of file "${PREFIX}/shared/newpass.$3" \
        should include 'myself'
      The contents of file "${PREFIX}/shared/newpass.$3" \
        should include "$3:passWord"
      expected_log() { %text:expand
        #|Add given password for shared/newpass to store.
        #|
        #| shared/newpass.$1 | 3 +++
        #| 1 file changed, 3 insertions(+)
        setup_log
      }
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(expected_log $3)"
    End

    It 'inserts forcefully over an existing single-line entry with echo'
      Skip if 'pass(age) needs bash' check_skip $2
      Data "pass-word"
      When run script $1 insert -e -f subdir/file
      The status should be success
      The output should include 'subdir/file'
      The output should not include 'Retype'
      The contents of file "${PREFIX}/subdir/file.$3" \
        should include "$3:pass-word"
      expected_log() { %text:expand
        #|Add given password for subdir/file to store.
        #|
        #| subdir/file.$1 | 2 +-
        #| 1 file changed, 1 insertion(+), 1 deletion(-)
        setup_log
      }
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(expected_log $3)"
    End

    It 'inserts an entry into a new directory'
      Skip if 'pass(age) needs bash' check_skip $2
      Data "drowssap"
      When run script $1 insert -e new-dir/newpass
      The status should be success
      The output should include 'new-dir/newpass'
      The contents of file "${PREFIX}/new-dir/newpass.$3" \
        should include 'myself'
      The contents of file "${PREFIX}/new-dir/newpass.$3" \
        should include "$3:drowssap"
      expected_log() { %text:expand
        #|Add given password for new-dir/newpass to store.
        #|
        #| new-dir/newpass.$1 | 2 ++
        #| 1 file changed, 2 insertions(+)
        setup_log
      }
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(expected_log $3)"
    End

    It 'displays usage when called without argument'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 insert
      The status should equal 1
      The output should be blank
      The error should include 'Usage:'
      The error should include ' insert '
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(setup_log)"
    End

    It 'rejects a path containing ..'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 insert -e fluff/../new-secret
      The status should equal 1
      The output should be blank
      The error should include 'sneaky'
      The file "${PREFIX}/new-secret.age" should not be exist
      The file "${PREFIX}/new-secret.gpg" should not be exist
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(setup_log)"
    End
  End

  Describe 'edit'
    EDITOR=ed
    TERM=dumb

    It 'creates a file using EDITOR'
      EDITOR='ed -c'
      Skip if 'pass(age) needs bash' check_skip $2
      Data
        #|a
        #|New password
        #|New annotation
        #|.
        #|wq
      End
      When run script $1 edit subdir/new
      The status should be success
      The file "${PREFIX}/subdir/new.$3" should be exist
      expected_file() { %text:expand
        #|$1Recipient:myself
        #|$1:New password
        #|$1:New annotation
      }
      The contents of file "${PREFIX}/subdir/new.$3" should \
        equal "$(expected_file "$3")"
      expected_log() { %text:expand
        #|Add password for subdir/new using ed -c.
        #|
        #| subdir/new.$1 | 3 +++
        #| 1 file changed, 3 insertions(+)
        setup_log
      }
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(expected_log $3)"
    End

    It 'creates a file in a new directory'
      EDITOR='ed -c'
      Skip if 'pass(age) needs bash' check_skip $2
      Data
        #|a
        #|p4ssword!
        #|.
        #|wq
      End
      When run script $1 edit new-subdir/new
      The status should be success
      The directory "${PREFIX}/new-subdir" should be exist
      The file "${PREFIX}/new-subdir/new.$3" should be exist
      expected_file() { %text:expand
        #|$1Recipient:myself
        #|$1:p4ssword!
      }
      The contents of file "${PREFIX}/new-subdir/new.$3" should \
        equal "$(expected_file "$3")"
      expected_log() { %text:expand
        #|Add password for new-subdir/new using ed -c.
        #|
        #| new-subdir/new.$1 | 2 ++
        #| 1 file changed, 2 insertions(+)
        setup_log
      }
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(expected_log $3)"
    End

    It 'creates a file named like a flag'
      EDITOR='ed -c'
      Skip if 'pass(age) needs bash' check_skip $2
      Data
        #|a
        #|New password
        #|.
        #|wq
      End
      When run script $1 edit -h
      The status should be success
      The file "${PREFIX}/-h.$3" should be exist
      expected_file() { %text:expand
        #|$1Recipient:myself
        #|$1:New password
      }
      The contents of file "${PREFIX}/-h.$3" should \
        equal "$(expected_file "$3")"
      expected_log() { %text:expand
        #|Add password for -h using ed -c.
        #|
        #| -h.$1 | 2 ++
        #| 1 file changed, 2 insertions(+)
        setup_log
      }
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(expected_log $3)"
    End

    It 'creates a file named like a directory'
      EDITOR='ed -c'
      Skip if 'pass(age) needs bash' check_skip $2
      Data
        #|a
        #|New ambiguous password
        #|.
        #|wq
      End
      When run script $1 edit fluff
      The status should be success
      The file "${PREFIX}/fluff.$3" should be exist
      expected_file() { %text:expand
        #|$1Recipient:myself
        #|$1:New ambiguous password
      }
      The contents of file "${PREFIX}/fluff.$3" should \
        equal "$(expected_file "$3")"
      expected_log() { %text:expand
        #|Add password for fluff using ed -c.
        #|
        #| fluff.$1 | 2 ++
        #| 1 file changed, 2 insertions(+)
        setup_log
      }
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(expected_log $3)"
    End

    It 'creates a secret file named like an unencrypted file'
      EDITOR='ed -c'
      Skip if 'pass(age) needs bash' check_skip $2
      Data
        #|a
        #|New password in a new file
        #|.
        #|wq
      End
      When run script $1 edit y.txt
      The status should be success
      The file "${PREFIX}/y.txt.$3" should be exist
      expected_file() { %text:expand
        #|$1Recipient:myself
        #|$1:New password in a new file
      }
      The contents of file "${PREFIX}/y.txt.$3" should \
        equal "$(expected_file "$3")"
      expected_log() { %text:expand
        #|Add password for y.txt using ed -c.
        #|
        #| y.txt.$1 | 2 ++
        #| 1 file changed, 2 insertions(+)
        setup_log
      }
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(expected_log $3)"
    End

    It 'updates a file using EDITOR'
      Skip if 'pass(age) needs bash' check_skip $2
      Data
        #|2i
        #|New line
        #|.
        #|wq
      End
      When run script $1 edit fluff/two
      The status should be success
      expected_file() { %text:expand
        #|$1Recipient:master
        #|$1Recipient:myself
        #|$1:2-password
        #|$1:New line
        #|$1:URL: https://example.com/login
      }
      The contents of file "${PREFIX}/fluff/two.$3" should \
        equal "$(expected_file "$3")"
      expected_log() { %text:expand
        #|Edit password for fluff/two using ed.
        #|
        #| fluff/two.$1 | 1 +
        #| 1 file changed, 1 insertion(+)
        setup_log
      }
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(expected_log $3)"
    End

    It 'updates a file having an ambiguous name without suffix'
      Skip if 'pass(age) needs bash' check_skip $2
      Data
        #|1i
        #|New line
        #|.
        #|wq
      End
      When run script $1 edit extra
      The status should be success
      expected_file() { %text:expand
        #|$1Recipient:myself
        #|$1:New line
        #|$1:ambiguous
      }
      The contents of file "${PREFIX}/extra.$3" should \
        equal "$(expected_file "$3")"
      expected_log() { %text:expand
        #|Edit password for extra using ed.
        #|
        #| extra.$1 | 1 +
        #| 1 file changed, 1 insertion(+)
        setup_log
      }
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(expected_log $3)"
    End

    It 'reencrypts an updated file using EDITOR'
      Skip if 'pass(age) needs bash' check_skip $2
      Data
        #|a
        #|New option
        #|.
        #|wq
      End
      When run script $1 edit stale
      The status should be success
      expected_file() { %text:expand
        #|$1Recipient:myself
        #|$1:0-password
        #|$1:New option
      }
      The contents of file "${PREFIX}/stale.$3" should \
        equal "$(expected_file "$3")"
      expected_log() { %text:expand
        #|Edit password for stale using ed.
        #|
        #| stale.$1 | 2 +-
        #| 1 file changed, 1 insertion(+), 1 deletion(-)
        setup_log
      }
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(expected_log $3)"
    End

    It 'does not reencrypt an unchanged file using EDITOR'
      Skip if 'pass(age) needs bash' check_skip $2
      Data 'q'
      When run script $1 edit stale
      The status should equal \
        "$(if [ $2 = pashage ]; then echo 0; else echo 1; fi)"
      expected_file() { %text:expand
        #|$1Recipient:master
        #|$1Recipient:myself
        #|$1:0-password
      }
      The contents of file "${PREFIX}/stale.$3" should \
        equal "$(expected_file "$3")"
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(setup_log)"
    End

    It 'allows cancelling file creation'
      Skip if 'pass(age) needs bash' check_skip $2
      Data 'q'
      When run script $1 edit subdir/new
      The status should be successful
      The file "${PREFIX}/subdir/new.age" should not be exist
      The file "${PREFIX}/subdir/new.gpg" should not be exist
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(setup_log)"
    End

    It 'displays usage when called without argument'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 edit
      The status should equal 1
      The output should be blank
      The error should include 'Usage:'
      The error should include ' edit '
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(setup_log)"
    End

    It 'rejects a path containing ..'
      Skip if 'pass(age) needs bash' check_skip $2
      EDITOR=true
      When run script $1 edit subdir/../stale
      The status should equal 1
      The output should be blank
      The error should include 'sneaky'
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(setup_log)"
    End
  End

  Describe 'generate'
    It 'generates a new file'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 generate newdir/newfile
      The status should be success
      The output should include 'The generated password for'
      The file "${PREFIX}/newdir/newfile.$3" should be exist
      The lines of contents of file "${PREFIX}/newdir/newfile.$3" should \
        equal 2
      The line 1 of contents of file "${PREFIX}/newdir/newfile.$3" should \
        equal "$3Recipient:myself"
      The output should \
        include "$(@sed -n "2s/$3://p" "${PREFIX}/newdir/newfile.$3")"
      expected_log() { %text:expand
        #|Add generated password for newdir/newfile.
        #|
        #| newdir/newfile.$1 | 2 ++
        #| 1 file changed, 2 insertions(+)
        setup_log
      }
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(expected_log $3)"
    End

    It 'fails to generates a new file named like a flag without escape'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 generate -h
      The status should equal 1
      The output should be blank
      The error should include 'Usage:'
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(setup_log)"
    End

    It 'generates a new file named like a flag'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 generate -- -h
      The status should be success
      The output should include 'The generated password for'
      The file "${PREFIX}/-h.$3" should be exist
      The lines of contents of file "${PREFIX}/-h.$3" should equal 2
      The line 1 of contents of file "${PREFIX}/-h.$3" should \
        equal "$3Recipient:myself"
      The output should \
        include "$(@sed -n "2s/$3://p" "${PREFIX}/-h.$3")"
      expected_log() { %text:expand
        #|Add generated password for -h.
        #|
        #| -h.$1 | 2 ++
        #| 1 file changed, 2 insertions(+)
        setup_log
      }
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(expected_log $3)"
    End

    It 'generates a new file named like a directory'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 generate fluff
      The status should be success
      The output should include 'The generated password for'
      The file "${PREFIX}/fluff.$3" should be exist
      The lines of contents of file "${PREFIX}/fluff.$3" should equal 2
      The line 1 of contents of file "${PREFIX}/fluff.$3" should \
        equal "$3Recipient:myself"
      The output should \
        include "$(@sed -n "2s/$3://p" "${PREFIX}/fluff.$3")"
      expected_log() { %text:expand
        #|Add generated password for fluff.
        #|
        #| fluff.$1 | 2 ++
        #| 1 file changed, 2 insertions(+)
        setup_log
      }
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(expected_log $3)"
    End

    It 'generates a new file in a new directory'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 generate brand-new-dir/file
      The status should be success
      The output should include 'The generated password for'
      The file "${PREFIX}/brand-new-dir/file.$3" should be exist
      The lines of contents of file "${PREFIX}/brand-new-dir/file.$3" should \
        equal 2
      The line 1 of contents of file "${PREFIX}/brand-new-dir/file.$3" should \
        equal "$3Recipient:myself"
      The output should \
        include "$(@sed -n "2s/$3://p" "${PREFIX}/brand-new-dir/file.$3")"
      expected_log() { %text:expand
        #|Add generated password for brand-new-dir/file.
        #|
        #| brand-new-dir/file.$1 | 2 ++
        #| 1 file changed, 2 insertions(+)
        setup_log
      }
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(expected_log $3)"
    End

    It 'generates a new file without symbols'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 generate -n newfile 4
      The status should be success
      The output should include 'The generated password for'
      The file "${PREFIX}/newfile.$3" should be exist
      The lines of contents of file "${PREFIX}/newfile.$3" should \
        equal 2
      The line 1 of contents of file "${PREFIX}/newfile.$3" should \
        equal "$3Recipient:myself"
      The line 2 of contents of file "${PREFIX}/newfile.$3" should \
        match pattern "$3:[0-9a-zA-z][0-9a-zA-z][0-9a-zA-z][0-9a-zA-z]"
      The output should \
        include "$(@sed -n "2s/$3://p" "${PREFIX}/newfile.$3")"
      expected_log() { %text:expand
        #|Add generated password for newfile.
        #|
        #| newfile.$1 | 2 ++
        #| 1 file changed, 2 insertions(+)
        setup_log
      }
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(expected_log $3)"
    End

    It 'replaces an existing file when forced'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 generate -f fluff/three 20
      The status should be success
      The output should include 'The generated password for'
      The lines of contents of file "${PREFIX}/fluff/three.$3" should equal 3
      The output should \
        include "$(@sed -n "3s/$3://p" "${PREFIX}/fluff/three.$3")"
      expected_log() { %text:expand
        #|Add generated password for fluff/three.
        #|
        #| fluff/three.$1 | 4 +---
        #| 1 file changed, 1 insertion(+), 3 deletions(-)
        setup_log
      }
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(expected_log $3)"
    End

    It 'replaces the first line of an existing file'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 generate -ni fluff/three 4
      The status should be success
      The output should include 'The generated password for'
      The lines of contents of file "${PREFIX}/fluff/three.$3" should equal 5
      The line 3 of contents of file "${PREFIX}/fluff/three.$3" should \
        match pattern "$3:[0-9a-zA-z][0-9a-zA-z][0-9a-zA-z][0-9a-zA-z]"
      The output should \
        include "$(@sed -n "3s/$3://p" "${PREFIX}/fluff/three.$3")"
      expected_log() { %text:expand
        #|Replace generated password for fluff/three.
        #|
        #| fluff/three.$1 | 2 +-
        #| 1 file changed, 1 insertion(+), 1 deletion(-)
        setup_log
      }
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(expected_log $3)"
    End

    It 'pastes the generated password into the clipboard'
      DISPLAY=mock
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 generate -nc subdir/new
      The status should be success
      The output should not include 'The generated password for'
      The output should not \
        include "$(@sed -n "2s/$3://p" "${PREFIX}/subdir/new.$3")"
      The output should include \
        'Copied subdir/new to clipboard. Will clear in 45 seconds.'
      The error should start with '$ xclip -selection clipboard'
      expected_log() { %text:expand
        #|Add generated password for subdir/new.
        #|
        #| subdir/new.$1 | 2 ++
        #| 1 file changed, 2 insertions(+)
        setup_log
      }
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(expected_log $3)"
    End

    It 'displays the generated password as a QR-code'
      DISPLAY=mock
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 generate -qn new
      The status should be success
      The output should not include 'The generated password for'
      The output should not include "$(@sed -n "2s/$3://p" "${PREFIX}/new.$3")"
      The error should start with '$ feh -x --title pas'
      expected_log() { %text:expand
        #|Add generated password for new.
        #|
        #| new.$1 | 2 ++
        #| 1 file changed, 2 insertions(+)
        setup_log
      }
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(expected_log $3)"
    End

    It 'reports a generation error'
      Mock tr
        if [ "$1" = '-dc' ]; then
          %putsn '0123456789'
        else
          @tr "$@"
        fi
      End
      expected_err() {
        if [ "$1" = pashage ]; then
          %putsn 'Error while generating password: 10/12 bytes read'
        else
          %putsn 'Could not generate password from /dev/urandom.'
        fi
      }
      When run script $1 generate -f new-secret 12
      The status should equal 1
      The output should be blank
      The error should equal "$(expected_err $2)"
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(setup_log)"
    End

    It 'displays usage when called without argument'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 generate
      The status should equal 1
      The output should be blank
      The error should include 'Usage:'
      The error should include ' generate '
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(setup_log)"
    End

    It 'displays usage when called with incompatible display options'
      When run script $1 generate --clip --qrcode new-secret
      The status should equal 1
      The output should be blank
      The error should include 'Usage:'
      The error should include ' generate '
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(setup_log)"
    End

    It 'displays usage when called with reversed incompatible display options'
      When run script $1 generate --qrcode --clip new-secret
      The status should equal 1
      The output should be blank
      The error should include 'Usage:'
      The error should include ' generate '
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(setup_log)"
    End

    It 'displays usage when called with incompatible overwriting options'
      When run script $1 generate --force --inplace new-secret
      The status should equal 1
      The output should be blank
      The error should include 'Usage:'
      The error should include ' generate '
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(setup_log)"
    End

    It 'displays usage when called with reversed incompatible overwriting opt'
      When run script $1 generate --inplace --force new-secret
      The status should equal 1
      The output should be blank
      The error should include 'Usage:'
      The error should include ' generate '
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(setup_log)"
    End

    It 'rejects a path containing ..'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 generate subdir/../new-secret
      The status should equal 1
      The output should be blank
      The error should include 'sneaky'
      The file "${PREFIX}/new-secret.age" should not be exist
      The file "${PREFIX}/new-secret.gpg" should not be exist
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(setup_log)"
    End
  End

  Describe 'rm'
    It 'removes a file without confirmation when forced'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 rm -f subdir/file
      The status should be success
      The output should include 'subdir/file'
      The error should be blank
      The file "${PREFIX}/subdir/file.$3" should not be exist
      expected_log() { %text:expand
        #|Remove subdir/file from store.
        #|
        #| subdir/file.$1 | 2 --
        #| 1 file changed, 2 deletions(-)
        setup_log
      }
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(expected_log $3)"
    End

    It 'fails to remove a file named like a flag without escape'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 rm -f -g
      The status should equal 1
      The output should be blank
      The error should include 'Usage:'
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(setup_log)"
    End

    It 'removes a file named like a flag'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 rm -f -- -g
      The status should be success
      The output should include '-g'
      The error should be blank
      The file "${PREFIX}/-g.$3" should not be exist
      expected_log() { %text:expand
        #|Remove -g from store.
        #|
        #| -g.$1 | 2 --
        #| 1 file changed, 2 deletions(-)
        setup_log
      }
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(expected_log $3)"
    End

    It 'removes a file having an ambiguous name without suffix'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 rm -f extra
      The status should be success
      The output should include 'extra'
      The error should be blank
      The file "${PREFIX}/extra.$3" should not be exist
      The directory "${PREFIX}/extra" should be exist
      expected_log() { %text:expand
        #|Remove extra from store.
        #|
        #| extra.$1 | 2 --
        #| 1 file changed, 2 deletions(-)
        setup_log
      }
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(expected_log $3)"
    End

    It 'fails to remove a non-existent file'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 rm -f non-existent-file
      The status should equal 1
      The error should include 'non-existent-file'
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(setup_log)"
    End

    It 'does not remove a directory without `-r` even when forced'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 rm -f fluff
      The status should equal \
        "$(if [ $2 = pashage ]; then echo 1; else echo 0; fi)"
      The error should include 'fluff/'
      The error should include 's a directory'
      The directory "${PREFIX}/fluff" should be exist
      The file "${PREFIX}/fluff/one.$3" should be exist
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(setup_log)"
    End

    It 'removes a directory when forced and recursive'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 rm -rf fluff
      The status should be success
      The directory "${PREFIX}/fluff" should not be exist
      expected_log() {
        if [ $1 = pashage ]; then
          %putsn 'Remove fluff/ from store.'
        else
          %putsn 'Remove fluff from store.'
        fi
        %text:expand
        #|
        #| fluff/.age-recipients | 2 --
        #| fluff/.gpg-id         | 2 --
        #| fluff/one.age         | 3 ---
        #| fluff/one.gpg         | 3 ---
        #| fluff/three.age       | 5 -----
        #| fluff/three.gpg       | 5 -----
        #| fluff/two.age         | 4 ----
        #| fluff/two.gpg         | 4 ----
        #| 8 files changed, 28 deletions(-)
        setup_log
      }
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(expected_log $2)"
    End

    It 'removes a directory having an ambiguous name with `/` suffix'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 rm -rf extra/
      The status should be success
      The output should include 'extra'
      The error should be blank
      The file "${PREFIX}/extra.age" should be exist
      The file "${PREFIX}/extra.gpg" should be exist
      The directory "${PREFIX}/extra" should not be exist
      expected_log() { %text:expand
        #|Remove extra/ from store.
        #|
        #| extra/subdir/file.age | 2 --
        #| extra/subdir/file.gpg | 2 --
        #| 2 files changed, 4 deletions(-)
        setup_log
      }
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(expected_log $3)"
    End

    It 'does not remove anything with `/` suffix but no recursive flag'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 rm -f extra/
      The status should equal \
        "$(if [ $2 = pashage ]; then echo 1; else echo 0; fi)"
      The error should include 'extra/'
      The error should include 's a directory'
      The directory "${PREFIX}/extra" should be exist
      The file "${PREFIX}/extra.age" should be exist
      The file "${PREFIX}/extra.gpg" should be exist
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(setup_log)"
    End

    It 'fails to remove a non-existent directory'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 rm -rf stale/
      The status should equal 1
      The error should include 'stale/'
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(setup_log)"
    End

    It 'does not remove an unencrypted file in the store'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 rm -f y.txt
      The status should equal 1
      The output should be blank
      The error should include 'y.txt'
      The file "${PREFIX}/y.txt" should be exist
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(setup_log)"
    End

    It 'does not remove an unencrypted file with `/` suffix'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 rm -rf y.txt/
      The status should equal 1
      The output should be blank
      The error should include 'y.txt'
      The file "${PREFIX}/y.txt" should be exist
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(setup_log)"
    End

    It 'displays usage when called without argument'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 delete
      The status should equal 1
      The output should be blank
      The error should include 'Usage:'
      The error should include ' delete '
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(setup_log)"
    End

    It 'rejects a path containing ..'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 delete subdir/../fluff/one
      The status should equal 1
      The output should be blank
      The error should include 'sneaky'
      The file "${PREFIX}/fluff/one.age" should be exist
      The file "${PREFIX}/fluff/one.gpg" should be exist
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(setup_log)"
    End
  End

  Describe 'mv'
    It 'renames a file without reencrypting'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 mv subdir/file subdir/renamed
      The status should be success
      The error should be blank
      The file "${PREFIX}/subdir/file.$3" should not be exist
      file_contents() { %text:expand
        #|${1}Recipient:myself
        #|${1}:p4ssw0rd
      }
      The contents of file "${PREFIX}/subdir/renamed.$3" \
        should equal "$(file_contents "$3")"
      expected_log() {
        if [ "$2" = pashage ]; then
          %putsn 'Move subdir/file.age to subdir/renamed.age'
        else
          %putsn 'Rename subdir/file to subdir/renamed.'
        fi
        %text:expand
        #|
        #| subdir/{file.$1 => renamed.$1} | 0
        #| 1 file changed, 0 insertions(+), 0 deletions(-)
        setup_log
      }
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(expected_log $3 $2)"
    End

    It 'fails to rename a file named like a flag without escape'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 mv -g safe-name
      The status should equal 1
      The output should be blank
      The error should include 'Usage:'
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(setup_log)"
    End

    It 'renames a file named like a flag'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 mv -- -g -h
      The status should be success
      The error should be blank
      The file "${PREFIX}/-g.$3" should not be exist
      file_contents() { %text:expand
        #|${1}Recipient:myself
        #|${1}:--
      }
      The contents of file "${PREFIX}/-h.$3" \
        should equal "$(file_contents "$3")"
      expected_log() {
        if [ "$2" = pashage ]; then
          %putsn 'Move -g.age to -h.age'
        else
          %putsn 'Rename -g to -h.'
        fi
        %text:expand
        #|
        #| -g.$1 => -h.$1 | 0
        #| 1 file changed, 0 insertions(+), 0 deletions(-)
        setup_log
      }
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(expected_log $3 $2)"
    End

    It 'reencrypts a moved file'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 mv subdir/file shared/renamed
      The status should be success
      The error should be blank
      The file "${PREFIX}/subdir/file.$3" should not be exist
      file_contents() { %text:expand
        #|${1}Recipient:myself
        #|${1}Recipient:friend
        #|${1}:p4ssw0rd
      }
      The contents of file "${PREFIX}/shared/renamed.$3" \
        should equal "$(file_contents "$3")"
      expected_log() {
        if [ "$2" = pashage ]; then
          %putsn 'Move subdir/file.age to shared/renamed.age'
        else
          %putsn 'Rename subdir/file to shared/renamed.'
        fi
        %text:expand
        #|
        #| subdir/file.$1 => shared/renamed.$1 | 1 +
        #| 1 file changed, 1 insertion(+)
        setup_log
      }
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(expected_log $3 $2)"
    End

    It 'moves an unencrypted file without reencrypting it'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 mv y.txt shared
      The status should be success
      The error should be blank
      The file "${PREFIX}/y.txt" should not be exist
      file_contents() { %text
        #|Unencrypted line 1
        #|Unencrypted line 2
        #|Unencrypted line 3
      }
      The contents of file "${PREFIX}/shared/y.txt" \
        should equal "$(file_contents)"
      expected_log() {
        if [ "$2" = pashage ]; then
          %putsn 'Move y.txt to shared/y.txt'
        else
          %putsn 'Rename y.txt to shared.'
        fi
        %text
        #|
        #| y.txt => shared/y.txt | 0
        #| 1 file changed, 0 insertions(+), 0 deletions(-)
        setup_log
      }
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(expected_log $3 $2)"
    End

    It 'reencrypts relevant files in a moved directory'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 mv subdir shared/
      The status should be success
      The error should be blank
      The file "${PREFIX}/subdir/file.$3" should not be exist
      file_contents() { %text:expand
        #|${1}Recipient:myself
        #|${1}Recipient:friend
        #|${1}:p4ssw0rd
      }
      The contents of file "${PREFIX}/shared/subdir/file.$3" \
        should equal "$(file_contents "$3")"
      expected_log() {
        if [ "$2" = pashage ]; then
          %putsn 'Move subdir/ to shared/subdir/'
        else
          %putsn 'Rename subdir to shared/.'
        fi
        if [ "$1" = age ]; then
          %text:expand
          #|
          #| {subdir => shared/subdir}/file.age | 1 +
          #| {subdir => shared/subdir}/file.gpg | 0
          #| 2 files changed, 1 insertion(+)
        else
          %text:expand
          #|
          #| {subdir => shared/subdir}/file.age | 0
          #| {subdir => shared/subdir}/file.gpg | 1 +
          #| 2 files changed, 1 insertion(+)
        fi
        setup_log
      }
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(expected_log $3 $2)"
    End

    It 'moves a file into a new directory'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 mv subdir/file new-subdir/
      The status should be success
      The error should be blank
      The file "${PREFIX}/subdir/file.$3" should not be exist
      file_contents() { %text:expand
        #|${1}Recipient:myself
        #|${1}:p4ssw0rd
      }
      The contents of file "${PREFIX}/new-subdir/file.$3" \
        should equal "$(file_contents "$3")"
      expected_log() {
        if [ "$2" = pashage ]; then
          %putsn 'Move subdir/file.age to new-subdir/file.age'
        else
          %putsn 'Rename subdir/file to new-subdir/.'
        fi
        %text:expand
        #|
        #| {subdir => new-subdir}/file.$1 | 0
        #| 1 file changed, 0 insertions(+), 0 deletions(-)
        setup_log
      }
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(expected_log $3 $2)"
    End

    It 'fails to rename a non-existent file'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 mv non-existent-file new-name
      The status should equal 1
      The error should \
        equal 'Error: non-existent-file is not in the password store.'
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(setup_log)"
    End

    It 'renames a directory with recipients'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 mv fluff filler
      The status should be success
      The error should be blank
      The directory "${PREFIX}/fluff" should not be exist
      The directory "${PREFIX}/filler" should be exist
      expected_log() {
        if [ "$2" = pashage ]; then
          %putsn 'Move fluff/ to filler/'
        else
          %putsn 'Rename fluff to filler.'
        fi
        %text:expand
        #|
        #| {fluff => filler}/.age-recipients | 0
        #| {fluff => filler}/.gpg-id         | 0
        #| {fluff => filler}/one.age         | 0
        #| {fluff => filler}/one.gpg         | 0
        #| {fluff => filler}/three.age       | 0
        #| {fluff => filler}/three.gpg       | 0
        #| {fluff => filler}/two.age         | 0
        #| {fluff => filler}/two.gpg         | 0
        #| 8 files changed, 0 insertions(+), 0 deletions(-)
        setup_log
      }
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(expected_log $3 $2)"
    End

    It 'renames a directory without recipients'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 mv subdir newdir
      The status should be success
      The error should be blank
      The directory "${PREFIX}/subdir" should not be exist
      file_contents() { %text:expand
        #|${1}Recipient:myself
        #|${1}:p4ssw0rd
      }
      The contents of file "${PREFIX}/newdir/file.$3" \
        should equal "$(file_contents "$3")"
      expected_log() {
        if [ "$2" = pashage ]; then
          %putsn 'Move subdir/ to newdir/'
        else
          %putsn 'Rename subdir to newdir.'
        fi
        %text:expand
        #|
        #| {subdir => newdir}/file.age | 0
        #| {subdir => newdir}/file.gpg | 0
        #| 2 files changed, 0 insertions(+), 0 deletions(-)
        setup_log
      }
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(expected_log $3 $2)"
    End

    It 'overwrites an existing file when forced'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 mv -f fluff/two fluff/one
      The status should be success
      The file "${PREFIX}/fluff/two.$3" should not be exist
      file_contents() { %text:expand
        #|${1}Recipient:master
        #|${1}Recipient:myself
        #|${1}:2-password
        #|${1}:URL: https://example.com/login
      }
      The contents of file "${PREFIX}/fluff/one.$3" \
        should equal "$(file_contents "$3")"
      expected_log() {
        if [ "$2" = pashage ]; then
          %putsn 'Move fluff/two.age to fluff/one.age'
        else
          %putsn 'Rename fluff/two to fluff/one.'
        fi
        %text:expand
        #|
        #| fluff/one.$1 | 3 ++-
        #| fluff/two.$1 | 4 ----
        #| 2 files changed, 2 insertions(+), 5 deletions(-)
        setup_log
      }
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(expected_log $3 $2)"
    End

    It 'renames a file having an ambiguous name without suffix'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 mv extra new
      The status should be success
      The file "${PREFIX}/extra.$3" should not be exist
      file_contents() { %text:expand
        #|${1}Recipient:myself
        #|${1}:ambiguous
      }
      The contents of file "${PREFIX}/new.$3" \
        should equal "$(file_contents "$3")"
      expected_log() {
        if [ "$2" = pashage ]; then
          %putsn 'Move extra.age to new.age'
        else
          %putsn 'Rename extra to new.'
        fi
        %text:expand
        #|
        #| extra.$1 => new.$1 | 0
        #| 1 file changed, 0 insertions(+), 0 deletions(-)
        setup_log
      }
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(expected_log $3 $2)"
    End

    It 'renames a directory having an ambiguous name with `/` suffix'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 mv extra/ new
      The status should be success
      The directory "${PREFIX}/extra" should not be exist
      The file "${PREFIX}/new/subdir/file.age" should be exist
      The file "${PREFIX}/new/subdir/file.gpg" should be exist
      expected_log() {
        if [ "$2" = pashage ]; then
          %putsn 'Move extra/ to new/'
        else
          %putsn 'Rename extra/ to new.'
        fi
        %text:expand
        #|
        #| {extra => new}/subdir/file.age | 0
        #| {extra => new}/subdir/file.gpg | 0
        #| 2 files changed, 0 insertions(+), 0 deletions(-)
        setup_log
      }
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(expected_log $3 $2)"
    End

    It 'moves a file to a directory having an ambiguous name without suffix'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 mv subdir/file extra
      The status should be success
      The file "${PREFIX}/subdir/file.$3" should not be exist
      file_contents() { %text:expand
        #|${1}Recipient:myself
        #|${1}:p4ssw0rd
      }
      The contents of file "${PREFIX}/extra/file.$3" \
        should equal "$(file_contents "$3")"
      expected_log() {
        if [ "$2" = pashage ]; then
          %putsn "Move subdir/file.$1 to extra/file.$1"
        else
          %putsn 'Rename subdir/file to extra.'
        fi
        %text:expand
        #|
        #| {subdir => extra}/file.$1 | 0
        #| 1 file changed, 0 insertions(+), 0 deletions(-)
        setup_log
      }
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(expected_log $3 $2)"
    End

    It 'does not merge directories recursively'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 mv -f subdir/ extra/
      The status should equal 1
      The error should include 'subdir'
      The error should include 'extra/'
      The directory "${PREFIX}/subdir" should be exist
      The file "${PREFIX}/subdir/file.$3" should be exist
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(setup_log)"
    End

    It 'displays usage when called without argument'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 mv
      The status should equal 1
      The output should be blank
      The error should include 'Usage:'
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(setup_log)"
    End

    It 'fails to rename a non-existent directory'
      Skip if 'pass(age) considers "stale/" as the file "stale"' \
        [ ! $2 = pashage ]
      When run script $1 mv stale/ new-name
      The status should equal 1
      The error should equal 'Error: stale/ is not in the password store.'
      The directory "${PREFIX}/new-name" should not be exist
      The file "${PREFIX}/new-name.age" should not be exist
      The file "${PREFIX}/new-name.gpg" should not be exist
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(setup_log)"
    End

    It 'rejects a source path containing ..'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 mv fluff/../stale subdir/
      The status should equal 1
      The output should be blank
      The error should include 'sneaky'
      The file "${PREFIX}/stale.age" should be exist
      The file "${PREFIX}/stale.gpg" should be exist
      The file "${PREFIX}/subdir/stale.age" should not be exist
      The file "${PREFIX}/subdir/stale.gpg" should not be exist
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(setup_log)"
    End

    It 'rejects a destination path containing ..'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 mv subdir/file extra/subdir/..
      The status should equal 1
      The output should be blank
      The error should include 'sneaky'
      The file "${PREFIX}/subdir/file.age" should be exist
      The file "${PREFIX}/subdir/file.gpg" should be exist
      The file "${PREFIX}/extra/file.age" should not be exist
      The file "${PREFIX}/extra/file.gpg" should not be exist
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(setup_log)"
    End
  End

  Describe 'cp'
    It 'copies a file without reencrypting'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 cp subdir/file subdir/copy
      The status should be success
      The error should be blank
      file_contents() { %text:expand
        #|${1}Recipient:myself
        #|${1}:p4ssw0rd
      }
      The contents of file "${PREFIX}/subdir/copy.$3" \
        should equal "$(file_contents "$3")"
      expected_log() {
        if [ "$2" = pashage ]; then
          %putsn 'Copy subdir/file.age to subdir/copy.age'
        else
          %putsn 'Copy subdir/file to subdir/copy.'
        fi
        %text:expand
        #|
        #| subdir/copy.$1 | 2 ++
        #| 1 file changed, 2 insertions(+)
        setup_log
      }
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(expected_log $3 $2)"
    End

    It 'fails to copy a file named like a flag without escape'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 cp -g safe-name
      The status should equal 1
      The output should be blank
      The error should not be blank
      The error should include 'Usage:'
      The contents of file "${GITLOG}" should equal "$(setup_log)"
    End

    It 'copies a file named like a flag'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 cp -- -g -h
      The status should be success
      The error should be blank
      file_contents() { %text:expand
        #|${1}Recipient:myself
        #|${1}:--
      }
      The contents of file "${PREFIX}/-h.$3" \
        should equal "$(file_contents "$3")"
      expected_log() {
        if [ "$2" = pashage ]; then
          %putsn 'Copy -g.age to -h.age'
        else
          %putsn 'Copy -g to -h.'
        fi
        %text:expand
        #|
        #| -h.$1 | 2 ++
        #| 1 file changed, 2 insertions(+)
        setup_log
      }
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(expected_log $3 $2)"
    End

    It 'reencrypts a copied file'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 cp subdir/file shared/copy
      The status should be success
      The error should be blank
      file_contents() { %text:expand
        #|${1}Recipient:myself
        #|${1}Recipient:friend
        #|${1}:p4ssw0rd
      }
      The contents of file "${PREFIX}/shared/copy.$3" \
        should equal "$(file_contents "$3")"
      expected_log() {
        if [ "$2" = pashage ]; then
          %putsn 'Copy subdir/file.age to shared/copy.age'
        else
          %putsn 'Copy subdir/file to shared/copy.'
        fi
        %text:expand
        #|
        #| shared/copy.$1 | 3 +++
        #| 1 file changed, 3 insertions(+)
        setup_log
      }
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(expected_log $3 $2)"
    End

    It 'copies an unencrypted file without reencrypting it'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 cp y.txt shared
      The status should be success
      The error should be blank
      file_contents() { %text
        #|Unencrypted line 1
        #|Unencrypted line 2
        #|Unencrypted line 3
      }
      The contents of file "${PREFIX}/shared/y.txt" \
        should equal "$(file_contents)"
      expected_log() {
        if [ "$2" = pashage ]; then
          %putsn 'Copy y.txt to shared/y.txt'
        else
          %putsn 'Copy y.txt to shared.'
        fi
        %text
        #|
        #| shared/y.txt | 3 +++
        #| 1 file changed, 3 insertions(+)
        setup_log
      }
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(expected_log $3 $2)"
    End

    It 'reencrypts relevant files in a copied directory'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 cp subdir shared/
      The status should be success
      The error should be blank
      file_contents() { %text:expand
        #|${1}Recipient:myself
        #|${1}Recipient:friend
        #|${1}:p4ssw0rd
      }
      The contents of file "${PREFIX}/shared/subdir/file.$3" \
        should equal "$(file_contents "$3")"
      expected_log() {
        if [ "$2" = pashage ]; then
          %putsn 'Copy subdir/ to shared/subdir/'
        else
          %putsn 'Copy subdir to shared/.'
        fi
        if [ "$1" = age ]; then
          %text:expand
          #|
          #| shared/subdir/file.age | 3 +++
          #| shared/subdir/file.gpg | 2 ++
          #| 2 files changed, 5 insertions(+)
        else
          %text:expand
          #|
          #| shared/subdir/file.age | 2 ++
          #| shared/subdir/file.gpg | 3 +++
          #| 2 files changed, 5 insertions(+)
        fi
        setup_log
      }
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(expected_log $3 $2)"
    End

    It 'copies a file into a new directory'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 cp subdir/file new-subdir/
      The status should be success
      The error should be blank
      file_contents() { %text:expand
        #|${1}Recipient:myself
        #|${1}:p4ssw0rd
      }
      The contents of file "${PREFIX}/new-subdir/file.$3" \
        should equal "$(file_contents "$3")"
      expected_log() {
        if [ "$2" = pashage ]; then
          %putsn 'Copy subdir/file.age to new-subdir/file.age'
        else
          %putsn 'Copy subdir/file to new-subdir/.'
        fi
        %text:expand
        #|
        #| new-subdir/file.$1 | 2 ++
        #| 1 file changed, 2 insertions(+)
        setup_log
      }
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(expected_log $3 $2)"
    End

    It 'fails to copy a non-existent file'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 cp non-existent-file new-name
      The status should equal 1
      The error should \
        equal 'Error: non-existent-file is not in the password store.'
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(setup_log)"
    End

    It 'copies a directory with recipients'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 cp fluff filler
      The status should be success
      The error should be blank
      The directory "${PREFIX}/filler" should be exist
      expected_log() {
        if [ "$2" = pashage ]; then
          %putsn 'Copy fluff/ to filler/'
        else
          %putsn 'Copy fluff to filler.'
        fi
        %text:expand
        #|
        #| filler/.age-recipients | 2 ++
        #| filler/.gpg-id         | 2 ++
        #| filler/one.age         | 3 +++
        #| filler/one.gpg         | 3 +++
        #| filler/three.age       | 5 +++++
        #| filler/three.gpg       | 5 +++++
        #| filler/two.age         | 4 ++++
        #| filler/two.gpg         | 4 ++++
        #| 8 files changed, 28 insertions(+)
        setup_log
      }
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(expected_log $3 $2)"
    End

    It 'copies a directory without recipients'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 cp subdir newdir
      The status should be success
      The error should be blank
      file_contents() { %text:expand
        #|${1}Recipient:myself
        #|${1}:p4ssw0rd
      }
      The contents of file "${PREFIX}/newdir/file.$3" \
        should equal "$(file_contents "$3")"
      expected_log() {
        if [ "$2" = pashage ]; then
          %putsn 'Copy subdir/ to newdir/'
        else
          %putsn 'Copy subdir to newdir.'
        fi
        %text:expand
        #|
        #| newdir/file.age | 2 ++
        #| newdir/file.gpg | 2 ++
        #| 2 files changed, 4 insertions(+)
        setup_log
      }
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(expected_log $3 $2)"
    End

    It 'overwrites an existing file when forced'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 cp -f fluff/two fluff/one
      The status should be success
      file_contents() { %text:expand
        #|${1}Recipient:master
        #|${1}Recipient:myself
        #|${1}:2-password
        #|${1}:URL: https://example.com/login
      }
      The contents of file "${PREFIX}/fluff/one.$3" \
        should equal "$(file_contents "$3")"
      expected_log() {
        if [ "$2" = pashage ]; then
          %putsn 'Copy fluff/two.age to fluff/one.age'
        else
          %putsn 'Copy fluff/two to fluff/one.'
        fi
        %text:expand
        #|
        #| fluff/one.$1 | 3 ++-
        #| 1 file changed, 2 insertions(+), 1 deletion(-)
        setup_log
      }
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(expected_log $3 $2)"
    End

    It 'overwrites collisions when copying recursively and forcefully'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 cp -f subdir/ extra/
      The status should be success
      expected_log() {
        if [ "$2" = pashage ]; then
          %putsn 'Copy subdir/ to extra/subdir/'
        else
          %putsn 'Copy subdir/ to extra/.'
        fi
        %text:expand
        #|
        #| extra/subdir/file.age | 2 +-
        #| extra/subdir/file.gpg | 2 +-
        #| 2 files changed, 2 insertions(+), 2 deletions(-)
        setup_log
      }
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(expected_log $3 $2)"
    End

    It 'copies a file having an ambiguous name without suffix'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 cp extra new
      The status should be success
      file_contents() { %text:expand
        #|${1}Recipient:myself
        #|${1}:ambiguous
      }
      The contents of file "${PREFIX}/new.$3" \
        should equal "$(file_contents "$3")"
      expected_log() {
        if [ "$2" = pashage ]; then
          %putsn 'Copy extra.age to new.age'
        else
          %putsn 'Copy extra to new.'
        fi
        %text:expand
        #|
        #| new.$1 | 2 ++
        #| 1 file changed, 2 insertions(+)
        setup_log
      }
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(expected_log $3 $2)"
    End

    It 'copies a directory having an ambiguous name with `/` suffix'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 cp extra/ new
      The status should be success
      file_contents() { %text:expand
        #|${1}Recipient:myself
        #|${1}:Pa55worD
      }
      The contents of file "${PREFIX}/new/subdir/file.$3" \
        should equal "$(file_contents $3)"
      expected_log() {
        if [ "$2" = pashage ]; then
          %putsn 'Copy extra/ to new/'
        else
          %putsn 'Copy extra/ to new.'
        fi
        %text:expand
        #|
        #| new/subdir/file.age | 2 ++
        #| new/subdir/file.gpg | 2 ++
        #| 2 files changed, 4 insertions(+)
        setup_log
      }
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(expected_log $3 $2)"
    End

    It 'copies a file to a directory having an ambiguous name without suffix'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 cp subdir/file extra
      The status should be success
      file_contents() { %text:expand
        #|${1}Recipient:myself
        #|${1}:p4ssw0rd
      }
      The contents of file "${PREFIX}/extra/file.$3" \
        should equal "$(file_contents "$3")"
      expected_log() {
        if [ "$2" = pashage ]; then
          %putsn "Copy subdir/file.$1 to extra/file.$1"
        else
          %putsn 'Copy subdir/file to extra.'
        fi
        %text:expand
        #|
        #| extra/file.$1 | 2 ++
        #| 1 file changed, 2 insertions(+)
        setup_log
      }
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(expected_log $3 $2)"
    End

    It 'displays usage when called without argument'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 copy
      The status should equal 1
      The output should be blank
      The error should include 'Usage:'
      The error should include ' copy '
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(setup_log)"
    End

    It 'fails to copy a non-existent directory'
      Skip if 'pass(age) considers "stale/" as the file "stale"' \
        [ ! $2 = pashage ]
      When run script $1 cp stale/ new-name
      The status should equal 1
      The error should equal 'Error: stale/ is not in the password store.'
      The directory "${PREFIX}/new-name" should not be exist
      The file "${PREFIX}/new-name.age" should not be exist
      The file "${PREFIX}/new-name.gpg" should not be exist
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(setup_log)"
    End

    It 'rejects a source path containing ..'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 cp fluff/../stale subdir/
      The status should equal 1
      The output should be blank
      The error should include 'sneaky'
      The file "${PREFIX}/subdir/stale.age" should not be exist
      The file "${PREFIX}/subdir/stale.gpg" should not be exist
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(setup_log)"
    End

    It 'rejects a destination path containing ..'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 cp subdir/file extra/subdir/..
      The status should equal 1
      The output should be blank
      The error should include 'sneaky'
      The file "${PREFIX}/extra/file.age" should not be exist
      The file "${PREFIX}/extra/file.gpg" should not be exist
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(setup_log)"
    End
  End

  Describe 'git'
    It 'transmits arguments to git'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 git log --format='%s' --stat
      The status should be success
      The output should equal "$(setup_log)"
    End

    It 'displays git usage when called without argument'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 git
      The status should equal \
        "$(if [ $2 = pashage ]; then echo 1; else echo 0; fi)"
      The output should include 'usage: git'
      The error should be blank
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(setup_log)"
    End

    remove_git() { rm -rf "${PREFIX}/.git"; }
    BeforeEach remove_git

    It 'fails without a git repository'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 git log
      The status should equal 1
      The output should be blank
      The error should match pattern \
        'Error: the password store is not a git repository. Try "* git init".'
    End

    It 're-initializes the git repository'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 git init -b trunk
      The status should be successful
      The output should start with \
        "Initialized empty Git repository in ${PREFIX}/.git"
      The error should be blank
      The directory "${PREFIX}/.git" should be exist
      The file "${PREFIX}/.gitattributes" should be exist
    End
  End

  Describe 'help'
    It 'displays a help text with supported commands'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 help
      The status should be success
      if ! [ $2 = passage ]; then
        The output should include ' init '
      fi
      The output should include ' find '
      The output should include ' [show] '
      The output should include ' grep '
      The output should include ' insert '
      The output should include ' edit '
      The output should include ' generate '
      The output should include ' git '
      The output should include ' help'
      The output should include ' version'
    End
  End

  Describe 'version'
    It 'displays a version box'
      Skip if 'pass(age) needs bash' check_skip $2
      When run script $1 version
      The status should be success
      The output should include 'password manager'
      The output should start with '============='
      The output should end with '============='
    End
  End
End
