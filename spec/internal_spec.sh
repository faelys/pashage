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

# This test file covers all internal helper functions,
# These functions are fundemantal so there is no need for mocking,
# except for the interactive path in `yesno`.

Describe 'Internal Helper Functions'
  Include src/pashage.sh
  Set 'errexit:on' 'nounset:on' 'pipefail:on'

  Describe 'check_sneaky_path'
    It 'accept an empty path'
      When run check_sneaky_path ''
      The status should be success
      The error should be blank
      The output should be blank
    End

    It 'accepts a file name'
      When run check_sneaky_path 'a'
      The status should be success
      The error should be blank
      The output should be blank
    End

    It 'accepts an absolute path'
      When run check_sneaky_path '/a/b/c'
      The status should be success
      The error should be blank
      The output should be blank
    End

    It 'accepts a relative path'
      When run check_sneaky_path 'a/b/c/'
      The status should be success
      The error should be blank
      The output should be blank
    End

    It 'aborts when .. is a path component'
      When run check_sneaky_path 'a/../b'
      The error should equal 'Encountered path considered sneaky: "a/../b"'
      The output should be blank
      The status should equal 1
    End

    It 'aborts when .. is a path prefix'
      When run check_sneaky_path '../a/b'
      The error should equal 'Encountered path considered sneaky: "../a/b"'
      The output should be blank
      The status should equal 1
    End

    It 'aborts when .. is a path suffix'
      When run check_sneaky_path '/a/..'
      The error should equal 'Encountered path considered sneaky: "/a/.."'
      The output should be blank
      The status should equal 1
    End

    It 'aborts when .. is the whole path'
      When run check_sneaky_path '..'
      The error should equal 'Encountered path considered sneaky: ".."'
      The output should be blank
      The status should equal 1
    End
  End

  Describe 'check_sneaky_paths'
    It 'aborts when all paths are bad'
      When run check_sneaky_paths ../a b/../c
      The error should equal 'Encountered path considered sneaky: "../a"'
      The output should be blank
      The status should equal 1
    End

    It 'accepts several good paths'
      When run check_sneaky_paths a b/c /d/e/f
      The status should be success
      The error should be blank
      The output should be blank
    End

    It 'accepts an empty argument list'
      When run check_sneaky_paths
      The status should be success
      The error should be blank
      The output should be blank
    End

    It 'aborts when a single path is bad'
      When run check_sneaky_paths a b/../c /d/e/f
      The error should equal 'Encountered path considered sneaky: "b/../c"'
      The output should be blank
      The status should equal 1
    End
  End

  Describe 'checked'
    echo_ret() { printf '%s\n' "$1"; return $2; }

    It 'aborts on command failure and reports it'
      When run checked echo_ret 'it runs' 42
      The output should equal 'it runs'
      The error should equal 'Fatal(42): echo_ret it runs 42'
      The status should equal 42
    End

    It 'continues silently when the command is successful'
      When run checked echo_ret 'it runs' 0
      The status should be success
      The output should equal 'it runs'
      The error should be blank
    End
  End

  Specify 'die'
    When run die Message Word
    The error should equal 'Message Word'
    The output should be blank
    The status should equal 1
  End

  Describe 'glob_exists'
    It 'answers y when the glob matches something'
      When call glob_exists /*
      The status should be success
      The variable ANSWER should equal y
    End

    It 'answers n when the glob does not match anything'
      When call glob_exists non-existent/*
      The status should be success
      The variable ANSWER should equal n
    End
  End

  Describe 'set_LOCAL_RECIPIENT_FILE'
    PREFIX="${SHELLSPEC_WORKDIR}/prefix/store"
    setup() {
      @mkdir -p "${PREFIX}/subdir/subsub" "${PREFIX}/special"
      echo "Outside recipient" >"${PREFIX}/../.age-recipients"
      echo "Toplevel recipient" >"${PREFIX}/.age-recipients"
      echo "Subdir recipient" >"${PREFIX}/subdir/.age-recipients"
    }
    cleanup() { @rm -rf "${PREFIX}"; }

    BeforeEach 'setup'
    AfterEach 'cleanup'

    It 'returns root from root'
      When call set_LOCAL_RECIPIENT_FILE foo
      The status should be success
      The variable LOCAL_RECIPIENT_FILE should equal \
        "${PREFIX}/.age-recipients"
    End

    It 'returns root from unmarked subdirectory'
      When call set_LOCAL_RECIPIENT_FILE special/foo
      The status should be success
      The variable LOCAL_RECIPIENT_FILE should equal \
        "${PREFIX}/.age-recipients"
    End

    It 'returns subdirectory from itself'
      When call set_LOCAL_RECIPIENT_FILE subdir/foo
      The status should be success
      The variable LOCAL_RECIPIENT_FILE should equal \
        "${PREFIX}/subdir/.age-recipients"
    End

    It 'returns subdirectory from sub-subdirectory'
      When call set_LOCAL_RECIPIENT_FILE subdir/subsub/foo
      The status should be success
      The variable LOCAL_RECIPIENT_FILE should equal \
        "${PREFIX}/subdir/.age-recipients"
    End

    setup() {
      @mkdir -p "${PREFIX}/subdir/subsub" "${PREFIX}/special"
      echo "Outside recipient" >"${PREFIX}/../.age-recipients"
      echo "Subdir recipient" >"${PREFIX}/subdir/.age-recipients"
    }

    It 'returns nothing from empty root'
      When call set_LOCAL_RECIPIENT_FILE foo
      The status should be success
      The variable LOCAL_RECIPIENT_FILE should equal ''
    End

    It 'returns nothing from unmarked subdirectory below empty root'
      When call set_LOCAL_RECIPIENT_FILE special/foo
      The status should be success
      The variable LOCAL_RECIPIENT_FILE should equal ''
    End

    It 'returns subdirectory from itself even under empty root'
      When call set_LOCAL_RECIPIENT_FILE subdir/foo
      The status should be success
      The variable LOCAL_RECIPIENT_FILE should equal \
        "${PREFIX}/subdir/.age-recipients"
    End

    It 'returns subdirectory from sub-subdirectory even under empty root'
      When call set_LOCAL_RECIPIENT_FILE subdir/subsub/foo
      The status should be success
      The variable LOCAL_RECIPIENT_FILE should equal \
        "${PREFIX}/subdir/.age-recipients"
    End
  End

  Describe 'strlen'
    It 'accepts an ASCII and returns its length'
      When call strlen 'abc def'
      The output should equal 7
    End

    It 'accepts an empty string and returns 0'
      When call strlen ''
      The output should equal 0
    End
  End

  Describe 'yesno'
    Describe 'Without stty'
      It 'accepts an uppercase N'
        Data 'N'
        When call yesno 'prompt'
        The status should be success
        The output should equal 'prompt [y/n]'
        The variable ANSWER should equal 'N'
      End

      It 'accepts an uppercase Y'
        Data 'YES'
        When call yesno 'prompt'
        The status should be success
        The output should equal 'prompt [y/n]'
        The variable ANSWER should equal 'y'
      End
    End

    Describe 'Dumb terminal with stty'
      stty() { false; }

      It 'accepts a lowercase N'
        Data 'no'
        When call yesno 'prompt'
        The status should be success
        The output should equal 'prompt [y/n]'
        The variable ANSWER should equal 'n'
      End

      It 'accepts an uppercase Y'
        Data 'Y'
        When call yesno 'prompt'
        The status should be success
        The output should equal 'prompt [y/n]'
        The variable ANSWER should equal 'y'
      End
    End

    Describe 'Mocking a terminal'
      setup() {
        %putsn x >|"${SHELLSPEC_WORKDIR}/first-dd"
      }
      stty() { :; }
      dd() {
        if [ -f "${SHELLSPEC_WORKDIR}/first-dd" ]; then
          %puts x
          @rm "${SHELLSPEC_WORKDIR}/first-dd"
        else
          %puts y
        fi
      }

      BeforeEach setup

      It 'accepts a lowercase Y after bad input'
        When call yesno 'prompt'
        The status should be success
        The output should equal 'prompt [y/n]'
        The variable ANSWER should equal 'y'
      End
    End
  End
End
