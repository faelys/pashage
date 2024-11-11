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

# This test file fully covers all SCM functions,
# both integrated with git and without a repository.

Describe 'Integrated SCM Functions'
  Include src/pashage.sh
  if [ "${SHELLSPEC_SHELL_TYPE}" = sh ]; then
    Set 'errexit:on' 'nounset:on'
  else
    Set 'errexit:on' 'nounset:on' 'pipefail:on'
  fi
  PREFIX="${SHELLSPEC_WORKDIR}/repo"

  git() { @git "$@"; }

  git_log() {
    @git -C "${PREFIX}" log --format='%s' >|"${SHELLSPEC_WORKDIR}/git-log.txt"
  }

  git_status() {
    @git -C "${PREFIX}" status --porcelain \
      >|"${SHELLSPEC_WORKDIR}/git-status.txt"
  }

  setup() {
    @git init -q -b main "${PREFIX}"
    @git -C "${PREFIX}" config --local user.name 'Test User'
    @git -C "${PREFIX}" config --local user.email 'test@example.com'
    @mkdir "${PREFIX}/subdir"
    %putsn data >"${PREFIX}/subdir/file.txt"
    @git -C "${PREFIX}" add subdir/file.txt
    @git -C "${PREFIX}" commit -m 'Setup a file' >/dev/null
  }

  cleanup() {
    @rm -rf "${PREFIX}"
  }

  BeforeEach setup
  AfterEach cleanup

  Describe 'scm_add'
    It 'adds an untracked file'
      testcase() {
        %putsn other-data >"${PREFIX}/untracked.txt"
        scm_add untracked.txt
      }
      When call testcase
      The status should be success
      The output should be blank
      The result of function git_status should be successful
      The contents of file "${SHELLSPEC_WORKDIR}/git-status.txt" \
        should equal 'A  untracked.txt'
    End

    It 'adds changes to a tracked file'
      testcase() {
        %putsn other-data >|"${PREFIX}/subdir/file.txt"
        scm_add subdir/file.txt
      }
      When call testcase
      The status should be success
      The output should be blank
      The result of function git_status should be successful
      The contents of file "${SHELLSPEC_WORKDIR}/git-status.txt" \
        should equal 'M  subdir/file.txt'
    End
  End

  Describe 'scm_begin'
    It 'is successful on a clean repository'
      When call scm_begin
      The output should be blank
      The status should be successful
    End

    It 'aborts when an untracked file exists'
      testcase() {
        %putsn other-data >"${PREFIX}/untracked.txt"
        scm_begin
      }
      When run testcase
      The status should equal 1
      The error should equal 'There are already pending changes.'
    End

    It 'aborts when a tracked file is modified'
      testcase() {
        %putsn other-data >|"${PREFIX}/subdir/file.txt"
        scm_begin
      }
      When run testcase
      The status should equal 1
      The error should equal 'There are already pending changes.'
    End

    It 'aborts when there are uncommitted changes'
      testcase() {
        %putsn other-data >|"${PREFIX}/subdir/file.txt"
        scm_add subdir/file.txt
        scm_begin
      }
      When run testcase
      The status should equal 1
      The error should equal 'There are already pending changes.'
    End
  End

  Describe 'scm_commit'
    It 'commits a new file'
      testcase() {
        scm_begin
        %putsn other-data >"${PREFIX}/new.txt"
        scm_add new.txt
        scm_commit 'New file'
      }
      expected_log() { %text
        #|New file
        #|Setup a file
      }
      When call testcase
      The output should be blank
      The status should be successful
      The result of function git_log should be successful
      The contents of file "${SHELLSPEC_WORKDIR}/git-log.txt" \
        should equal "$(expected_log)"
    End

    It 'does nothing without scm_add'
      testcase() {
        scm_begin
        %putsn other-data >"${PREFIX}/new.txt"
        scm_commit 'Nothing'
      }
      When call testcase
      The output should be blank
      The status should be successful
      The result of function git_log should be successful
      The contents of file "${SHELLSPEC_WORKDIR}/git-log.txt" \
        should equal "Setup a file"
      The result of function git_status should be successful
      The contents of file "${SHELLSPEC_WORKDIR}/git-status.txt" \
        should equal "?? new.txt"
    End
  End

  Describe 'scm_cp'
    cp() { @cp "$@"; }

    It 'creates and adds a file'
      When call scm_cp subdir/file.txt file-copy.txt
      The status should be success
      The output should be blank
      The contents of file "${PREFIX}/subdir/file.txt" should equal 'data'
      The contents of file "${PREFIX}/file-copy.txt" should equal 'data'
      The result of function git_status should be successful
      The contents of file "${SHELLSPEC_WORKDIR}/git-status.txt" \
        should equal "A  file-copy.txt"
    End

    It 'copies and adds a directory recursively'
      When call scm_cp subdir newdir
      The status should be success
      The output should be blank
      The contents of file "${PREFIX}/subdir/file.txt" should equal 'data'
      The contents of file "${PREFIX}/newdir/file.txt" should equal 'data'
      The result of function git_status should be successful
      The contents of file "${SHELLSPEC_WORKDIR}/git-status.txt" \
        should equal "A  newdir/file.txt"
    End
  End

  Describe 'scm_del'
    rm() { @rm "$@"; }

    It 'deletes a file'
      When call scm_del subdir/file.txt
      The status should be success
      The output should be blank
      The file "${PREFIX}/subdir/file.txt" should not be exist
      The result of function git_status should be successful
      The contents of file "${SHELLSPEC_WORKDIR}/git-status.txt" \
        should equal "D  subdir/file.txt"
    End

    It 'deletes a directory recursively'
      When call scm_del subdir
      The status should be success
      The output should be blank
      The directory "${PREFIX}/subdir" should not be exist
      The result of function git_status should be successful
      The contents of file "${SHELLSPEC_WORKDIR}/git-status.txt" \
        should equal "D  subdir/file.txt"
    End
  End

  Describe 'scm_mv'
    mv() { @mv "$@"; }

    It 'moves a file and records the move'
      When call scm_mv subdir/file.txt file.txt
      The status should be success
      The output should be blank
      The file "${PREFIX}/subdir/file.txt" should not be exist
      The contents of file "${PREFIX}/file.txt" should equal 'data'
      The result of function git_status should be successful
      The contents of file "${SHELLSPEC_WORKDIR}/git-status.txt" \
        should equal 'R  subdir/file.txt -> file.txt'
    End

    It 'moves a directory recursively and records the move'
      When call scm_mv subdir newdir
      The status should be success
      The output should be blank
      The directory "${PREFIX}/subdir" should not be exist
      The contents of file "${PREFIX}/newdir/file.txt" should equal 'data'
      The result of function git_status should be successful
      The contents of file "${SHELLSPEC_WORKDIR}/git-status.txt" \
        should equal 'R  subdir/file.txt -> newdir/file.txt'
    End
  End

  Describe 'scm_rm'
    rm() { @rm "$@"; }

    It 'removes a file'
      When call scm_rm subdir/file.txt
      The status should be success
      The output should be blank
      The file "${PREFIX}/subdir/file.txt" should not be exist
      The result of function git_status should be successful
      The contents of file "${SHELLSPEC_WORKDIR}/git-status.txt" \
        should equal 'D  subdir/file.txt'
    End

    It 'removes a directory recursively'
      When call scm_rm subdir
      The status should be success
      The output should be blank
      The directory "${PREFIX}/subdir" should not be exist
      The result of function git_status should be successful
      The contents of file "${SHELLSPEC_WORKDIR}/git-status.txt" \
        should equal 'D  subdir/file.txt'
    End
  End
End

Describe 'Integrated SCM Functions without SCM'
  Include src/pashage.sh
  if [ "${SHELLSPEC_SHELL_TYPE}" = sh ]; then
    Set 'errexit:on' 'nounset:on'
  else
    Set 'errexit:on' 'nounset:on' 'pipefail:on'
  fi
  PREFIX="${SHELLSPEC_WORKDIR}/repo"

  setup() {
    @mkdir -p "${PREFIX}/subdir"
    %putsn data >"${PREFIX}/subdir/file.txt"
  }

  cleanup() {
    @rm -rf "${PREFIX}"
  }

  BeforeEach setup
  AfterEach cleanup

  Describe 'scm_add'
    It 'does nothing'
      When call scm_add untracked.txt
      The output should be blank
      The status should be successful
    End
  End

  Describe 'scm_begin'
    It 'does nothing'
      When call scm_begin
      The output should be blank
      The status should be successful
    End

    It 'does nothing even when an untracked file exists'
      testcase() {
        %putsn other-data >"${PREFIX}/untracked.txt"
        scm_begin
      }
      When run testcase
      The output should be blank
      The status should be successful
    End
  End

  Describe 'scm_commit'
    It 'does nothing even with a new file added'
      testcase() {
        scm_begin
        %putsn other-data >"${PREFIX}/new.txt"
        scm_add new.txt
        scm_commit 'New file'
      }
      When call testcase
      The output should be blank
      The status should be successful
    End
  End

  Describe 'scm_cp'
    cp() { @cp "$@"; }

    It 'creates a file'
      When call scm_cp subdir/file.txt file-copy.txt
      The status should be success
      The output should be blank
      The contents of file "${PREFIX}/subdir/file.txt" should equal 'data'
      The contents of file "${PREFIX}/file-copy.txt" should equal 'data'
    End

    It 'copies a directory recursively'
      When call scm_cp subdir newdir
      The status should be success
      The output should be blank
      The contents of file "${PREFIX}/subdir/file.txt" should equal 'data'
      The contents of file "${PREFIX}/newdir/file.txt" should equal 'data'
    End
  End

  Describe 'scm_del'
    It 'does nothing with a file'
      When call scm_del subdir/file.txt
      The status should be success
      The output should be blank
      The contents of file "${PREFIX}/subdir/file.txt" should equal 'data'
    End

    It 'does nothing with a directory'
      When call scm_del subdir
      The status should be success
      The output should be blank
      The contents of file "${PREFIX}/subdir/file.txt" should equal 'data'
    End
  End

  Describe 'scm_mv'
    mv() { @mv "$@"; }

    It 'moves a file'
      When call scm_mv subdir/file.txt file.txt
      The status should be success
      The output should be blank
      The file "${PREFIX}/subdir/file.txt" should not be exist
      The contents of file "${PREFIX}/file.txt" should equal 'data'
    End

    It 'moves a directory recursively'
      When call scm_mv subdir newdir
      The status should be success
      The output should be blank
      The directory "${PREFIX}/subdir" should not be exist
      The contents of file "${PREFIX}/newdir/file.txt" should equal 'data'
    End
  End

  Describe 'scm_rm'
    rm() { @rm "$@"; }

    It 'removes a file'
      When call scm_rm subdir/file.txt
      The status should be success
      The output should be blank
      The file "${PREFIX}/subdir/file.txt" should not be exist
    End

    It 'removes a directory recursively'
      When call scm_rm subdir
      The status should be success
      The output should be blank
      The directory "${PREFIX}/subdir" should not be exist
    End
  End
End
