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

# This test file fully covers all action functions in isolation,
# with all interactions fully mocked.

Describe 'Action Functions'
  Include src/pashage.sh
  if [ "${SHELLSPEC_SHELL_TYPE}" = sh ]; then
    Set 'errexit:on' 'nounset:on'
  else
    Set 'errexit:on' 'nounset:on' 'pipefail:on'
  fi

  Describe 'do_copy_move'
    DECISION=default
    OVERWRITE=yes
    PREFIX="${SHELLSPEC_WORKDIR}/prefix"

    ACTION=Move
    SCM_ACTION=scm_mv

    do_decrypt() {
      mocklog do_decrypt "$@"
      %putsn data
    }

    do_encrypt() {
      @cat >/dev/null
      mocklog do_encrypt "$@"
    }

    basename() { @basename "$@"; }
    cat() { @cat "$@"; }
    dirname() { @dirname "$@"; }

    mkdir() { mocklog mkdir "$@"; }
    scm_add() { mocklog scm_add "$@"; }
    scm_begin() { mocklog scm_begin "$@"; }
    scm_commit() { mocklog scm_commit "$@"; }
    scm_cp() { mocklog scm_cp "$@"; }
    scm_mv() { mocklog scm_mv "$@"; }
    scm_rm() { mocklog scm_rm "$@"; }

    setup() {
      @mkdir -p "${PREFIX}/sub/bare/sub" "${PREFIX}/subdir/notes.txt"
      %putsn 'identity 1' >"${PREFIX}/.age-recipients"
      %putsn 'identity 2' >"${PREFIX}/sub/.age-recipients"
      %putsn 'identity 2' >"${PREFIX}/subdir/.age-recipients"
      %putsn data >"${PREFIX}/sub/secret.age"
      %putsn data >"${PREFIX}/sub/bare/deep.age"
      %putsn data >"${PREFIX}/sub/bare/sub/deepest.age"
      %putsn data >"${PREFIX}/subdir/lower.age"
      %putsn data >"${PREFIX}/root.age"
      %putsn data >"${PREFIX}/notes.txt"
    }

    cleanup() {
      @rm -rf "${PREFIX}"
    }

    BeforeEach setup
    AfterEach cleanup

    It 'renames a file without re-encrypting'
      result() {
        %text:expand
        #|$ mkdir -p -- ${PREFIX}/sub
        #|$ scm_begin
        #|$ scm_mv sub/secret.age sub/renamed.age
        #|$ scm_commit Move sub/secret.age to sub/renamed.age
      }
      When call do_copy_move sub/secret sub/renamed
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 're-encrypts when copying to another identity'
      ACTION=Copy
      SCM_ACTION=scm_cp
      result() {
        %text:expand
        #|$ scm_begin
        #|$ do_decrypt ${PREFIX}/root.age
        #|$ do_encrypt sub/root.age
        #|$ scm_add sub/root.age
        #|$ scm_commit Copy root.age to sub/root.age
      }
      When call do_copy_move root sub/
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'accepts explicit .age extensions'
      ACTION=Copy
      SCM_ACTION=scm_cp
      result() {
        %text:expand
        #|$ mkdir -p -- ${PREFIX}/sub
        #|$ scm_begin
        #|$ do_decrypt ${PREFIX}/root.age
        #|$ do_encrypt sub/moved.age
        #|$ scm_add sub/moved.age
        #|$ scm_commit Copy root.age to sub/moved.age
      }
      When call do_copy_move root.age sub/moved.age
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'can be prevented from re-encrypting when copying to another identity'
      DECISION=keep
      ACTION=Copy
      SCM_ACTION=scm_cp
      result() { %text
        #|$ scm_begin
        #|$ scm_cp root.age sub/root.age
        #|$ scm_commit Copy root.age to sub/root.age
      }
      When call do_copy_move root sub/
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'does not re-encrypt a non-encrypted file'
      result() { %text
        #|$ scm_begin
        #|$ scm_mv notes.txt sub/notes.txt
        #|$ scm_commit Move notes.txt to sub/notes.txt
      }
      When call do_copy_move notes.txt sub/
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'does not re-encrypt a non-encrypted file even when forced'
      DECISION=force
      result() { %text
        #|$ scm_begin
        #|$ scm_mv notes.txt sub/notes.txt
        #|$ scm_commit Move notes.txt to sub/notes.txt
      }
      When call do_copy_move notes.txt sub/
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'moves a file without re-encrypting to another directory'
      result() { %text
        #|$ scm_begin
        #|$ scm_mv sub/secret.age subdir/secret.age
        #|$ scm_commit Move sub/secret.age to subdir/secret.age
      }
      When call do_copy_move sub/secret subdir
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'asks confirmation before overwriting a file'
      OVERWRITE=no
      rm() { mocklog rm "$@"; }
      yesno() {
        mocklog yesno "$@"
        ANSWER=y
      }
      result() {
        %text:expand
        #|$ mkdir -p -- ${PREFIX}/sub
        #|$ scm_begin
        #|$ yesno sub/secret.age already exists. Overwrite?
        #|$ rm -f -- ${PREFIX}/sub/secret.age
        #|$ do_decrypt ${PREFIX}/root.age
        #|$ do_encrypt sub/secret.age
        #|$ scm_rm root.age
        #|$ scm_add sub/secret.age
        #|$ scm_commit Move root.age to sub/secret.age
      }
      When call do_copy_move root sub/secret
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'moves a whole directory with identity'
      result() {
        %text:expand
        #|$ scm_begin
        #|$ mkdir -p -- ${PREFIX}/subdir/sub
        #|$ scm_mv sub/.age-recipients subdir/sub/.age-recipients
        #|$ mkdir -p -- ${PREFIX}/subdir/sub/bare
        #|$ scm_mv sub/bare/deep.age subdir/sub/bare/deep.age
        #|$ mkdir -p -- ${PREFIX}/subdir/sub/bare/sub
        #|$ scm_mv sub/bare/sub/deepest.age subdir/sub/bare/sub/deepest.age
        #|$ scm_mv sub/secret.age subdir/sub/secret.age
        #|$ scm_commit Move sub/ to subdir/sub/
      }
      When call do_copy_move sub subdir/
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'recursively moves files to a directory with the same identity'
      result() {
        %text:expand
        #|$ scm_begin
        #|$ mkdir -p -- ${PREFIX}/subdir/new-bare
        #|$ scm_mv sub/bare/deep.age subdir/new-bare/deep.age
        #|$ mkdir -p -- ${PREFIX}/subdir/new-bare/sub
        #|$ scm_mv sub/bare/sub/deepest.age subdir/new-bare/sub/deepest.age
        #|$ scm_commit Move sub/bare/ to subdir/new-bare/
      }
      When call do_copy_move sub/bare subdir/new-bare
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'recursively re-encrypts a directory'
      result() {
        %text:expand
        #|$ scm_begin
        #|$ mkdir -p -- ${PREFIX}/new-bare
        #|$ do_decrypt ${PREFIX}/sub/bare/deep.age
        #|$ do_encrypt new-bare/deep.age
        #|$ scm_rm sub/bare/deep.age
        #|$ scm_add new-bare/deep.age
        #|$ mkdir -p -- ${PREFIX}/new-bare/sub
        #|$ do_decrypt ${PREFIX}/sub/bare/sub/deepest.age
        #|$ do_encrypt new-bare/sub/deepest.age
        #|$ scm_rm sub/bare/sub/deepest.age
        #|$ scm_add new-bare/sub/deepest.age
        #|$ scm_commit Move sub/bare/ to new-bare/
      }
      When call do_copy_move sub/bare new-bare
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'recursively re-encrypts a directory with the same identity when forced'
      DECISION=force
      result() {
        %text:expand
        #|$ scm_begin
        #|$ mkdir -p -- ${PREFIX}/subdir/new-bare
        #|$ do_decrypt ${PREFIX}/sub/bare/deep.age
        #|$ do_encrypt subdir/new-bare/deep.age
        #|$ scm_rm sub/bare/deep.age
        #|$ scm_add subdir/new-bare/deep.age
        #|$ mkdir -p -- ${PREFIX}/subdir/new-bare/sub
        #|$ do_decrypt ${PREFIX}/sub/bare/sub/deepest.age
        #|$ do_encrypt subdir/new-bare/sub/deepest.age
        #|$ scm_rm sub/bare/sub/deepest.age
        #|$ scm_add subdir/new-bare/sub/deepest.age
        #|$ scm_commit Move sub/bare/ to subdir/new-bare/
      }
      When call do_copy_move sub/bare subdir/new-bare
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'interactively re-enecrypts or copies files from a directory'
      DECISION=interactive
      ACTION=Copy
      SCM_ACTION=scm_cp
      YESNO_NEXT=n
      yesno() {
        mocklog yesno "$@"
        ANSWER="${YESNO_NEXT}"
        YESNO_NEXT=y
      }
      result() {
        %text:expand
        #|$ scm_begin
        #|$ mkdir -p -- ${PREFIX}/subdir/new-bare
        #|$ yesno Reencrypt sub/bare/deep into subdir/new-bare/deep?
        #|$ scm_cp sub/bare/deep.age subdir/new-bare/deep.age
        #|$ mkdir -p -- ${PREFIX}/subdir/new-bare/sub
        #|$ yesno Reencrypt sub/bare/sub/deepest into subdir/new-bare/sub/deepest?
        #|$ do_decrypt ${PREFIX}/sub/bare/sub/deepest.age
        #|$ do_encrypt subdir/new-bare/sub/deepest.age
        #|$ scm_add subdir/new-bare/sub/deepest.age
        #|$ scm_commit Copy sub/bare/ to subdir/new-bare/
      }
      When call do_copy_move sub/bare subdir/new-bare
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'reports a file masqueraded as a directory'
      When run do_copy_move root.age/ subdir
      The output should be blank
      The error should equal 'Error: root.age/ is not in the password store.'
      The status should equal 1
    End

    It 'reports non-existent source'
      When run do_copy_move nonexistent subdir
      The output should be blank
      The error should equal 'Error: nonexistent is not in the password store.'
      The status should equal 1
    End

    It 'cannot merge similarly-named directories'
      When run do_copy_move sub/bare/sub /
      The output should be blank
      The error should equal 'Error: / already contains sub'
      The status should equal 1
    End

    It 'cannot move a directory into a file'
      When run do_copy_move sub/ root.age
      The output should be blank
      The error should equal 'Error: root.age is not a directory'
      The status should equal 1
    End

    It 'cannot overwrite a directory with a file'
      When run do_copy_move notes.txt subdir
      The output should be blank
      The error should equal 'Error: subdir already contains notes.txt/'
      The status should equal 1
    End

    # Unreachable branches in do_copy_move_file, defensively implemented
    It 'defensively avois re-encrypting'
      DECISION=keep
      result() {
        %text
        #|$ scm_mv root.age non-existent
      }
      When run do_copy_move_file root.age non-existent
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'defensively checks internal consistency of DECISION'
      DECISION=garbage
      When run do_copy_move_file root.age non-existent
      The output should be blank
      The error should equal 'Unexpected DECISION value "garbage"'
      The status should equal 1
    End
  End

  Specify 'do_decrypt'
    AGE=age
    age() {
      mocklog age "$@"
      %= 'cleartext'
    }

    IDENTITIES_FILE='/path/to/identity'
    When call do_decrypt '/path/to/encrypted/file.age'
    The status should be success
    The output should equal 'cleartext'
    The error should equal \
      '$ age -d -i /path/to/identity -- /path/to/encrypted/file.age'
  End

  Describe 'do_decrypt_gpg'
    It 'uses gpg when agent is not available'
      gpg() { mocklog gpg "$@"; }
      unset GPG_AGENT_INFO
      unset GPG
      When call do_decrypt_gpg /path/to/encrypted/file.gpg
      The status should be success
      The error should equal \
        '$ gpg -d --quiet --yes --compress-algo=none --no-encrypt-to -- /path/to/encrypted/file.gpg'
    End

    It 'uses gpg when agent is available'
      gpg() { mocklog gpg "$@"; }
      GPG_AGENT_INFO=agent-info
      unset GPG
      When call do_decrypt_gpg /path/to/encrypted/file.gpg
      The status should be success
      The error should equal \
        '$ gpg -d --quiet --yes --compress-algo=none --no-encrypt-to --batch --use-agent -- /path/to/encrypted/file.gpg'
    End

    It 'uses gpg2'
      gpg2() { mocklog gpg2 "$@"; }
      unset GPG_AGENT_INFO
      unset GPG
      When call do_decrypt_gpg /path/to/encrypted/file.gpg
      The status should be success
      The error should equal \
        '$ gpg2 -d --quiet --yes --compress-algo=none --no-encrypt-to --batch --use-agent -- /path/to/encrypted/file.gpg'
    End

    It 'uses user-provided command'
      user_cmd() { mocklog user_cmd "$@"; }
      unset GPG_AGENT_INFO
      GPG=user_cmd
      When call do_decrypt_gpg /path/to/encrypted/file.gpg
      The status should be success
      The error should equal \
        '$ user_cmd -d --quiet --yes --compress-algo=none --no-encrypt-to -- /path/to/encrypted/file.gpg'
    End

    It 'bails out when command cannot be guessed'
      unset GPG
      When run do_decrypt_gpg /path/to/encrypted/file.gpg
      The error should equal 'GPG does not seem available'
      The status should equal 1
    End
  End

  Describe 'do_deinit'
    DECISION=default
    PREFIX="${SHELLSPEC_WORKDIR}/prefix"

    do_reencrypt_dir() { mocklog do_reencrypt_dir "$@"; }
    scm_begin() { mocklog scm_begin "$@"; }
    scm_commit() { mocklog scm_commit "$@"; }
    scm_rm() { mocklog scm_rm "$@"; }

    setup() {
      @mkdir -p "${PREFIX}/empty" "${PREFIX}/sub"
      %putsn data > "${PREFIX}/.age-recipients"
      %putsn data > "${PREFIX}/sub/.age-recipients"
    }

    cleanup() {
      @rm -rf "${PREFIX}"
    }

    BeforeEach setup
    AfterEach cleanup

    It 'de-initializes the whole store'
      result() {
        %text:expand
        #|$ scm_begin
        #|$ scm_rm .age-recipients
        #|$ do_reencrypt_dir ${PREFIX}/
        #|$ scm_commit Deinitialize store root
      }
      When call do_deinit ''
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'de-initializes a subdirectory'
      result() {
        %text:expand
        #|$ scm_begin
        #|$ scm_rm sub/.age-recipients
        #|$ do_reencrypt_dir ${PREFIX}/sub
        #|$ scm_commit Deinitialize sub
      }
      When call do_deinit sub
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'can de-initialize without re-encryption'
      DECISION=keep
      result() {
        %text:expand
        #|$ scm_begin
        #|$ scm_rm sub/.age-recipients
        #|$ scm_commit Deinitialize sub
      }
      When call do_deinit sub
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'reports impossible de-initialization'
      When run do_deinit non-existent
      The output should be blank
      The error should equal 'No existing recipient to remove at non-existent'
      The status should equal 1
    End
  End

  Describe 'do_delete'
    DECISION=force
    RECURSIVE=yes
    PREFIX="${SHELLSPEC_WORKDIR}/prefix"

    dirname() { @dirname "$@"; }
    scm_begin() { mocklog scm_begin "$@"; }
    scm_commit() { mocklog scm_commit "$@"; }
    scm_rm() { mocklog scm_rm "$@"; }

    setup() {
      @mkdir -p "${PREFIX}/empty" "${PREFIX}/sub"
      %putsn data > "${PREFIX}/non-encrypted"
      %putsn data > "${PREFIX}/sub.age"
      %putsn data > "${PREFIX}/sub/entry.age"
    }

    cleanup() {
      @rm -rf "${PREFIX}"
    }

    BeforeEach setup
    AfterEach cleanup

    It 'deletes a file after confirmation'
      DECISION=default
      yesno() {
        mocklog yesno "$@"
        ANSWER=y
      }
      result() {
        %text:expand
        #|$ yesno Are you sure you would like to delete sub/entry?
        #|$ scm_begin
        #|$ scm_rm sub/entry.age
        #|$ scm_commit Remove sub/entry from store.
      }
      When call do_delete sub/entry
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'does not delete a file without confirmation'
      DECISION=default
      yesno() {
        mocklog yesno "$@"
        ANSWER=n
      }
      result() {
        %text
        #|$ yesno Are you sure you would like to delete sub/entry?
      }
      When call do_delete sub/entry
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'deletes a directory'
      result() {
        %text:expand
        #|$ scm_begin
        #|$ scm_rm empty/
        #|$ scm_commit Remove empty/ from store.
      }
      When call do_delete empty
      The status should be success
      The output should equal 'Removing empty/'
      The error should equal "$(result)"
    End

    It 'deletes a file rather than a directory on ambiguity'
      result() {
        %text:expand
        #|$ scm_begin
        #|$ scm_rm sub.age
        #|$ scm_commit Remove sub from store.
      }
      When call do_delete sub
      The status should be success
      The output should equal 'Removing sub'
      The error should equal "$(result)"
    End

    It 'deletes a directory when explicitly asked'
      result() {
        %text:expand
        #|$ scm_begin
        #|$ scm_rm sub/
        #|$ scm_commit Remove sub/ from store.
      }
      When call do_delete sub/
      The status should be success
      The output should equal 'Removing sub/'
      The error should equal "$(result)"
    End

    It 'does not delete an explicit directory without RECURSIVE'
      RECURSIVE=no
      When run do_delete sub/
      The output should be blank
      The error should equal 'Error: sub/ is a directory'
      The status should equal 1
    End

    It 'does not delete an implicit directory without RECURSIVE'
      RECURSIVE=no
      When run do_delete empty
      The output should be blank
      The error should equal 'Error: empty/ is a directory'
      The status should equal 1
    End

    It 'does not delete a non-encrypted file'
      When run do_delete non-encrypted
      The output should be blank
      The error should equal \
        'Error: non-encrypted is not in the password store.'
      The status should equal 1
    End

    It 'does not delete a file presented as a directory'
      When run do_delete non-encrypted/
      The output should be blank
      The error should equal \
        'Error: non-encrypted/ is not a directory.'
      The status should equal 1
    End

    It 'reports a non-existent directory'
      When run do_delete non-existent/
      The output should be blank
      The error should equal \
        'Error: non-existent/ is not in the password store.'
      The status should equal 1
    End
  End

  Describe 'do_edit'
    SECURE_TMPDIR="${SHELLSPEC_WORKDIR}/secure"
    PREFIX="${SHELLSPEC_WORKDIR}/prefix"

    diff(){ @diff "$@"; }

    do_decrypt() {
      mocklog do_decrypt "$@"
      %= foo
    }
    old_do_decrypt() {
      mocklog do_decrypt "$@"
      %text
      #|old line 1
      #|old line 2
    }

    do_encrypt() {
      mocklog do_encrypt "$@"
      @sed 's/^/> /' >&2
    }

    mktemp() {
      mocklog mktemp "$@"
      %putsn "$2"
    }

    rm(){ mocklog rm "$@"; @rm "$@"; }

    setup() {
      @mkdir -p "${PREFIX}"
      %text > "${PREFIX}/existing.age"
      #|encrypted data
      @mkdir -p "${SECURE_TMPDIR}"
      %text > "${SECURE_TMPDIR}/new-cleartext.txt"
      #|new line 1
      #|old line 2
      #|new line 3
    }

    scm_add() { mocklog scm_add "$@"; }
    scm_begin() { mocklog scm_begin "$@"; }
    scm_commit() { mocklog scm_commit "$@"; }

    cleanup() {
      @rm -rf "${PREFIX}" "${SECURE_TMPDIR}"
    }

    BeforeEach setup
    AfterEach cleanup

    It 'creates a new file'
      edit(){ @cat "${SECURE_TMPDIR}/new-cleartext.txt" >|"$1"; }
      result() {
        %text:expand
        #|$ mktemp -u ${SECURE_TMPDIR}/XXXXXX
        #|$ scm_begin
        #|$ do_encrypt sub/new.age
        #|> new line 1
        #|> old line 2
        #|> new line 3
        #|$ scm_add sub/new.age
        #|$ scm_commit Add password for sub/new using edit.
        #|$ rm ${SECURE_TMPDIR}/XXXXXX-sub-new.txt
      }
      EDIT_CMD=edit
      When call do_edit sub/new
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'handles NOT creating a new file'
      result() {
        %text:expand
        #|$ mktemp -u ${SECURE_TMPDIR}/XXXXXX
        #|$ scm_begin
      }
      EDIT_CMD=true
      When call do_edit new
      The status should be success
      The output should equal 'New password for new not saved.'
      The error should equal "$(result)"
    End

    It 'updates a file'
      edit(){ @cat "${SECURE_TMPDIR}/new-cleartext.txt" >|"$1"; }
      cat(){ mocklog cat "$@"; @cat "$@"; }
      result() {
        %text:expand
        #|$ mktemp -u ${SECURE_TMPDIR}/XXXXXX
        #|$ do_decrypt ${PREFIX}/existing.age
        #|$ cat ${SECURE_TMPDIR}/XXXXXX-existing.txt
        #|$ scm_begin
        #|$ do_encrypt existing.age
        #|> new line 1
        #|> old line 2
        #|> new line 3
        #|$ scm_add existing.age
        #|$ scm_commit Edit password for existing using edit.
        #|$ rm ${SECURE_TMPDIR}/XXXXXX-existing.txt
      }
      EDIT_CMD=edit
      When call do_edit existing
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'does not re-encrypt an unchanged file'
      cat(){ mocklog cat "$@"; @cat "$@"; }
      result() {
        %text:expand
        #|$ mktemp -u ${SECURE_TMPDIR}/XXXXXX
        #|$ do_decrypt ${PREFIX}/existing.age
        #|$ cat ${SECURE_TMPDIR}/XXXXXX-existing.txt
        #|$ scm_begin
        #|$ rm ${SECURE_TMPDIR}/XXXXXX-existing.txt
      }
      EDIT_CMD=true
      When call do_edit existing
      The status should be success
      The output should equal 'Password for existing unchanged.'
      The error should equal "$(result)"
    End

    It 'uses VISUAL on non-dumb terminal'
      edit() { mocklog edit "$@"; }
      VISUAL=edit
      TERM=non-dumb
      EDITOR=false
      unset EDIT_CMD
      result() {
        %text:expand
        #|$ mktemp -u ${SECURE_TMPDIR}/XXXXXX
        #|$ scm_begin
        #|$ edit ${SECURE_TMPDIR}/XXXXXX-subdir-new.txt
      }
      When call do_edit subdir/new
      The status should be success
      The output should equal 'New password for subdir/new not saved.'
      The error should equal "$(result)"
    End

    It 'uses EDITOR on dumb terminal'
      edit() { mocklog edit "$@"; }
      VISUAL=false
      TERM=dumb
      EDITOR=edit
      unset EDIT_CMD
      result() {
        %text:expand
        #|$ mktemp -u ${SECURE_TMPDIR}/XXXXXX
        #|$ scm_begin
        #|$ edit ${SECURE_TMPDIR}/XXXXXX-subdir-new.txt
      }
      When call do_edit subdir/new
      The status should be success
      The output should equal 'New password for subdir/new not saved.'
      The error should equal "$(result)"
    End

    It 'uses EDITOR without terminal'
      edit() { mocklog edit "$@"; }
      VISUAL=false
      EDITOR=edit
      unset EDIT_CMD
      unset TERM
      result() {
        %text:expand
        #|$ mktemp -u ${SECURE_TMPDIR}/XXXXXX
        #|$ scm_begin
        #|$ edit ${SECURE_TMPDIR}/XXXXXX-subdir-new.txt
      }
      When call do_edit subdir/new
      The status should be success
      The output should equal 'New password for subdir/new not saved.'
      The error should equal "$(result)"
    End

    It 'uses EDITOR on non-dumb terminal without VISUAL'
      edit() { mocklog edit "$@"; }
      TERM=non-dumb
      EDITOR=edit
      unset VISUAL
      unset EDIT_CMD
      result() {
        %text:expand
        #|$ mktemp -u ${SECURE_TMPDIR}/XXXXXX
        #|$ scm_begin
        #|$ edit ${SECURE_TMPDIR}/XXXXXX-subdir-new.txt
      }
      When call do_edit subdir/new
      The status should be success
      The output should equal 'New password for subdir/new not saved.'
      The error should equal "$(result)"
    End

    It 'falls back on vi without EDITOR nor VISUAL'
      vi() { mocklog vi "$@"; }
      unset EDITOR
      unset VISUAL
      unset EDIT_CMD
      result() {
        %text:expand
        #|$ mktemp -u ${SECURE_TMPDIR}/XXXXXX
        #|$ scm_begin
        #|$ vi ${SECURE_TMPDIR}/XXXXXX-subdir-new.txt
      }
      When call do_edit subdir/new
      The status should be success
      The output should equal 'New password for subdir/new not saved.'
      The error should equal "$(result)"
    End

    It 'reports EDITOR exit code'
      exit42() { mocklog editor "$@"; return 42; }
      EDITOR=exit42
      result() {
        %text:expand
        #|$ mktemp -u ${SECURE_TMPDIR}/XXXXXX
        #|$ scm_begin
        #|$ editor ${SECURE_TMPDIR}/XXXXXX-subdir-new.txt
        #|Editor "exit42" exited with code 42
      }
      When run do_edit subdir/new
      The status should equal 42
      The error should equal "$(result)"
    End
  End

  Describe 'do_encrypt'
    unset PASHAGE_RECIPIENTS_FILE
    unset PASSAGE_RECIPIENTS_FILE
    unset PASHAGE_RECIPIENTS
    unset PASSAGE_RECIPIENTS
    AGE=age
    PREFIX=/prefix
    dirname() { @dirname "$@"; }

    age() { mocklog age "$@"; }
    mkdir() { mocklog mkdir "$@"; }

    setup() {
      %= data >"${SHELLSPEC_WORKDIR}/existing-file"
    }
    BeforeAll 'setup'

    It 'falls back on identity when there is no recipient'
      OVERWRITE=yes
      IDENTITIES_FILE='/path/to/identity'
      set_LOCAL_RECIPIENT_FILE() {
        LOCAL_RECIPIENT_FILE=''
      }
      result() {
        %text
        #|$ mkdir -p /prefix/encrypted
        #|$ age -e -i /path/to/identity -o /prefix/encrypted/file.age
      }
      When run do_encrypt 'encrypted/file.age'
      The status should be success
      The error should equal "$(result)"
    End

    It 'overwrites existing file only once'
      OVERWRITE=once
      PREFIX="${SHELLSPEC_WORKDIR}"
      set_LOCAL_RECIPIENT_FILE() {
        LOCAL_RECIPIENT_FILE='/path/to/recipients'
      }
      preserve() { %preserve OVERWRITE; }
      AfterRun 'preserve'
      result() {
        %text:expand
        #|$ mkdir -p ${PREFIX}
        #|$ age -e -R /path/to/recipients -o ${PREFIX}/existing-file
      }
      When run do_encrypt 'existing-file'
      The status should be success
      The error should equal "$(result)"
      The variable OVERWRITE should equal no
    End

    It 'overwrites existing file when requested'
      OVERWRITE=yes
      PREFIX="${SHELLSPEC_WORKDIR}"
      set_LOCAL_RECIPIENT_FILE() {
        LOCAL_RECIPIENT_FILE='/path/to/recipients'
      }
      preserve() { %preserve OVERWRITE; }
      AfterRun 'preserve'
      result() {
        %text:expand
        #|$ mkdir -p ${PREFIX}
        #|$ age -e -R /path/to/recipients -o ${PREFIX}/existing-file
      }
      When run do_encrypt 'existing-file'
      The status should be success
      The error should equal "$(result)"
      The variable OVERWRITE should equal yes
    End

    It 'refuses to overwrite an existing file'
      OVERWRITE=no
      PREFIX="${SHELLSPEC_WORKDIR}"
      set_LOCAL_RECIPIENT_FILE() {
        LOCAL_RECIPIENT_FILE='/path/to/recipients'
      }
      When run do_encrypt 'existing-file'
      The error should equal 'Refusing to overwite existing-file'
      The status should equal 1
    End

    It 'uses PASSAGE_RECIPIENTS rather than LOCAL_RECIPIENT_FILE'
      PASSAGE_RECIPIENTS='inline-recipient-1 inline-recipient-2'
      set_LOCAL_RECIPIENT_FILE() {
        LOCAL_RECIPIENT_FILE='shadowed'
      }
      OVERWRITE=yes
      result() {
        %text
        #|$ mkdir -p /prefix/encrypted
        #|$ age -e -r inline-recipient-1 -r inline-recipient-2 -o /prefix/encrypted/file.age
      }

      When call do_encrypt 'encrypted/file.age'
      The status should be success
      The error should equal "$(result)"
    End

    It 'uses PASHAGE_RECIPIENTS rather than PASSAGE_RECIPIENTS'
      PASHAGE_RECIPIENTS='inline-recipient-1 inline-recipient-2'
      PASSAGE_RECIPIENTS='shadowed'
      set_LOCAL_RECIPIENT_FILE() {
        LOCAL_RECIPIENT_FILE='shadowed'
      }
      OVERWRITE=yes
      result() {
        %text
        #|$ mkdir -p /prefix/encrypted
        #|$ age -e -r inline-recipient-1 -r inline-recipient-2 -o /prefix/encrypted/file.age
      }

      When call do_encrypt 'encrypted/file.age'
      The status should be success
      The error should equal "$(result)"
    End

    It 'uses PASSAGE_RECIPIENTS_FILE rather than PASHAGE_RECIPIENTS'
      PASSAGE_RECIPIENTS_FILE='/path/to/recipients'
      PASHAGE_RECIPIENTS='shadowed'
      PASSAGE_RECIPIENTS='shadowed'
      set_LOCAL_RECIPIENT_FILE() {
        LOCAL_RECIPIENT_FILE='shadowed'
      }
      OVERWRITE=yes
      result() {
        %text
        #|$ mkdir -p /prefix/encrypted
        #|$ age -e -R /path/to/recipients -o /prefix/encrypted/file.age
      }

      When call do_encrypt 'encrypted/file.age'
      The status should be success
      The error should equal "$(result)"
    End

    It 'uses PASHAGE_RECIPIENTS_FILE rather than PASSAGE_RECIPIENTS_FILE'
      PASHAGE_RECIPIENTS_FILE='/path/to/recipients'
      PASSAGE_RECIPIENTS_FILE='shadowed'
      PASHAGE_RECIPIENTS='shadowed'
      PASSAGE_RECIPIENTS='shadowed'
      set_LOCAL_RECIPIENT_FILE() {
        LOCAL_RECIPIENT_FILE='shadowed'
      }
      OVERWRITE=yes
      result() {
        %text
        #|$ mkdir -p /prefix/encrypted
        #|$ age -e -R /path/to/recipients -o /prefix/encrypted/file.age
      }

      When call do_encrypt 'encrypted/file.age'
      The status should be success
      The error should equal "$(result)"
    End
  End

  Describe 'do_generate'
    PREFIX="${SHELLSPEC_WORKDIR}/prefix"
    SHOW=none

    dd() { %- 0123456789 ; }
    dirname() { @dirname "$@"; }
    tr() { @tr "$@"; }

    do_encrypt() {
      mocklog do_encrypt "$@"
      @sed 's/^/> /' >&2
    }

    do_show() {
      mocklog do_show "$@"
      @sed 's/^/> /' >&2
    }

    mkdir() { mocklog mkdir "$@"; }
    scm_add() { mocklog scm_add "$@"; }
    scm_begin() { mocklog scm_begin "$@"; }
    scm_commit() { mocklog scm_commit "$@"; }

    setup() {
      @mkdir -p "${PREFIX}/suspicious.age"
      %putsn data >"${PREFIX}/existing.age"
    }

    cleanup() {
      @rm -rf "${PREFIX}"
    }

    BeforeEach setup
    AfterEach cleanup

    It 'detects short reads'
      When run do_generate suspicious 12 '[:alnum:]'
      The output should be blank
      The error should equal \
        'Error while generating password: 10/12 bytes read'
      The status should equal 1
    End

    It 'aborts when a directory is in the way'
      result(){
        %text:expand
        #|$ scm_begin
        #|$ mkdir -p -- ${PREFIX}
        #|Cannot replace directory suspicious.age
      }
      When run do_generate suspicious 10 '[:alnum:]'
      The output should be blank
      The error should equal "$(result)"
      The status should equal 1
    End

    It 'generates a new file'
      result(){
        %text:expand
        #|$ scm_begin
        #|$ mkdir -p -- ${PREFIX}/sub
        #|$ do_encrypt sub/new.age
        #|> 0123456789
        #|$ scm_add ${PREFIX}/sub/new.age
        #|$ scm_commit Add generated password for sub/new.
        #|$ do_show sub/new
        #|> 0123456789
      }
      When call do_generate sub/new 10 '[alnum:]'
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'displays a title before text output'
      SHOW=text
      BOLD_TEXT='(B)'
      NORMAL_TEXT='(N)'
      UNDERLINE_TEXT='(U)'
      NO_UNDERLINE_TEXT='(!U)'
      result(){
        %text:expand
        #|$ scm_begin
        #|$ mkdir -p -- ${PREFIX}/sub
        #|$ do_encrypt sub/new.age
        #|> 0123456789
        #|$ scm_add ${PREFIX}/sub/new.age
        #|$ scm_commit Add generated password for sub/new.
        #|$ do_show sub/new
        #|> 0123456789
      }
      When call do_generate sub/new 10 '[alnum:]'
      The status should be success
      The output should equal \
        '(B)The generated password for (U)sub/new(!U) is:(N)'
      The error should equal "$(result)"
    End

    It 'overwrites an existing file when forced'
      OVERWRITE=no
      DECISION=force
      result(){
        %text:expand
        #|$ scm_begin
        #|$ mkdir -p -- ${PREFIX}
        #|$ do_encrypt existing.age
        #|> 0123456789
        #|$ scm_add ${PREFIX}/existing.age
        #|$ scm_commit Add generated password for existing.
        #|$ do_show existing
        #|> 0123456789
      }
      When call do_generate existing 10 '[alnum:]'
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'overwrites an existing file after confirmation'
      OVERWRITE=no
      DECISION=default
      yesno() {
        mocklog yesno "$@";
        ANSWER=y
      }
      result(){
        %text:expand
        #|$ scm_begin
        #|$ mkdir -p -- ${PREFIX}
        #|$ yesno An entry already exists for existing. Overwrite it?
        #|$ do_encrypt existing.age
        #|> 0123456789
        #|$ scm_add ${PREFIX}/existing.age
        #|$ scm_commit Add generated password for existing.
        #|$ do_show existing
        #|> 0123456789
      }
      When call do_generate existing 10 '[alnum:]'
      The status should be success
      The output should be blank
      The error should equal "$(result)"
      The variable OVERWRITE should equal 'once'
    End

    It 'does not overwrite an existing file without confirmation'
      OVERWRITE=no
      DECISION=default
      yesno() {
        mocklog yesno "$@";
        ANSWER=n
      }
      result(){
        %text:expand
        #|$ scm_begin
        #|$ mkdir -p -- ${PREFIX}
        #|$ yesno An entry already exists for existing. Overwrite it?
      }
      When call do_generate existing 10 '[alnum:]'
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'updates the first line of an existing file'
      OVERWRITE=yes
      mktemp() { %= "$1"; }
      do_decrypt() {
        mocklog do_decrypt "$@"
        %text
        #|old password
        #|line 2
        #|line 3
      }
      mv() { mocklog mv "$@"; }
      result(){
        %text:expand
        #|$ scm_begin
        #|$ mkdir -p -- ${PREFIX}
        #|$ do_decrypt ${PREFIX}/existing.age
        #|$ do_encrypt existing-XXXXXXXXX.age
        #|> 0123456789
        #|> line 2
        #|> line 3
        #|$ mv ${PREFIX}/existing-XXXXXXXXX.age ${PREFIX}/existing.age
        #|$ scm_add ${PREFIX}/existing.age
        #|$ scm_commit Replace generated password for existing.
        #|$ do_show existing
        #|> 0123456789
      }
      When call do_generate existing 10 '[alnum:]'
      The status should be success
      The output should equal 'Decrypting previous secret for existing'
      The error should equal "$(result)"
    End

    It 'updates the only line of an existing one-line file'
      OVERWRITE=yes
      mktemp() { %= "$1"; }
      do_decrypt() {
        mocklog do_decrypt "$@"
        %text
        #|old password
      }
      mv() { mocklog mv "$@"; }
      result(){
        %text:expand
        #|$ scm_begin
        #|$ mkdir -p -- ${PREFIX}
        #|$ do_decrypt ${PREFIX}/existing.age
        #|$ do_encrypt existing-XXXXXXXXX.age
        #|> 0123456789
        #|$ mv ${PREFIX}/existing-XXXXXXXXX.age ${PREFIX}/existing.age
        #|$ scm_add ${PREFIX}/existing.age
        #|$ scm_commit Replace generated password for existing.
        #|$ do_show existing
        #|> 0123456789
      }
      When call do_generate existing 10 '[alnum:]'
      The status should be success
      The output should equal 'Decrypting previous secret for existing'
      The error should equal "$(result)"
    End
  End

  Describe 'do_grep'
    PREFIX="${SHELLSPEC_WORKDIR}/prefix"
    BLUE_TEXT='(B)'
    BOLD_TEXT='(G)'
    NORMAL_TEXT='(N)'

    do_decrypt() { @cat "$1"; }
    grep() { @grep "$1"; }

    setup() {
      @mkdir -p "${PREFIX}/subdir"
      %putsn data >"${PREFIX}/non-match.age"
      %text >"${PREFIX}/subdir/match.age"
      #|non-match
      #|other
      #|suffix
    }

    cleanup() {
      @rm -rf "${PREFIX}"
    }

    BeforeEach setup
    AfterEach cleanup

    It 'outputs matching files'
      result(){
        %text
        #|(B)subdir/(G)match(N):
        #|other
      }
      start_do_grep(){
        ( cd "${PREFIX}" && do_grep '' "$@" )
      }
      When call start_do_grep ot
      The status should be success
      The output should equal "$(result)"
    End

    It 'outputs all the matching lines'
      result(){
        %text
        #|(B)subdir/(G)match(N):
        #|other
        #|suffix
      }
      start_do_grep(){
        ( cd "${PREFIX}" && do_grep '' "$@" )
      }
      When call start_do_grep -vea
      The status should be success
      The output should equal "$(result)"
    End
  End

  Describe 'do_init'
    PREFIX="${SHELLSPEC_WORKDIR}/prefix"
    DECISION=default
    OVERWRITE=no

    do_reencrypt_dir() { mocklog do_reencrypt_dir "$@"; }
    mkdir() { mocklog mkdir "$@"; @mkdir "$@"; }
    scm_add() { mocklog scm_add "$@"; }
    scm_begin() { mocklog scm_begin "$@"; }
    scm_commit() { mocklog scm_commit "$@"; }

    cleanup() {
      @rm -rf "${PREFIX}"
    }

    AfterEach cleanup

    It 'initializes the store'
      result() {
        %text:expand
        #|$ mkdir -p -- ${PREFIX}
        #|$ scm_begin
        #|$ scm_add .age-recipients
        #|$ do_reencrypt_dir ${PREFIX}
        #|$ scm_commit Set age recipients at store root
      }
      When call do_init '' identity
      The status should be success
      The output should equal 'Password store recipients set at store root'
      The error should equal "$(result)"
      The file "${PREFIX}/.age-recipients" should be exist
      The contents of the file "${PREFIX}/.age-recipients" should equal \
        'identity'
    End

    It 'initializes a subdirectory'
      result() {
        %text:expand
        #|$ mkdir -p -- ${PREFIX}/sub
        #|$ scm_begin
        #|$ scm_add sub/.age-recipients
        #|$ do_reencrypt_dir ${PREFIX}/sub
        #|$ scm_commit Set age recipients at sub
      }
      two_id() {
        %text
        #|identity 1
        #|identity 2
      }
      When call do_init sub 'identity 1' 'identity 2'
      The status should be success
      The output should equal 'Password store recipients set at sub'
      The error should equal "$(result)"
      The file "${PREFIX}/sub/.age-recipients" should be exist
      The contents of the file "${PREFIX}/sub/.age-recipients" should equal \
        "$(two_id)"
    End

    It 'can initialize without re-encryption'
      DECISION=keep
      result() {
        %text:expand
        #|$ mkdir -p -- ${PREFIX}
        #|$ scm_begin
        #|$ scm_add .age-recipients
        #|$ scm_commit Set age recipients at store root
      }
      When call do_init '' identity
      The status should be success
      The output should equal 'Password store recipients set at store root'
      The error should equal "$(result)"
      The file "${PREFIX}/.age-recipients" should be exist
      The contents of the file "${PREFIX}/.age-recipients" should equal \
        'identity'
    End
  End

  Describe 'do_insert'
    PREFIX="${SHELLSPEC_WORKDIR}/prefix"

    do_encrypt() {
      mocklog do_encrypt "$@"
      @sed 's/^/> /' >&2
    }

    dirname() { @dirname "$@"; }
    head() { @head "$@"; }

    mkdir() { mocklog mkdir "$@"; }
    scm_add() { mocklog scm_add "$@"; }
    scm_begin() { mocklog scm_begin "$@"; }
    scm_commit() { mocklog scm_commit "$@"; }

    setup() {
      @mkdir -p "${PREFIX}"
      %putsn data >"${PREFIX}/existing.age"
    }

    cleanup() {
      @rm -rf "${PREFIX}"
    }

    BeforeEach setup
    AfterEach cleanup

    It 'inserts a single line from standard input'
      ECHO=yes
      MULTILINE=no
      OVERWRITE=yes
      result() {
        %text:expand
        #|$ scm_begin
        #|$ mkdir -p -- ${PREFIX}/subdir
        #|$ do_encrypt subdir/new.age
        #|> line 1
        #|$ scm_add subdir/new.age
        #|$ scm_commit Add given password for subdir/new to store.
      }
      Data
        #|line 1
        #|line 2
        #|line 3
      End

      When call do_insert 'subdir/new'
      The status should be success
      The output should equal 'Enter password for subdir/new: '
      The error should equal "$(result)"
    End

    It 'inserts the standard input until the first blank line'
      MULTILINE=yes
      OVERWRITE=yes
      o_result() { %text
        #|Enter contents of subdir/new and
        #|press Ctrl+D or enter an empty line when finished:
      }
      result() {
        %text:expand
        #|$ scm_begin
        #|$ mkdir -p -- ${PREFIX}/subdir
        #|$ do_encrypt subdir/new.age
        #|> line 1
        #|> line 2
        #|$ scm_add subdir/new.age
        #|$ scm_commit Add given password for subdir/new to store.
      }
      Data
        #|line 1
        #|line 2
        #|
        #|line 3
        #|line 4
      End

      When call do_insert 'subdir/new'
      The status should be success
      The output should equal "$(o_result)"
      The error should equal "$(result)"
    End

    It 'inserts the whole standard input without blank line'
      MULTILINE=yes
      OVERWRITE=yes
      o_result() { %text
        #|Enter contents of subdir/new and
        #|press Ctrl+D or enter an empty line when finished:
      }
      result() {
        %text:expand
        #|$ scm_begin
        #|$ mkdir -p -- ${PREFIX}/subdir
        #|$ do_encrypt subdir/new.age
        #|> line 1
        #|> line 2
        #|> line 3
        #|$ scm_add subdir/new.age
        #|$ scm_commit Add given password for subdir/new to store.
      }
      Data
        #|line 1
        #|line 2
        #|line 3
      End

      When call do_insert 'subdir/new'
      The status should be success
      The output should equal "$(o_result)"
      The error should equal "$(result)"
    End

    It 'checks password confirmation before inserting it'
      ECHO=no
      MULTILINE=no
      OVERWRITE=yes
      stty() { true; }
      o_result() {
        %text | @sed 's/\$$//'
        #|Enter password for subdir/new:  $
        #|Retype password for subdir/new: $
        #|Passwords don't match$
        #|Enter password for subdir/new:  $
        #|Retype password for subdir/new: $
      }
      e_result() {
        %text:expand
        #|$ scm_begin
        #|$ mkdir -p -- ${PREFIX}/subdir
        #|$ do_encrypt subdir/new.age
        #|> line 3
        #|$ scm_add subdir/new.age
        #|$ scm_commit Add given password for subdir/new to store.
      }
      Data
        #|line 1
        #|line 2
        #|line 3
        #|line 3
        #|line 5
      End

      When call do_insert 'subdir/new'
      The status should be success
      The output should equal "$(o_result)"
      The error should equal "$(e_result)"
    End

    It 'asks confirmation before overwriting'
      MULTILINE=yes
      OVERWRITE=no
      yesno() {
        mocklog yesno "$@"
        ANSWER=y
      }
      o_result() { %text
        #|Enter contents of existing and
        #|press Ctrl+D or enter an empty line when finished:
      }
      result() {
        %text:expand
        #|$ yesno An entry already exists for existing. Overwrite it?
        #|$ scm_begin
        #|$ mkdir -p -- ${PREFIX}
        #|$ do_encrypt existing.age
        #|> password
        #|$ scm_add existing.age
        #|$ scm_commit Add given password for existing to store.
      }
      Data 'password'

      When call do_insert 'existing'
      The status should be success
      The output should equal "$(o_result)"
      The error should equal "$(result)"
      The variable OVERWRITE should equal once
    End

    It 'does not overwrite without confirmation'
      MULTILINE=yes
      OVERWRITE=no
      yesno() {
        mocklog yesno "$@"
        ANSWER=n
      }
      result() {
        %text:expand
        #|$ yesno An entry already exists for existing. Overwrite it?
      }
      Data 'password'

      When call do_insert 'existing'
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'does not ask confirmation before overwriting when forced'
      MULTILINE=yes
      OVERWRITE=yes
      yesno() {
        mocklog yesno "$@"
        ANSWER=y
      }
      o_result() { %text
        #|Enter contents of existing and
        #|press Ctrl+D or enter an empty line when finished:
      }
      result() {
        %text:expand
        #|$ scm_begin
        #|$ mkdir -p -- ${PREFIX}
        #|$ do_encrypt existing.age
        #|> password
        #|$ scm_add existing.age
        #|$ scm_commit Add given password for existing to store.
      }
      Data 'password'

      When call do_insert 'existing'
      The status should be success
      The output should equal "$(o_result)"
      The error should equal "$(result)"
    End
  End

  Describe 'do_list_or_show'
    PREFIX="${SHELLSPEC_WORKDIR}/prefix"

    do_decrypt() {
      mocklog do_decrypt "$@"
      %putsn data
    }

    do_decrypt_gpg() {
      mocklog do_decrypt_gpg "$@"
      %putsn data
    }

    do_show() {
      @cat >/dev/null
      mocklog do_show "$@"
    }

    do_tree() { mocklog do_tree "$@"; }

    setup() {
      @mkdir -p "${PREFIX}/subdir/subsub" "${PREFIX}/empty" "${PREFIX}/other"
      %putsn data >"${PREFIX}/root.age"
      %putsn data >"${PREFIX}/subdir/hidden"
      %putsn data >"${PREFIX}/subdir/subsub/old.gpg"
      %putsn data >"${PREFIX}/other/lower.age"
    }

    cleanup() {
      @rm -rf "${PREFIX}"
    }

    BeforeEach setup
    AfterEach cleanup

    It 'lists the whole store'
      When call do_list_or_show ''
      The status should be success
      The output should be blank
      The error should equal "$ do_tree ${PREFIX} Password Store"
    End

    It 'shows a decrypted age file'
      result() {
        %text:expand
        #|$ do_decrypt ${PREFIX}/other/lower.age
        #|$ do_show other/lower
      }
      When call do_list_or_show 'other/lower'
      The status should be success
      The error should equal "$(result)"
    End

    It 'shows a decrypted gpg file'
      result() {
        %text:expand
        #|$ do_decrypt_gpg ${PREFIX}/subdir/subsub/old.gpg
        #|$ do_show subdir/subsub/old
      }
      When call do_list_or_show 'subdir/subsub/old'
      The status should be success
      The error should equal "$(result)"
    End

    It 'lists a subdirectory'
      When call do_list_or_show 'subdir'
      The status should be success
      The output should be blank
      The error should equal "$ do_tree ${PREFIX}/subdir subdir"
    End

    It 'does not show a non-encrypted file'
      When run do_list_or_show 'subdir/hidden'
      The output should be blank
      The error should equal \
        'Error: subdir/hidden is not in the password store.'
      The status should equal 1
    End
  End

  Describe 'do_reencrypt'
    PREFIX="${SHELLSPEC_WORKDIR}/prefix"
    DECISION=default

    do_decrypt() {
      mocklog do_decrypt "$@"
      %putsn 'secret data'
    }

    do_encrypt() {
      @cat >/dev/null
      mocklog do_encrypt "$@"
    }

    mktemp() { %putsn "${2-$1}"; }
    mv() { mocklog mv "$@"; }
    scm_add() { mocklog scm_add "$@"; }
    scm_begin() { mocklog scm_begin "$@"; }
    scm_commit() { mocklog scm_commit "$@"; }

    setup() {
      @mkdir -p "${PREFIX}/subdir/subsub"
      %putsn data >"${PREFIX}/root.age"
      %putsn data >"${PREFIX}/subdir/middle.age"
      %putsn data >"${PREFIX}/subdir/subsub/deep.age"
    }

    cleanup() {
      @rm -rf "${PREFIX}"
    }

    BeforeEach setup
    AfterEach cleanup

    It 're-encrypts a single file'
      result() {
        %text:expand
        #|$ scm_begin
        #|$ do_decrypt ${PREFIX}/subdir/subsub/deep.age
        #|$ do_encrypt subdir/subsub/deep-XXXXXXXXX.age
        #|$ mv -f -- ${PREFIX}/subdir/subsub/deep-XXXXXXXXX.age ${PREFIX}/subdir/subsub/deep.age
        #|$ scm_add subdir/subsub/deep.age
        #|$ scm_commit Re-encrypt subdir/subsub/deep
      }
      When call do_reencrypt subdir/subsub/deep
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'recursively re-encrypts a directory'
      result() {
        %text:expand
        #|$ scm_begin
        #|$ do_decrypt ${PREFIX}/subdir/middle.age
        #|$ do_encrypt subdir/middle-XXXXXXXXX.age
        #|$ mv -f -- ${PREFIX}/subdir/middle-XXXXXXXXX.age ${PREFIX}/subdir/middle.age
        #|$ scm_add subdir/middle.age
        #|$ do_decrypt ${PREFIX}/subdir/subsub/deep.age
        #|$ do_encrypt subdir/subsub/deep-XXXXXXXXX.age
        #|$ mv -f -- ${PREFIX}/subdir/subsub/deep-XXXXXXXXX.age ${PREFIX}/subdir/subsub/deep.age
        #|$ scm_add subdir/subsub/deep.age
        #|$ scm_commit Re-encrypt subdir/
      }
      When call do_reencrypt subdir/
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'recursively re-encrypts the whole store as /'
      result() {
        %text:expand
        #|$ scm_begin
        #|$ do_decrypt ${PREFIX}/root.age
        #|$ do_encrypt root-XXXXXXXXX.age
        #|$ mv -f -- ${PREFIX}/root-XXXXXXXXX.age ${PREFIX}/root.age
        #|$ scm_add root.age
        #|$ do_decrypt ${PREFIX}/subdir/middle.age
        #|$ do_encrypt subdir/middle-XXXXXXXXX.age
        #|$ mv -f -- ${PREFIX}/subdir/middle-XXXXXXXXX.age ${PREFIX}/subdir/middle.age
        #|$ scm_add subdir/middle.age
        #|$ do_decrypt ${PREFIX}/subdir/subsub/deep.age
        #|$ do_encrypt subdir/subsub/deep-XXXXXXXXX.age
        #|$ mv -f -- ${PREFIX}/subdir/subsub/deep-XXXXXXXXX.age ${PREFIX}/subdir/subsub/deep.age
        #|$ scm_add subdir/subsub/deep.age
        #|$ scm_commit Re-encrypt /
      }
      When call do_reencrypt /
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'recursively re-encrypts the whole store as the empty string'
      result() {
        %text:expand
        #|$ scm_begin
        #|$ do_decrypt ${PREFIX}/root.age
        #|$ do_encrypt root-XXXXXXXXX.age
        #|$ mv -f -- ${PREFIX}/root-XXXXXXXXX.age ${PREFIX}/root.age
        #|$ scm_add root.age
        #|$ do_decrypt ${PREFIX}/subdir/middle.age
        #|$ do_encrypt subdir/middle-XXXXXXXXX.age
        #|$ mv -f -- ${PREFIX}/subdir/middle-XXXXXXXXX.age ${PREFIX}/subdir/middle.age
        #|$ scm_add subdir/middle.age
        #|$ do_decrypt ${PREFIX}/subdir/subsub/deep.age
        #|$ do_encrypt subdir/subsub/deep-XXXXXXXXX.age
        #|$ mv -f -- ${PREFIX}/subdir/subsub/deep-XXXXXXXXX.age ${PREFIX}/subdir/subsub/deep.age
        #|$ scm_add subdir/subsub/deep.age
        #|$ scm_commit Re-encrypt /
      }
      When call do_reencrypt ''
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'asks for confirmation before each file'
      DECISION=interactive
      YESNO_NEXT=n
      yesno() {
        mocklog yesno "$@"
        ANSWER="${YESNO_NEXT}"
        YESNO_NEXT=y
      }
      result() {
        %text:expand
        #|$ scm_begin
        #|$ yesno Re-encrypt subdir/middle?
        #|$ yesno Re-encrypt subdir/subsub/deep?
        #|$ do_decrypt ${PREFIX}/subdir/subsub/deep.age
        #|$ do_encrypt subdir/subsub/deep-XXXXXXXXX.age
        #|$ mv -f -- ${PREFIX}/subdir/subsub/deep-XXXXXXXXX.age ${PREFIX}/subdir/subsub/deep.age
        #|$ scm_add subdir/subsub/deep.age
        #|$ scm_commit Re-encrypt subdir/
      }
      When call do_reencrypt subdir
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'reports a non-existent directory'
      result() {
        %text
        #|$ scm_begin
        #|Error: non-existent/ is not in the password store.
      }
      When run do_reencrypt non-existent/
      The output should be blank
      The error should equal "$(result)"
      The status should equal 1
    End

    It 'reports a non-existent file'
      result() {
        %text
        #|$ scm_begin
        #|Error: non-existent is not in the password store.
      }
      When run do_reencrypt non-existent
      The output should be blank
      The error should equal "$(result)"
      The status should equal 1
    End
  End

  Describe 'do_show'
    cleartext(){
      %text
      #|password line
      #|extra line 1
      #|extra line 2
    }

    It 'shows a secret on standard output'
      cat() { @cat; }
      Data cleartext
      SHOW=text
      When call do_show
      The status should be success
      The output should equal "$(cleartext)"
    End

    It 'pastes a secret into the clipboard'
      head() { @head "$@"; }
      tail() { @tail "$@"; }
      tr() { @tr "$@"; }
      platform_clip() { @cat >&2; }
      Data cleartext
      SELECTED_LINE=1
      SHOW=clip
      When call do_show title
      The status should be success
      The output should be blank
      The error should equal 'password line'
    End

    It 'shows a secret as a QR-code'
      head() { @head "$@"; }
      tail() { @tail "$@"; }
      tr() { @tr "$@"; }
      platform_qrcode() { @cat >&2; }
      Data cleartext
      SELECTED_LINE=1
      SHOW=qrcode
      When call do_show title
      The status should be success
      The output should be blank
      The error should equal 'password line'
    End

    It 'aborts on unexpected SHOW'
      SHOW=bad
      Data cleartext
      When run do_show title
      The output should be blank
      The error should equal 'Unexpected SHOW value "bad"'
      The status should equal 1
    End
  End

  Describe 'do_tree'
    PREFIX="${SHELLSPEC_WORKDIR}/prefix"
    BLUE_TEXT='(B)'
    NORMAL_TEXT='(N)'
    RED_TEXT='(R)'
    TREE_T='T_'
    TREE_L='L_'
    TREE_I='I_'
    TREE__='__'

    grep() { @grep "$@"; }

    setup() {
      @mkdir -p "${PREFIX}/subdir/subsub" "${PREFIX}/empty" "${PREFIX}/other"
      %putsn data >"${PREFIX}/root.age"
      %putsn data >"${PREFIX}/subdir/hidden"
      %putsn data >"${PREFIX}/subdir/subsub/old.gpg"
      %putsn data >"${PREFIX}/other/lower.age"
    }

    cleanup() {
      @rm -rf "${PREFIX}"
    }

    BeforeEach setup
    AfterEach cleanup

    It 'displays everything without a pattern'
      result() {
        %text
        #|Title
        #|T_(B)empty(N)
        #|T_(B)other(N)
        #|I_L_lower
        #|T_root
        #|L_(B)subdir(N)
        #|__L_(B)subsub(N)
        #|____L_(R)old(N)
      }
      When call do_tree "${PREFIX}" 'Title'
      The status should be success
      The output should equal "$(result)"
    End

    It 'displays matching files and their non-matching parents'
      result() {
        %text
        #|Title
        #|T_(B)other(N)
        #|I_L_lower
        #|L_(B)subdir(N)
        #|__L_(B)subsub(N)
        #|____L_(R)old(N)
      }
      When call do_tree "${PREFIX}" 'Title' -i L
      The status should be success
      The output should equal "$(result)"
    End

    It 'does not display matching directories'
      result() {
        %text
        #|Title
        #|L_root
      }
      When call do_tree "${PREFIX}" 'Title' t
      The status should be success
      The output should equal "$(result)"
    End

    It 'might not display anything'
      When call do_tree "${PREFIX}" 'Title' z
      The status should be success
      The output should equal ''
    End

    It 'does not display an empty title'
      When call do_tree "${PREFIX}" '' t
      The status should be success
      The output should equal 'L_root'
    End
  End
End
