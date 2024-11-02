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

# This test file exercises the whole software through command functions,
# using minimal mocking, limited to cryptography (to make it more robust
# and easier to debug), like the `pass_usage.sh` suite.
# It complements `pass_usage.sh` with pashage-specific behavior, aiming for
# maximal coverage of normal code paths.

Describe 'Integrated Command Functions'
  Include src/pashage.sh
  Set 'errexit:on' 'nounset:on' 'pipefail:on'

  GITLOG="${SHELLSPEC_WORKDIR}/git-log.txt"

  AGE='mock-age'
  IDENTITIES_FILE="${SHELLSPEC_WORKDIR}/age-identities"
  PREFIX="${SHELLSPEC_WORKDIR}/store"

  CHARACTER_SET='[:punct:][:alnum:]'
  CHARACTER_SET_NO_SYMBOLS='[:alnum:]'
  CLIP_TIME=45
  GENERATED_LENGTH=25
  X_SELECTION=clipboard

  TREE__='   '
  TREE_I='|  '
  TREE_T='|- '
  TREE_L='`- '

  BOLD_TEXT='(B)'
  NORMAL_TEXT='(N)'
  RED_TEXT='(R)'
  BLUE_TEXT='(B)'
  UNDERLINE_TEXT='(U)'
  NO_UNDERLINE_TEXT='(!U)'

  git_log() {
    @git -C "${PREFIX}" status --porcelain >&2
    @git -C "${PREFIX}" log --format='%s' --stat >|"${GITLOG}"
  }

  setup_log() { %text
    #|Initial setup
    #|
    #| extra/subdir/file.age  | 2 ++
    #| fluff/.age-recipients  | 2 ++
    #| fluff/one.age          | 3 +++
    #| fluff/three.age        | 5 +++++
    #| fluff/two.age          | 4 ++++
    #| old.gpg                | 3 +++
    #| shared/.age-recipients | 2 ++
    #| stale.age              | 3 +++
    #| subdir/file.age        | 2 ++
    #| 9 files changed, 26 insertions(+)
  }

  setup_log_bin() { %text
    #|Initial setup
    #|
    #| extra/subdir/file.age  | Bin 0 -> 33 bytes
    #| fluff/.age-recipients  |   2 ++
    #| fluff/one.age          | Bin 0 -> 55 bytes
    #| fluff/three.age        | Bin 0 -> 110 bytes
    #| fluff/two.age          | Bin 0 -> 90 bytes
    #| old.gpg                |   3 +++
    #| shared/.age-recipients |   2 ++
    #| stale.age              | Bin 0 -> 55 bytes
    #| subdir/file.age        | Bin 0 -> 33 bytes
    #| 9 files changed, 7 insertions(+)
  }

  expected_log() { setup_log; } # Default log to override as needed

  check_git_log() {
    git_log && expected_log | diff -u "${GITLOG}" - >&2
  }

  setup_id() {
    @mkdir -p "${PREFIX}/$1"
    @cat >"${PREFIX}/$1/.age-recipients"
  }

  setup_secret() {
    [ "$1" = "${1%/*}" ] || @mkdir -p "${PREFIX}/${1%/*}"
    @sed 's/^/age/' >"${PREFIX}/$1.age"
  }

  setup() {
    @git init -q -b main "${PREFIX}"
    @git -C "${PREFIX}" config --local user.name 'Test User'
    @git -C "${PREFIX}" config --local user.email 'test@example.com'
    %putsn 'myself' >"${IDENTITIES_FILE}"
    %text | setup_secret 'subdir/file'
    #|Recipient:myself
    #|:p4ssw0rd
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
    %text >"${PREFIX}/old.gpg"
    #|gpgRecipient:myOldSelf
    #|gpg:very-old-password
    #|gpg:Username: previous-life
    @git -C "${PREFIX}" add .
    @git -C "${PREFIX}" commit -m 'Initial setup' >/dev/null

    # Check setup_log consistency
    git_log
    setup_log | @diff -u - "${GITLOG}"
  }

  cleanup() {
    @rm -rf "${PREFIX}"
    @rm -f "${IDENTITIES_FILE}"
    @rm -rf "${SHELLSPEC_WORKDIR}/clone"
    @rm -rf "${SHELLSPEC_WORKDIR}/secure"
  }

  BeforeEach setup
  AfterEach cleanup

  cat()     { @cat     "$@"; }
  dd()      { @dd      "$@"; }
  diff()    { @diff    "$@"; }
  dirname() { @dirname "$@"; }
  git()     { @git     "$@"; }
  mkdir()   { @mkdir   "$@"; }
  mktemp()  { @mktemp  "$@"; }
  mv()      { @mv      "$@"; }
  rm()      { @rm      "$@"; }
  tr()      { @tr      "$@"; }

  platform_tmpdir() {
    SECURE_TMPDIR="${SHELLSPEC_WORKDIR}/secure"
    @mkdir -p "${SECURE_TMPDIR}"
  }

# Describe 'cmd_copy' is not needed (covered by 'cmd_copy_move')
# Describe 'cmd_copy_move'

  Describe 'cmd_delete'
    DECISION=default

    It 'deletes multiple files at once, prompting before each one'
      Data
        #|y
        #|n
        #|y
      End
      When call cmd_delete stale subdir/file fluff/two
      The status should be success
      The output should equal 'Are you sure you would like to delete stale? [y/n]Are you sure you would like to delete subdir/file? [y/n]Are you sure you would like to delete fluff/two? [y/n]'
      The error should be blank
      The file "${PREFIX}/fluff/two.age" should not be exist
      The file "${PREFIX}/stale.age" should not be exist
      The file "${PREFIX}/subdir/file.age" should be exist
      expected_log() { %text
        #|Remove fluff/two from store.
        #|
        #| fluff/two.age | 4 ----
        #| 1 file changed, 4 deletions(-)
        #|Remove stale from store.
        #|
        #| stale.age | 3 ---
        #| 1 file changed, 3 deletions(-)
        setup_log
      }
      The result of function check_git_log should be successful
    End
  End

  Describe 'cmd_edit'
    It 'uses EDITOR in a dumb terminal'
      unset EDIT_CMD
      EDITOR=false
      TERM=dumb
      VISUAL=true
      When run cmd_edit stale
      The status should equal 1
      The output should be blank
      The error should equal 'Editor "false" exited with code 1'
      expected_file() { %text:expand
        #|ageRecipient:master
        #|ageRecipient:myself
        #|age:0-password
      }
      The contents of file "${PREFIX}/stale.age" should \
        equal "$(expected_file)"
      The result of function check_git_log should be successful
    End

    It 'uses EDITOR when VISUAL is not set'
      unset EDIT_CMD
      EDITOR=false
      TERM=not-dumb
      unset VISUAL
      When run cmd_edit stale
      The status should equal 1
      The output should be blank
      The error should equal 'Editor "false" exited with code 1'
      expected_file() { %text:expand
        #|ageRecipient:master
        #|ageRecipient:myself
        #|age:0-password
      }
      The contents of file "${PREFIX}/stale.age" should \
        equal "$(expected_file)"
      The result of function check_git_log should be successful
    End

    It 'uses VISUAL in a non-dumb terminal'
      unset EDIT_CMD
      EDITOR=true
      TERM=not-dumb
      VISUAL=false
      When run cmd_edit stale
      The status should equal 1
      The output should be blank
      The error should equal 'Editor "false" exited with code 1'
      expected_file() { %text:expand
        #|ageRecipient:master
        #|ageRecipient:myself
        #|age:0-password
      }
      The contents of file "${PREFIX}/stale.age" should \
        equal "$(expected_file)"
      The result of function check_git_log should be successful
    End

    It 'falls back on vi without EDITOR nor visual'
      unset EDIT_CMD
      unset EDITOR
      unset VISUAL
      When run cmd_edit subdir/new
      The status should equal 127
      The output should be blank
      The line 1 of error should include 'not found'
      The line 2 of error should equal 'Editor "vi" exited with code 127'
      The file "${PREFIX}/subdir/new.age" should not be exist
      The file "${PREFIX}/subdir/new.gpg" should not be exist
      The result of function check_git_log should be successful
    End

    It 'reports unchanged file'
      EDIT_CMD=true
      When call cmd_edit stale
      The status should be success
      The output should equal 'Password for stale unchanged.'
      The error should be blank
      expected_file() { %text:expand
        #|ageRecipient:master
        #|ageRecipient:myself
        #|age:0-password
      }
      The contents of file "${PREFIX}/stale.age" should \
        equal "$(expected_file)"
      The result of function check_git_log should be successful
    End

    It 'allows lack of file creation without error'
      EDIT_CMD=true
      When run cmd_edit subdir/new
      The status should be success
      The output should equal 'New password for subdir/new not saved.'
      The error should be blank
      The file "${PREFIX}/subdir/new.age" should not be exist
      The file "${PREFIX}/subdir/new.gpg" should not be exist
      The result of function check_git_log should be successful
    End

    It 'reports editor failure'
      ret42() { return 42; }
      EDIT_CMD=ret42
      When run cmd_edit subdir/new
      The status should equal 42
      The output should be blank
      The error should equal 'Editor "ret42" exited with code 42'
      The file "${PREFIX}/subdir/new.age" should not be exist
      The file "${PREFIX}/subdir/new.gpg" should not be exist
      The result of function check_git_log should be successful
    End
  End

  Describe 'cmd_find'
    grep() { @grep "$@"; }

    It 'interprets the pattern as a regular expression'
      expected_output() { %text
        #|Search pattern: ^o
        #||- (B)fluff(N)
        #||  `- one
        #|`- (R)old(N)
      }
      When call cmd_find '^o'
      The status should be success
      The output should equal "$(expected_output)"
      The error should be blank
      The result of function check_git_log should be successful
    End

    It 'forwards flags to grep'
      expected_output() { %text
        #|Search pattern: -E -i F|I
        #||- (B)extra(N)
        #||  `- (B)subdir(N)
        #||     `- file
        #|`- (B)subdir(N)
        #|   `- file
      }
      When call cmd_find -E -i 'F|I'
      The status should be success
      The output should equal "$(expected_output)"
      The error should be blank
      The result of function check_git_log should be successful
    End
  End

  Describe 'cmd_generate'
    DECISION=default
    OVERWRITE=no
    SHOW=text

    random_chars() { %- 0123456789 ; }

    It 'overwrites after asking for confirmation'
      expected_out() { %text
        #|An entry already exists for subdir/file. Overwrite it? [y/n](B)The generated password for (U)subdir/file(!U) is:(N)
        #|0123456789
      }
      Data 'y'
      When call cmd_generate subdir/file 10
      The status should be success
      The output should equal "$(expected_out)"
      The error should be blank
      expected_file() { %text:expand
        #|ageRecipient:myself
        #|age:0123456789
      }
      The contents of file "${PREFIX}/subdir/file.age" should \
        equal "$(expected_file)"
      expected_log() { %text
        #|Add generated password for subdir/file.
        #|
        #| subdir/file.age | 2 +-
        #| 1 file changed, 1 insertion(+), 1 deletion(-)
        setup_log
      }
      The result of function check_git_log should be successful
    End

    It 'does nothing without confirmation'
      Data 'n'
      When call cmd_generate subdir/file 10
      The status should be success
      The output should equal \
        'An entry already exists for subdir/file. Overwrite it? [y/n]'
      The error should be blank
      The result of function check_git_log should be successful
    End

    It 'cannot overwrite a directory'
      run_test() {
        mkdir -p "${PREFIX}/new-secret.age" && \
        cmd_generate -f new-secret 10
      }
      When run run_test
      The status should equal 1
      The output should be blank
      The error should equal 'Cannot replace directory new-secret.age'
      The result of function git_log should be successful
      The contents of file "${GITLOG}" should equal "$(setup_log)"
    End
  End

  Describe 'cmd_git'
    It 'initializes a clone like a new repository'
      SOURCE="${PREFIX}"
      PREFIX="${SHELLSPEC_WORKDIR}/clone"
      expected_err() { %text:expand
        #|Cloning into '${PREFIX}'...
        #|done.
      }
      When call cmd_git clone "${SOURCE}"
      The status should be success
      The output should be blank
      The error should equal "$(expected_err)"
      The file "${PREFIX}/.gitattributes" should be exist
      The contents of file "${PREFIX}/.gitattributes" should equal \
        '*.age diff=age'
      expected_log() { %text
        #|Configure git repository for age file diff.
        #|
        #| .gitattributes | 1 +
        #| 1 file changed, 1 insertion(+)
        setup_log_bin
      }
      The result of function check_git_log should be successful
      PREFIX="${SOURCE}"
    End
  End

# Describe 'cmd_grep' is not needed (fully covered in pass_spec.sh)

  Describe 'cmd_gitconfig'
    grep() { @grep "$@"; }

    It 'creates a new .gitattributes and configures diff'
      When call cmd_gitconfig
      The status should be success
      The output should be blank
      The error should be blank
      The file "${PREFIX}/.gitattributes" should be exist
      The contents of file "${PREFIX}/.gitattributes" should equal \
        '*.age diff=age'
      expected_log() { %text
        #|Configure git repository for age file diff.
        #|
        #| .gitattributes | 1 +
        #| 1 file changed, 1 insertion(+)
        setup_log_bin
      }
      The result of function check_git_log should be successful
    End

    It 'expands an existing .gitattributes'
      run_test() {
        %putsn '# Existing but empty' >"${PREFIX}/.gitattributes"
        @git -C "${PREFIX}" add .gitattributes >/dev/null
        @git -C "${PREFIX}" commit -m 'Test case setup' >/dev/null
        cmd_gitconfig
      }
      When call run_test
      The status should be success
      The output should be blank
      The error should be blank
      expected_file() { %text
        #|# Existing but empty
        #|*.age diff=age
      }
      The file "${PREFIX}/.gitattributes" should be exist
      The contents of file "${PREFIX}/.gitattributes" should \
        equal "$(expected_file)"
      expected_log() { %text
        #|Configure git repository for age file diff.
        #|
        #| .gitattributes | 1 +
        #| 1 file changed, 1 insertion(+)
        #|Test case setup
        #|
        #| .gitattributes | 1 +
        #| 1 file changed, 1 insertion(+)
        setup_log_bin
      }
      The result of function check_git_log should be successful
    End

    It 'is idempotent'
      run_test() {
        cmd_gitconfig && cmd_gitconfig
      }
      When call run_test
      The status should be success
      The output should be blank
      The error should be blank
      The file "${PREFIX}/.gitattributes" should be exist
      The contents of file "${PREFIX}/.gitattributes" should equal \
        '*.age diff=age'
      expected_log() { %text
        #|Configure git repository for age file diff.
        #|
        #| .gitattributes | 1 +
        #| 1 file changed, 1 insertion(+)
        setup_log_bin
      }
      The result of function check_git_log should be successful
    End
  End

  Describe 'cmd_help'
    It 'displays a help text with pashage-specific supported commands'
      PROGRAM=prg
      When call cmd_help
      The status should be success
      The output should include ' prg copy '
      The output should include ' prg delete '
      The output should include ' prg gitconfig'
      The output should include ' prg move '
      The output should include ' prg random '
    End
  End

  Describe 'cmd_init'
    DECISION=default

    It 're-encrypts the whole store using a recipient ids named like a flag'
      When run cmd_init -- -p 'new-id'
      The status should be success
      The output should equal 'Password store recipients set at store root'
      The error should be blank
      expected_file() { %text
        #|-p
        #|new-id
      }
      The contents of file "${PREFIX}/.age-recipients" should \
        equal "$(expected_file)"
      expected_log() { %text
        #|Set age recipients at store root
        #|
        #| .age-recipients       | 2 ++
        #| extra/subdir/file.age | 3 ++-
        #| stale.age             | 4 ++--
        #| subdir/file.age       | 3 ++-
        #| 4 files changed, 8 insertions(+), 4 deletions(-)
        setup_log
      }
      The result of function check_git_log should be successful
    End
  End

  Describe 'cmd_insert'
    ECHO=no
    MULTILINE=no
    OVERWRITE=no

    It 'inserts several new single-line entries'
      stty() { false; }
      Data
        #|password-1
        #|n
        #|password-2
        #|password-3
      End
      When call cmd_insert -e newdir/pass-1 subdir/file newdir/pass-2
      The status should be success
      The error should be blank
      The output should equal 'Enter password for newdir/pass-1: An entry already exists for subdir/file. Overwrite it? [y/n]Enter password for newdir/pass-2: '
      The contents of file "${PREFIX}/newdir/pass-1.age" \
        should include "age:password-1"
      The contents of file "${PREFIX}/newdir/pass-2.age" \
        should include "age:password-2"
      expected_log() { %text
        #|Add given password for newdir/pass-2 to store.
        #|
        #| newdir/pass-2.age | 2 ++
        #| 1 file changed, 2 insertions(+)
        #|Add given password for newdir/pass-1 to store.
        #|
        #| newdir/pass-1.age | 2 ++
        #| 1 file changed, 2 insertions(+)
        setup_log
      }
      The result of function check_git_log should be successful
    End

    It 'inserts several new multi-line entries'
      stty() { false; }
      Data
        #|password-1
        #| extra spaced line
        #|
        #|y
        #|password-2
        #|	extra tabbed line
        #|
        #|password-3
      End
      When call cmd_insert -m newdir/pass-1 subdir/file newdir/pass-2
      The status should be success
      The error should be blank
      expected_out() { %text
        #|Enter contents of newdir/pass-1 and
        #|press Ctrl+D or enter an empty line when finished:
        #|An entry already exists for subdir/file. Overwrite it? [y/n]Enter contents of subdir/file and
        #|press Ctrl+D or enter an empty line when finished:
        #|Enter contents of newdir/pass-2 and
        #|press Ctrl+D or enter an empty line when finished:
      }
      The output should equal "$(expected_out)"
      expected_file_1() { %text
        #|ageRecipient:myself
        #|age:password-1
        #|age: extra spaced line
      }
      expected_file_2() { %text
        #|ageRecipient:myself
        #|age:password-2
        #|age:	extra tabbed line
      }
      expected_file_3() { %text
        #|ageRecipient:myself
        #|age:password-3
      }
      The contents of file "${PREFIX}/newdir/pass-1.age" \
        should equal "$(expected_file_1)"
      The contents of file "${PREFIX}/subdir/file.age" \
        should equal "$(expected_file_2)"
      The contents of file "${PREFIX}/newdir/pass-2.age" \
        should equal "$(expected_file_3)"
      expected_log() { %text
        #|Add given password for newdir/pass-2 to store.
        #|
        #| newdir/pass-2.age | 2 ++
        #| 1 file changed, 2 insertions(+)
        #|Add given password for subdir/file to store.
        #|
        #| subdir/file.age | 3 ++-
        #| 1 file changed, 2 insertions(+), 1 deletion(-)
        #|Add given password for newdir/pass-1 to store.
        #|
        #| newdir/pass-1.age | 3 +++
        #| 1 file changed, 3 insertions(+)
        setup_log
      }
      The result of function check_git_log should be successful
    End

    It 'inserts a new single-line entry on the second try'
      stty() { :; }
      Data
        #|first try
        #|First Try
        #|pass-word
        #|pass-word
      End
      When call cmd_insert newdir/newpass
      The status should be success
      The error should be blank
      expected_out() { %text | @sed 's/\$$//'
        #|Enter password for newdir/newpass:  $
        #|Retype password for newdir/newpass: $
        #|Passwords don't match$
        #|Enter password for newdir/newpass:  $
        #|Retype password for newdir/newpass: $
      }
      The output should equal "$(expected_out)"
      The contents of file "${PREFIX}/newdir/newpass.age" \
        should include "age:pass-word"
      expected_log() { %text
        #|Add given password for newdir/newpass to store.
        #|
        #| newdir/newpass.age | 2 ++
        #| 1 file changed, 2 insertions(+)
        setup_log
      }
      The result of function check_git_log should be successful
    End

    It 'overwrites an entry after confirmation'
      Data
        #|y
        #|pass-word
      End
      When call cmd_insert -e subdir/file
      The status should be success
      The error should be blank
      The output should equal 'An entry already exists for subdir/file. Overwrite it? [y/n]Enter password for subdir/file: '
      expected_file() { %text
        #|ageRecipient:myself
        #|age:pass-word
      }
      The contents of file "${PREFIX}/subdir/file.age" \
        should equal "$(expected_file)"
      expected_log() { %text
        #|Add given password for subdir/file to store.
        #|
        #| subdir/file.age | 2 +-
        #| 1 file changed, 1 insertion(+), 1 deletion(-)
        setup_log
      }
      The result of function check_git_log should be successful
    End

    It 'does not overwrite an entry without confirmation'
      Data
        #|n
        #|pass-word
      End
      When call cmd_insert -e subdir/file
      The status should be success
      The error should be blank
      The output should equal \
        'An entry already exists for subdir/file. Overwrite it? [y/n]'
      The result of function check_git_log should be successful
    End
  End

  Describe 'cmd_list_or_show'
    SHOW=text

    It 'decrypts a GPG secret in the store'
      GPG=mock-gpg
      When call cmd_list_or_show old
      The status should be success
      The error should be blank
      expected_out() { %text
        #|very-old-password
        #|Username: previous-life
      }
      The output should equal "$(expected_out)"
    End

    It 'displays both list and show usage on parse error with ambiguity'
      PROGRAM=prg
      COMMAND=both
      When run cmd_list_or_show -x
      The status should equal 1
      The output should be blank
      expected_err() { %text
        #|Usage: prg [list] [subfolder]
        #|       prg [show] [--clip[=line-number],-c[line-number] |
        #|                   --qrcode[=line-number],-q[line-number]] pass-name
      }
      The error should equal "$(expected_err)"
    End

    It 'displays list usage on parse error with list command'
      PROGRAM=prg
      COMMAND=list
      When run cmd_list_or_show -x
      The status should equal 1
      The output should be blank
      expected_err() { %text
        #|Usage: prg [list] [subfolder]
      }
      The error should equal "$(expected_err)"
    End

    It 'displays show usage on parse error with show command'
      PROGRAM=prg
      COMMAND=show
      When run cmd_list_or_show -x
      The status should equal 1
      The output should be blank
      expected_err() { %text
        #|Usage: prg [show] [--clip[=line-number],-c[line-number] |
        #|                   --qrcode[=line-number],-q[line-number]] pass-name
      }
      The error should equal "$(expected_err)"
    End
  End

# Describe 'cmd_move' is not needed (covered by 'cmd_copy_move')
# Describe 'cmd_random'
# Describe 'cmd_usage'
# Describe 'cmd_version'

  Describe 'unreachable defensive code'
    # This sections breaks the end-to-end scheme of this file
    # to reach full coverage, by precisely identifying unreachable lines
    # written for defensive programming against internal inconsistencies.

    It 'includes invalid values of SHOW in do_show'
      SHOW='invalid'
      When run do_show
      The status should equal 1
      The output should be blank
      expected_err() { %text
        #|Usage: prg [show] [--clip[=line-number],-c[line-number] |
        #|                   --qrcode[=line-number],-q[line-number]] pass-name
      }
      The error should equal 'Unexpected SHOW value "invalid"'
    End
  End
End
