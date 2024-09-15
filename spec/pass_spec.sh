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

# This test file should pass with either pashage
# or pass (the original password-store).

# The original password-store script can be added to the parameters list
# to run the cases against it.
# bash seems to escape the sandbox by resetting PATH on the slightest
# provocation, while the tests rely heavily on the mocked cryptography
# to check the store behavior.
# So it only works when using shellspec with bash and calling the `pass`
# script directly (e.g. on FreeBSD `/usr/local/libexec/password-store/pass`
# instead of `/usr/local/bin/pass`.

Parameters # script/path  scriptname  encryption
  /usr/bin/pass             pass         gpg
  ./src/run.sh              pashage      age
End

Describe 'Pass-like command'
  check_skip() {
    [ "$1" = "${1%pass}pass" ] && ! [ "${SHELLSPEC_SHELL_TYPE}" = bash ]
  }

  GITLOG="${SHELLSPEC_WORKDIR}/git-log.txt"
  PREFIX="${SHELLSPEC_WORKDIR}/store"

  export PASSWORD_STORE_DIR="${PREFIX}"
  export PASHAGE_STORE_DIR="${PREFIX}"
  export PASHAGE_IDENTITIES_FILE="${SHELLSPEC_WORKDIR}/age-identities"

  git_log() {
    @git -C "${PREFIX}" log --format='%s' --stat >|"${GITLOG}"
  }

  setup_log() { %text
    #|Initial setup
    #|
    #| .gpg-id                | 1 +
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
    #| subdir/file.age        | 2 ++
    #| subdir/file.gpg        | 2 ++
    #| 13 files changed, 37 insertions(+)
  }

  setup_id() {
    @mkdir -p "${PREFIX}/$1"
    @cat >"${PREFIX}/$1/.age-recipients"
    @cp -i "${PREFIX}/$1/.age-recipients" "${PREFIX}/$1/.gpg-id"
  }

  setup_secret() {
    @mkdir -p "${PREFIX}/${1%/*}"
    @sed 's/^/age/' >"${PREFIX}/$1.age"
    @sed 's/^age/gpg/' "${PREFIX}/$1.age" >"${PREFIX}/$1.gpg"
  }

  setup() {
    @git init -q -b main "${PREFIX}"
    @git -C "${PREFIX}" config --local user.name 'Test User'
    @git -C "${PREFIX}" config --local user.email 'test@example.com'
    %putsn 'myself' >"${PASHAGE_IDENTITIES_FILE}"
    %putsn 'myself' >"${PREFIX}/.gpg-id"
    %text | setup_secret 'subdir/file'
    #|Recipient:myself
    #|:p4ssw0rd
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
    @git -C "${PREFIX}" add .
    @git -C "${PREFIX}" commit -m 'Initial setup' >/dev/null

    # Check setup_log consistency
    git_log
    setup_log | @diff -u - "${GITLOG}"
  }

  cleanup() {
    @rm -rf "${PREFIX}"
    @rm -f "${PASHAGE_IDENTITIES_FILE}"
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

  Mock cut
    . "${SHELLSPEC_SUPPORT_BIN}"
    invoke cut "$@"
  End

  Mock dirname
    @dirname "$@"
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
    invoke od -v -t x1 | sed 's/  */ /g;s/ *$//' >&2
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

  #TODO: init

  Describe 'ls'
    It 'lists a directory'
      Skip if 'pass needs bash' check_skip $1
      When run script $1 ls subdir
      The line 1 of output should include 'subdir'
      The line 2 of output should include 'file'
    End

    It 'lists a directory implicitly'
      Skip if 'pass needs bash' check_skip $1
      When run script $1 subdir
      The line 1 of output should include 'subdir'
      The line 2 of output should include 'file'
    End

    It 'lists a directory when called as `show`'
      Skip if 'pass needs bash' check_skip $1
      When run script $1 show subdir
      The line 1 of output should include 'subdir'
      The line 2 of output should include 'file'
    End

    It 'lists the whole store without argument'
      Skip if 'pass needs bash' check_skip $1
      When run script $1
      The line  1 of output should equal 'Password Store'
      The line  2 of output should include 'fluff'
      The line  3 of output should include 'one'
      The line  4 of output should include 'one'
      The line  5 of output should include 'three'
      The line  6 of output should include 'three'
      The line  7 of output should include 'two'
      The line  8 of output should include 'two'
      The line  9 of output should include 'shared'
      The line 10 of output should include 'subdir'
      The line 11 of output should include 'file'
      The line 12 of output should include 'file'
    End

    It 'does not list a file masquerading as a directory'
      Skip if 'pass needs bash' check_skip $1
      When run script $1 subdir/file/
      The status should equal 1
      The error should equal 'Error: subdir/file/ is not in the password store.'
    End
  End

  Describe 'find'
    It 'lists entries matching a substring'
      Skip if 'pass needs bash' check_skip $1
      When run script $1 find o
      The lines of output should equal 6
      The line 1 of output should match pattern 'Search *: o'
      The line 2 of output should include 'fluff'
      The line 3 of output should include 'one'
      The line 4 of output should include 'one'
      The line 5 of output should include 'two'
      The line 6 of output should include 'two'
    End

    It 'reports success even without match'
      Skip if 'pass needs bash' check_skip $1
      When run script $1 find z
      The status should be success
      The lines of output should equal 1
      The line 1 of output should match pattern 'Search *: z'
      The error should be blank
    End
  End

  Describe 'show'
    It 'decrypts a password file'
      Skip if 'pass needs bash' check_skip $1
      When run script $1 show subdir/file
      The output should equal 'p4ssw0rd'
    End

    It 'decrypts a password file implicitly'
      Skip if 'pass needs bash' check_skip $1
      When run script $1 subdir/file
      The output should equal 'p4ssw0rd'
    End

    It 'decrypts a password file even when called as `list`'
      Skip if 'pass needs bash' check_skip $1
      When run script $1 ls subdir/file
      The output should equal 'p4ssw0rd'
    End

    It 'displays the password as a QR-code'
      DISPLAY=mock
      Skip if 'pass needs bash' check_skip $1
      When run script $1 -q fluff/one
      expected_err() { %text:expand
        #|$ feh -x --title ${1}: fluff/one -g +200+200 -
        #|0000000 31 2d 70 61 73 73 77 6f 72 64
        #|0000012
      }
      The error should equal "$(expected_err "$2")"
    End

    It 'displays the given line as a QR-code'
      DISPLAY=mock
      Skip if 'pass needs bash' check_skip $1
      When run script $1 --qrcode=2 fluff/three
      expected_err() { %text:expand
        #|$ feh -x --title ${1}: fluff/three -g +200+200 -
        #|0000000 55 73 65 72 6e 61 6d 65 3a 20 33 4a 61 6e 65
        #|0000017
      }
      The error should equal "$(expected_err "$2")"
    End

    It 'pastes into the clipboard'
      DISPLAY=mock
      Skip if 'pass needs bash' check_skip $1
      When run script $1 show -c fluff/three
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
      Skip if 'pass needs bash' check_skip $1
      When run script $1 show -c2 fluff/three
      The output should start with \
        'Copied fluff/three to clipboard. Will clear in 45 seconds.'
      expected_err() { %text
        #|$ xclip -selection clipboard
        #|0000000 55 73 65 72 6e 61 6d 65 3a 20 33 4a 61 6e 65
        #|0000017
      }
      The error should start with "$(expected_err)"
    End
  End

  Describe 'grep'
    It 'shows decrypted lines matching a regex'
      Skip if 'pass needs bash' check_skip $1
      When run script $1 grep -i Com
      The lines of output should equal 4
      The line 1 of output should include 'fluff'
      The line 1 of output should include 'three'
      The line 2 of output should include 'https://example.'
      The line 3 of output should include 'fluff'
      The line 3 of output should include 'two'
      The line 4 of output should include 'https://example.'
    End

    It 'is successful even without match'
      Skip if 'pass needs bash' check_skip $1
      When run script $1 grep nothing.matches
      The status should be success
      The output should be blank
    End
  End

  Describe 'insert'
    It 'inserts a new multi-line entry'
      Skip if 'pass needs bash' check_skip $1
      Data
        #|password
        #|Username: tester
        #|URL: https://example.com/login
      End
      When run script $1 insert -m rootpass
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
      Skip if 'pass needs bash' check_skip $1
      Data
        #|pass-word
        #|pass-word
      End
      When run script $1 insert newdir/newpass
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

    It 'inserts a new single-line entry with echo'
      Skip if 'pass needs bash' check_skip $1
      Data "pass-word"
      When run script $1 insert -e newdir/newpass
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
      Skip if 'pass needs bash' check_skip $1
      Data "passWord"
      When run script $1 insert -e shared/newpass
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
      Skip if 'pass needs bash' check_skip $1
      Data "pass-word"
      When run script $1 insert -e -f subdir/file
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
  End

  #TODO: edit
  #TODO: generate

  Describe 'rm'
    It 'removes a file without confirmation when forced'
      Skip if 'pass needs bash' check_skip $1
      When run script $1 rm -f subdir/file
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

    #TODO: rm -rf
  End

  Describe 'mv'
    It 'renames a file without reencrypting'
      Skip if 'pass needs bash' check_skip $1
      When run script $1 mv subdir/file subdir/renamed
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

    It 'reencrypts a moved file'
      Skip if 'pass needs bash' check_skip $1
      When run script $1 mv subdir/file shared/renamed
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

    It 'reencrypts relevant files in a moved directory'
      Skip if 'pass needs bash' check_skip $1
      When run script $1 mv subdir shared/
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

    It 'renames a directory with recipients'
      Skip if 'pass needs bash' check_skip $1
      When run script $1 mv fluff filler
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
      Skip if 'pass needs bash' check_skip $1
      When run script $1 mv subdir newdir
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
      Skip if 'pass needs bash' check_skip $1
      When run script $1 mv -f fluff/two fluff/one
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

    #TODO: recursive mv -f
  End

  #TODO: cp
  #TODO: git

  Describe 'help'
    It 'displays a help text with supported commands'
      Skip if 'pass needs bash' check_skip $1
      When run script $1 help
      The output should include ' init '
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
      Skip if 'pass needs bash' check_skip $1
      When run script $1 version
      The output should include 'password manager'
      The output should start with '============='
      The output should end with '============='
    End
  End
End
