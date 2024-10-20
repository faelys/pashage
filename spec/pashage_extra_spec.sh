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
    #| shared/.age-recipients | 2 ++
    #| stale.age              | 3 +++
    #| subdir/file.age        | 2 ++
    #| 8 files changed, 23 insertions(+)
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
    @git -C "${PREFIX}" add .
    @git -C "${PREFIX}" commit -m 'Initial setup' >/dev/null

    # Check setup_log consistency
    git_log
    setup_log | @diff -u - "${GITLOG}"
  }

  cleanup() {
    @rm -rf "${PREFIX}"
    @rm -f "${IDENTITIES_FILE}"
    @rm -rf "${SHELLSPEC_WORKDIR}/secure"
  }

  BeforeEach setup
  AfterEach cleanup

  cat()    { @cat     "$@"; }
  diff()   { @diff    "$@"; }
  git()    { @git     "$@"; }
  mktemp() { @mktemp  "$@"; }
  rm()     { @rm      "$@"; }

  platform_tmpdir() {
    SECURE_TMPDIR="${SHELLSPEC_WORKDIR}/secure"
    @mkdir -p "${SECURE_TMPDIR}"
  }

# Describe 'cmd_copy' is not needed (covered by 'cmd_copy_move')
# Describe 'cmd_copy_move'
# Describe 'cmd_delete'

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

# Describe 'cmd_find'
# Describe 'cmd_generate'
# Describe 'cmd_git'
# Describe 'cmd_grep'
# Describe 'cmd_gitconfig'
# Describe 'cmd_help'
# Describe 'cmd_init'
# Describe 'cmd_insert'
# Describe 'cmd_list_or_show'
# Describe 'cmd_move' is not needed (covered by 'cmd_copy_move')
# Describe 'cmd_random'
# Describe 'cmd_usage'
# Describe 'cmd_version'
End
