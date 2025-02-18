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

# This test file fully covers all command functions in isolation,
# using mocks for all action and helper functions.
# It mostly tests command-line parsing and environment transmission to actions.

Describe 'Command-Line Parsing'
  Include src/pashage.sh
  if [ "${SHELLSPEC_SHELL_TYPE}" = sh ]; then
    Set 'errexit:on' 'nounset:on'
  else
    Set 'errexit:on' 'nounset:on' 'pipefail:on'
  fi

  PREFIX=/prefix
  PROGRAM=prg

  CHARACTER_SET='[:punct:][:alnum:]'
  CHARACTER_SET_NO_SYMBOLS='[:alnum:]'

  # mocks
  platform_tmpdir() {
    SECURE_TMPDIR=/tmp/secure
  }

  check_sneaky_path() { mocklog check_sneaky_path "$@"; }
  git() { mocklog git "$@"; }
  scm_add() { mocklog scm_add "$@"; }
  scm_begin() { mocklog scm_begin "$@"; }
  scm_commit() { mocklog scm_commit "$@"; }

  do_copy_move() {
    mocklog do_copy_move "$@"
    %text:expand >&2
    #|ACTION=${ACTION}
    #|DECISION=${DECISION}
    #|OVERWRITE=${OVERWRITE}
    #|SCM_ACTION=${SCM_ACTION}
  }
  do_decrypt() {
    mocklog do_decrypt "$@"
  }
  do_decrypt_gpg() {
    mocklog do_decrypt_gpg "$@"
  }
  do_deinit() {
    mocklog do_deinit "$@"
    %text:expand >&2
    #|DECISION=${DECISION}
  }
  do_delete() {
    mocklog do_delete "$@"
    %text:expand >&2
    #|DECISION=${DECISION}
    #|RECURSIVE=${RECURSIVE}
  }
  do_edit() {
    mocklog do_edit "$@"
    %text:expand >&2
    #|EDITOR=${EDITOR}
    #|SECURE_TMPDIR=${SECURE_TMPDIR}
    #|TERM=${TERM}
    #|VISUAL=${VISUAL}
  }
  do_encrypt() {
    mocklog do_encrypt "$@"
    %text:expand >&2
    #|IDENTITIES_FILE=${IDENTITIES_FILE}
    #|LOCAL_RECIPIENT_FILE=${LOCAL_RECIPIENT_FILE}
    #|PASHAGE_RECIPIENTS=${PASHAGE_RECIPIENTS}
    #|PASHAGE_RECIPIENTS_FILE=${PASHAGE_RECIPIENTS_FILE}
    #|PASSAGE_RECIPIENTS=${PASSAGE_RECIPIENTS}
    #|PASSAGE_RECIPIENTS_FILE=${PASSAGE_RECIPIENTS_FILE}
  }
  do_generate() {
    mocklog do_generate "$@"
    %text:expand >&2
    #|DECISION=${DECISION}
    #|MULTILINE=${MULTILINE}
    #|OVERWRITE=${OVERWRITE}
    #|SELECTED_LINE=${SELECTED_LINE}
    #|SHOW=${SHOW}
  }
  do_grep() {
    mocklog do_grep "$@"
  }
  do_init() {
    mocklog do_init "$@"
    %text:expand >&2
    #|DECISION=${DECISION}
    #|OVERWRITE=${OVERWRITE}
  }
  do_insert() {
    mocklog do_insert "$@"
    %text:expand >&2
    #|ECHO=${ECHO}
    #|MULTILINE=${MULTILINE}
    #|OVERWRITE=${OVERWRITE}
  }
  do_list_or_show() {
    mocklog do_list_or_show "$@"
    %text:expand >&2
    #|SELECTED_LINE=${SELECTED_LINE}
    #|SHOW=${SHOW}
  }
  do_reencrypt() {
    mocklog do_reencrypt "$@"
    %text:expand >&2
    #|DECISION=${DECISION}
  }
  do_reencrypt_dir() {
    mocklog do_reencrypt_dir "$@"
    %text:expand >&2
    #|DECISION=${DECISION}
  }
  do_reencrypt_file() {
    mocklog do_reencrypt_file "$@"
    %text:expand >&2
    #|DECISION=${DECISION}
  }
  do_show() {
    mocklog do_show "$@"
    %text:expand >&2
    #|SELECTED_LINE=${SELECTED_LINE}
    #|SHOW=${SHOW}
  }
  do_tree() {
    mocklog do_tree "$@"
  }

  Describe 'cmd_copy'
    COMMAND=copy

    It 'copies multiple files'
      result() {
        %text
        #|$ check_sneaky_path src1
        #|$ check_sneaky_path src2
        #|$ check_sneaky_path src3
        #|$ check_sneaky_path dest
        #|$ do_copy_move src1 dest/
        #|ACTION=Copy
        #|DECISION=default
        #|OVERWRITE=no
        #|SCM_ACTION=scm_cp
        #|$ do_copy_move src2 dest/
        #|ACTION=Copy
        #|DECISION=default
        #|OVERWRITE=no
        #|SCM_ACTION=scm_cp
        #|$ do_copy_move src3 dest/
        #|ACTION=Copy
        #|DECISION=default
        #|OVERWRITE=no
        #|SCM_ACTION=scm_cp
      }
      When call cmd_copy src1 src2 src3 dest
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'copies forcefully with a long option'
      result() {
        %text
        #|$ check_sneaky_path src
        #|$ check_sneaky_path dest
        #|$ do_copy_move src dest
        #|ACTION=Copy
        #|DECISION=default
        #|OVERWRITE=yes
        #|SCM_ACTION=scm_cp
      }
      When call cmd_copy --force src dest
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'copies forcefully with a short option'
      result() {
        %text
        #|$ check_sneaky_path src
        #|$ check_sneaky_path dest
        #|$ do_copy_move src dest
        #|ACTION=Copy
        #|DECISION=default
        #|OVERWRITE=yes
        #|SCM_ACTION=scm_cp
      }
      When call cmd_copy -f src dest
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'always reencrypts with a long option'
      result() {
        %text
        #|$ check_sneaky_path src
        #|$ check_sneaky_path dest
        #|$ do_copy_move src dest
        #|ACTION=Copy
        #|DECISION=force
        #|OVERWRITE=no
        #|SCM_ACTION=scm_cp
      }
      When call cmd_copy --reencrypt src dest
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'always reencrypts with a short option'
      result() {
        %text
        #|$ check_sneaky_path src
        #|$ check_sneaky_path dest
        #|$ do_copy_move src dest
        #|ACTION=Copy
        #|DECISION=force
        #|OVERWRITE=no
        #|SCM_ACTION=scm_cp
      }
      When call cmd_copy -e src dest
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'interactively reencrypts with a long option'
      result() {
        %text
        #|$ check_sneaky_path src
        #|$ check_sneaky_path dest
        #|$ do_copy_move src dest
        #|ACTION=Copy
        #|DECISION=interactive
        #|OVERWRITE=no
        #|SCM_ACTION=scm_cp
      }
      When call cmd_copy --interactive src dest
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'interactively reencrypts with a short option'
      result() {
        %text
        #|$ check_sneaky_path src
        #|$ check_sneaky_path dest
        #|$ do_copy_move src dest
        #|ACTION=Copy
        #|DECISION=interactive
        #|OVERWRITE=no
        #|SCM_ACTION=scm_cp
      }
      When call cmd_copy -i src dest
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'never reencrypts with a long option'
      result() {
        %text
        #|$ check_sneaky_path src
        #|$ check_sneaky_path dest
        #|$ do_copy_move src dest
        #|ACTION=Copy
        #|DECISION=keep
        #|OVERWRITE=no
        #|SCM_ACTION=scm_cp
      }
      When call cmd_copy --keep src dest
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'never reencrypts with a short option'
      result() {
        %text
        #|$ check_sneaky_path src
        #|$ check_sneaky_path dest
        #|$ do_copy_move src dest
        #|ACTION=Copy
        #|DECISION=keep
        #|OVERWRITE=no
        #|SCM_ACTION=scm_cp
      }
      When call cmd_copy -k src dest
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'copies a file named like a flag'
      result() {
        %text
        #|$ check_sneaky_path -s
        #|$ check_sneaky_path dest
        #|$ do_copy_move -s dest
        #|ACTION=Copy
        #|DECISION=default
        #|OVERWRITE=no
        #|SCM_ACTION=scm_cp
      }
      When call cmd_copy -- -s dest
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    usage_text() { %text
      #|Usage: prg copy [--reencrypt,-e | --interactive,-i | --keep,-k ]
      #|                [--force,-f] old-path new-path
    }

    It 'reports a bad option'
      cat() { @cat; }
      When run cmd_copy -s arg
      The output should be blank
      The error should equal "$(usage_text)"
      The status should equal 1
    End

    It 'reports incompatible re-encryption options (-e and -i)'
      cat() { @cat; }
      When run cmd_copy -ei src dest
      The output should be blank
      The error should equal "$(usage_text)"
      The status should equal 1
    End

    It 'reports incompatible re-encryption options (-i and -k)'
      cat() { @cat; }
      When run cmd_copy -ik src dest
      The output should be blank
      The error should equal "$(usage_text)"
      The status should equal 1
    End

    It 'reports incompatible re-encryption options (-k and -e)'
      cat() { @cat; }
      When run cmd_copy -ke src dest
      The output should be blank
      The error should equal "$(usage_text)"
      The status should equal 1
    End

    It 'reports a lack of argument'
      cat() { @cat; }
      When run cmd_copy src
      The output should be blank
      The error should equal "$(usage_text)"
      The status should equal 1
    End
  End

  Describe 'cmd_copy_move'
    COMMAND=wrong

    It 'reports both commands when confused'
      cat() { @cat; }
      result() { %text
        #|Usage: prg copy [--reencrypt,-e | --interactive,-i | --keep,-k ]
        #|                [--force,-f] old-path new-path
        #|       prg move [--reencrypt,-e | --interactive,-i | --keep,-k ]
        #|                [--force,-f] old-path new-path
      }
      When run cmd_copy src
      The output should be blank
      The error should equal "$(result)"
      The status should equal 1
    End
  End

  Describe 'cmd_delete'
    COMMAND=delete

    It 'removes a file forcefully with a long option'
      result() {
        %text
        #|$ check_sneaky_path arg1
        #|$ do_delete arg1
        #|DECISION=force
        #|RECURSIVE=no
      }
      When call cmd_delete --force arg1
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'removes a file forcefully with a short option'
      result() {
        %text
        #|$ check_sneaky_path arg1
        #|$ do_delete arg1
        #|DECISION=force
        #|RECURSIVE=no
      }
      When call cmd_delete -f arg1
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'removes a directory recursively with a long option'
      result() {
        %text
        #|$ check_sneaky_path arg1
        #|$ do_delete arg1
        #|DECISION=default
        #|RECURSIVE=yes
      }
      When call cmd_delete --recursive arg1
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'removes a directory recursively with a short option'
      result() {
        %text
        #|$ check_sneaky_path arg1
        #|$ do_delete arg1
        #|DECISION=default
        #|RECURSIVE=yes
      }
      When call cmd_delete -r arg1
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'removes a directory recursively and forcefully with long options'
      result() {
        %text
        #|$ check_sneaky_path arg1
        #|$ do_delete arg1
        #|DECISION=force
        #|RECURSIVE=yes
      }
      When call cmd_delete --recursive --force arg1
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'removes a directory recursively and forcefully with short options'
      result() {
        %text
        #|$ check_sneaky_path arg1
        #|$ do_delete arg1
        #|DECISION=force
        #|RECURSIVE=yes
      }
      When call cmd_delete -rf arg1
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'removes a directory forcefully and recursively with short options'
      result() {
        %text
        #|$ check_sneaky_path arg1
        #|$ do_delete arg1
        #|DECISION=force
        #|RECURSIVE=yes
      }
      When call cmd_delete -fr arg1
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'removes multiple files'
      result() {
        %text
        #|$ check_sneaky_path arg1
        #|$ check_sneaky_path arg2
        #|$ check_sneaky_path arg3
        #|$ do_delete arg1
        #|DECISION=default
        #|RECURSIVE=no
        #|$ do_delete arg2
        #|DECISION=default
        #|RECURSIVE=no
        #|$ do_delete arg3
        #|DECISION=default
        #|RECURSIVE=no
      }
      When call cmd_delete arg1 arg2 arg3
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'removes a file named like a flag'
      result() {
        %text
        #|$ check_sneaky_path -f
        #|$ check_sneaky_path arg2
        #|$ do_delete -f
        #|DECISION=default
        #|RECURSIVE=no
        #|$ do_delete arg2
        #|DECISION=default
        #|RECURSIVE=no
      }
      When call cmd_delete -- -f arg2
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'reports a bad option'
      cat() { @cat; }
      When run cmd_delete -u arg
      The output should be blank
      The error should equal \
        'Usage: prg delete [--recursive,-r] [--force,-f] pass-name'
      The status should equal 1
    End

    It 'reports a lack of argument'
      cat() { @cat; }
      When run cmd_delete
      The output should be blank
      The error should equal \
        'Usage: prg delete [--recursive,-r] [--force,-f] pass-name'
      The status should equal 1
    End
  End

  Describe 'cmd_edit'
    COMMAND=edit
    EDITOR=ed
    TERM=dumb
    VISUAL=vi

    It 'edits multiple files succesively'
      result() {
        %text
        #|$ check_sneaky_path arg1
        #|$ check_sneaky_path arg2
        #|$ check_sneaky_path arg3
        #|$ do_edit arg1
        #|EDITOR=ed
        #|SECURE_TMPDIR=/tmp/secure
        #|TERM=dumb
        #|VISUAL=vi
        #|$ do_edit arg2
        #|EDITOR=ed
        #|SECURE_TMPDIR=/tmp/secure
        #|TERM=dumb
        #|VISUAL=vi
        #|$ do_edit arg3
        #|EDITOR=ed
        #|SECURE_TMPDIR=/tmp/secure
        #|TERM=dumb
        #|VISUAL=vi
      }
      When call cmd_edit arg1 arg2 arg3
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'reports a lack of argument'
      cat() { @cat; }
      When run cmd_edit
      The output should be blank
      The error should equal 'Usage: prg edit pass-name'
      The status should equal 1
    End
  End

  Describe 'cmd_find'
    COMMAND=find

    It 'uses the argument list directly'
      When call cmd_find -i pattern
      The status should be success
      The output should equal 'Search pattern: -i pattern'
      The error should equal '$ do_tree /prefix  -i pattern'
    End

    It 'reports a lack of argument'
      cat() { @cat; }
      When run cmd_find
      The output should be blank
      The error should equal 'Usage: prg find [GREP_OPTIONS] regex'
      The status should equal 1
    End
  End

  Describe 'cmd_generate'
    COMMAND=generate
    GENERATED_LENGTH=25

    usage_text() { %text
      #|Usage: prg generate [--no-symbols,-n] [--clip,-c | --qrcode,-q]
      #|                    [--in-place,-i | --force,-f] [--multiline,-m]
      #|                    [--try,-t] pass-name [pass-length [character-set]]
    }

    It 'generates a new entry with default length'
      result() {
        %text
        #|$ check_sneaky_path secret
        #|$ do_generate secret 25 [:punct:][:alnum:]
        #|DECISION=default
        #|MULTILINE=no
        #|OVERWRITE=no
        #|SELECTED_LINE=1
        #|SHOW=text
      }
      When call cmd_generate secret
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'generates a new entry with explicit length'
      result() {
        %text
        #|$ check_sneaky_path secret
        #|$ do_generate secret 12 [:punct:][:alnum:]
        #|DECISION=default
        #|MULTILINE=no
        #|OVERWRITE=no
        #|SELECTED_LINE=1
        #|SHOW=text
      }
      When call cmd_generate secret 12
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'generates a new entry with explicit length and character set'
      result() {
        %text
        #|$ check_sneaky_path secret
        #|$ do_generate secret 12 [A-Z]
        #|DECISION=default
        #|MULTILINE=no
        #|OVERWRITE=no
        #|SELECTED_LINE=1
        #|SHOW=text
      }
      When call cmd_generate secret 12 '[A-Z]'
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'generates a new flag-like entry'
      result() {
        %text
        #|$ check_sneaky_path -f
        #|$ do_generate -f 25 [:punct:][:alnum:]
        #|DECISION=default
        #|MULTILINE=no
        #|OVERWRITE=no
        #|SELECTED_LINE=1
        #|SHOW=text
      }
      When call cmd_generate -- -f
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'generates a new entry and copies it into the clipboard (long)'
      result() {
        %text
        #|$ check_sneaky_path secret
        #|$ do_generate secret 25 [:punct:][:alnum:]
        #|DECISION=default
        #|MULTILINE=no
        #|OVERWRITE=no
        #|SELECTED_LINE=1
        #|SHOW=clip
      }
      When call cmd_generate --clip secret
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'generates a new entry and copies it into the clipboard (short)'
      result() {
        %text
        #|$ check_sneaky_path secret
        #|$ do_generate secret 25 [:punct:][:alnum:]
        #|DECISION=default
        #|MULTILINE=no
        #|OVERWRITE=no
        #|SELECTED_LINE=1
        #|SHOW=clip
      }
      When call cmd_generate -c secret
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'generates a new entry and shows it as a QR-code (long)'
      result() {
        %text
        #|$ check_sneaky_path secret
        #|$ do_generate secret 25 [:punct:][:alnum:]
        #|DECISION=default
        #|MULTILINE=no
        #|OVERWRITE=no
        #|SELECTED_LINE=1
        #|SHOW=qrcode
      }
      When call cmd_generate --qrcode secret
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'generates a new entry and shows it as a QR-code (short)'
      result() {
        %text
        #|$ check_sneaky_path secret
        #|$ do_generate secret 25 [:punct:][:alnum:]
        #|DECISION=default
        #|MULTILINE=no
        #|OVERWRITE=no
        #|SELECTED_LINE=1
        #|SHOW=qrcode
      }
      When call cmd_generate -q secret
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'generates a new alphanumeric entry and copies it into the clipboard (long)'
      result() {
        %text
        #|$ check_sneaky_path secret
        #|$ do_generate secret 25 [:alnum:]
        #|DECISION=default
        #|MULTILINE=no
        #|OVERWRITE=no
        #|SELECTED_LINE=1
        #|SHOW=clip
      }
      When call cmd_generate --clip --no-symbols secret
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'generates a new alphanumeric entry and copies it into the clipboard (short)'
      result() {
        %text
        #|$ check_sneaky_path secret
        #|$ do_generate secret 25 [:alnum:]
        #|DECISION=default
        #|MULTILINE=no
        #|OVERWRITE=no
        #|SELECTED_LINE=1
        #|SHOW=clip
      }
      When call cmd_generate -cn secret
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'generates a new alphanumeric entry and shows it as a QR-code (long)'
      result() {
        %text
        #|$ check_sneaky_path secret
        #|$ do_generate secret 25 [:alnum:]
        #|DECISION=default
        #|MULTILINE=no
        #|OVERWRITE=no
        #|SELECTED_LINE=1
        #|SHOW=qrcode
      }
      When call cmd_generate --no-symbols --qrcode secret
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'generates a new alphanumeric entry and shows it as a QR-code (short)'
      result() {
        %text
        #|$ check_sneaky_path secret
        #|$ do_generate secret 25 [:alnum:]
        #|DECISION=default
        #|MULTILINE=no
        #|OVERWRITE=no
        #|SELECTED_LINE=1
        #|SHOW=qrcode
      }
      When call cmd_generate -nq secret
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'generates a new entry in place (long)'
      result() {
        %text
        #|$ check_sneaky_path secret
        #|$ do_generate secret 25 [:punct:][:alnum:]
        #|DECISION=default
        #|MULTILINE=no
        #|OVERWRITE=reuse
        #|SELECTED_LINE=1
        #|SHOW=text
      }
      When call cmd_generate --in-place secret
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'generates a new entry in place (short)'
      result() {
        %text
        #|$ check_sneaky_path secret
        #|$ do_generate secret 25 [:punct:][:alnum:]
        #|DECISION=default
        #|MULTILINE=no
        #|OVERWRITE=reuse
        #|SELECTED_LINE=1
        #|SHOW=text
      }
      When call cmd_generate -i secret
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'overwrites an existing entry (long)'
      result() {
        %text
        #|$ check_sneaky_path secret
        #|$ do_generate secret 25 [:punct:][:alnum:]
        #|DECISION=default
        #|MULTILINE=no
        #|OVERWRITE=yes
        #|SELECTED_LINE=1
        #|SHOW=text
      }
      When call cmd_generate --force secret
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'overwrites an existing entry (short)'
      result() {
        %text
        #|$ check_sneaky_path secret
        #|$ do_generate secret 25 [:punct:][:alnum:]
        #|DECISION=default
        #|MULTILINE=no
        #|OVERWRITE=yes
        #|SELECTED_LINE=1
        #|SHOW=text
      }
      When call cmd_generate -f secret
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'asks for confirmation before saving the generated password (long)'
      result() {
        %text
        #|$ check_sneaky_path secret
        #|$ do_generate secret 25 [:punct:][:alnum:]
        #|DECISION=interactive
        #|MULTILINE=no
        #|OVERWRITE=no
        #|SELECTED_LINE=1
        #|SHOW=text
      }
      When call cmd_generate --try secret
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'asks for confirmation before saving the generated password (short)'
      result() {
        %text
        #|$ check_sneaky_path secret
        #|$ do_generate secret 25 [:punct:][:alnum:]
        #|DECISION=interactive
        #|MULTILINE=no
        #|OVERWRITE=no
        #|SELECTED_LINE=1
        #|SHOW=text
      }
      When call cmd_generate -t secret
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'accepts extra lines after the generated secret (long)'
      result() {
        %text
        #|$ check_sneaky_path secret
        #|$ do_generate secret 25 [:punct:][:alnum:]
        #|DECISION=default
        #|MULTILINE=yes
        #|OVERWRITE=no
        #|SELECTED_LINE=1
        #|SHOW=text
      }
      When call cmd_generate --multiline secret
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'accepts extra lines after the generated secret (short)'
      result() {
        %text
        #|$ check_sneaky_path secret
        #|$ do_generate secret 25 [:punct:][:alnum:]
        #|DECISION=default
        #|MULTILINE=yes
        #|OVERWRITE=no
        #|SELECTED_LINE=1
        #|SHOW=text
      }
      When call cmd_generate -m secret
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'reports incompatible generation long options'
      cat() { @cat; }
      When run cmd_generate --in-place --force secret
      The output should be blank
      The error should equal "$(usage_text)"
      The status should equal 1
    End

    It 'reports incompatible generation short options'
      cat() { @cat; }
      When run cmd_generate -fi secret
      The output should be blank
      The error should equal "$(usage_text)"
      The status should equal 1
    End

    It 'reports incompatible show long options'
      cat() { @cat; }
      When run cmd_generate --qrcode --clip secret
      The output should be blank
      The error should equal "$(usage_text)"
      The status should equal 1
    End

    It 'reports incompatible show short options'
      cat() { @cat; }
      When run cmd_generate -cq secret
      The output should be blank
      The error should equal "$(usage_text)"
      The status should equal 1
    End

    It 'reports a bad option'
      cat() { @cat; }
      When run cmd_generate --bad secret
      The output should be blank
      The error should equal "$(usage_text)"
      The status should equal 1
    End

    It 'reports a lack of argument'
      cat() { @cat; }
      When run cmd_generate
      The output should be blank
      The error should equal "$(usage_text)"
      The status should equal 1
    End
  End

  Describe 'cmd_git'
    COMMAND=git

    cmd_gitconfig() { mocklog cmd_gitconfig "$@"; }
    mkdir() { mocklog mkdir "$@"; @mkdir "$@"; }

    setup() {
      @mkdir -p "${SHELLSPEC_WORKDIR}/repo/.git"
      @mkdir -p "${SHELLSPEC_WORKDIR}/repo/sub"
    }

    cleanup() {
      @rm -rf "${SHELLSPEC_WORKDIR}/repo"
    }

    BeforeEach setup
    AfterEach cleanup

    It 'initializes a new repository'
      PREFIX="${SHELLSPEC_WORKDIR}/repo/sub"
      result() {
        %text:expand
        #|$ mkdir -p -- ${PREFIX}
        #|$ git -C ${PREFIX} init
        #|$ scm_add .
        #|$ scm_commit Add current contents of password store.
        #|$ cmd_gitconfig
      }
      When call cmd_git init
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'clones a new repository'
      PREFIX="${SHELLSPEC_WORKDIR}/repo/sub"
      result() {
        %text:expand
        #|$ git clone origin ${PREFIX}
        #|$ cmd_gitconfig
      }
      When call cmd_git clone origin
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'runs the git command into the store'
      PREFIX="${SHELLSPEC_WORKDIR}/repo"
      When call cmd_git log --oneline
      The status should be success
      The output should be blank
      The error should equal "$ git -C ${PREFIX} log --oneline"
    End

    It 'transmits an empty argument list to git'
      PREFIX="${SHELLSPEC_WORKDIR}/repo"
      When run cmd_git
      The status should be success
      The output should be blank
      The error should equal "$ git -C ${PREFIX}"
    End

    It 'aborts without a git repository'
      PREFIX="${SHELLSPEC_WORKDIR}/repo/sub"
      When run cmd_git log
      The output should be blank
      The error should equal 'Error: the password store is not a git repository. Try "prg git init".'
      The status should equal 1
    End
  End

  Describe 'cmd_gitconfig'
    COMMAND=gitconfig
    AGE=age
    IDENTITIES_FILE=id

    grep() { @grep "$@"; }

    setup() {
      @mkdir -p "${SHELLSPEC_WORKDIR}/repo/.git"
      @mkdir -p "${SHELLSPEC_WORKDIR}/repo/sub-1/.git"
      %putsn data >"${SHELLSPEC_WORKDIR}/repo/sub-1/.gitattributes"
      @mkdir -p "${SHELLSPEC_WORKDIR}/repo/sub-2/.git"
      %putsn '*.age diff=age' >"${SHELLSPEC_WORKDIR}/repo/sub-2/.gitattributes"
    }

    cleanup() {
      @rm -rf "${SHELLSPEC_WORKDIR}/repo"
    }

    BeforeEach setup
    AfterEach cleanup

    It 'configures a new repository'
      PREFIX="${SHELLSPEC_WORKDIR}/repo"
      result() {
        %text:expand
        #|$ scm_begin
        #|$ scm_add .gitattributes
        #|$ scm_commit Configure git repository for age file diff.
        #|$ git -C ${PREFIX} config --local diff.age.binary true
        #|$ git -C ${PREFIX} config --local diff.age.textconv age -d -i id
      }
      When call cmd_gitconfig
      The status should be success
      The output should be blank
      The error should equal "$(result)"
      The contents of file "${PREFIX}/.gitattributes" should equal '*.age diff=age'
    End

    It 'expands an existing .gitattributes'
      PREFIX="${SHELLSPEC_WORKDIR}/repo/sub-1"
      result() {
        %text:expand
        #|$ scm_begin
        #|$ scm_add .gitattributes
        #|$ scm_commit Configure git repository for age file diff.
        #|$ git -C ${PREFIX} config --local diff.age.binary true
        #|$ git -C ${PREFIX} config --local diff.age.textconv age -d -i id
      }
      attrs() {
        %text
        #|data
        #|*.age diff=age
      }
      When call cmd_gitconfig
      The status should be success
      The output should be blank
      The error should equal "$(result)"
      The contents of file "${PREFIX}/.gitattributes" should equal "$(attrs)"
    End

    It 'configures a repository with a valid .gitattributes'
      PREFIX="${SHELLSPEC_WORKDIR}/repo/sub-2"
      result() {
        %text:expand
        #|$ git -C ${PREFIX} config --local diff.age.binary true
        #|$ git -C ${PREFIX} config --local diff.age.textconv age -d -i id
      }
      When call cmd_gitconfig
      The status should be success
      The output should be blank
      The error should equal "$(result)"
      The contents of file "${PREFIX}/.gitattributes" should equal '*.age diff=age'
    End

    It 'aborts without a git repository'
      PREFIX="${SHELLSPEC_WORKDIR}/repo/prefix"
      When run cmd_gitconfig
      The output should be blank
      The error should equal  'The store is not a git repository.'
      The status should equal 1
    End
  End

  Describe 'cmd_grep'
    COMMAND=grep
    PREFIX="${SHELLSPEC_WORKDIR}"

    It 'uses the argument list directly'
      When call cmd_grep -i pattern
      The status should be success
      The output should be blank
      The error should equal '$ do_grep  -i pattern'
    End

    It 'reports a lack of argument'
      cat() { @cat; }
      When run cmd_grep
      The output should be blank
      The error should equal 'Usage: prg grep [GREP_OPTIONS] search-regex'
      The status should equal 1
    End
  End

  Describe 'cmd_help'
    COMMAND=help

    It 'displays version and usage'
      cmd_usage() { mocklog cmd_usage "$@"; }
      cmd_version() { mocklog cmd_version "$@"; }
      result() {
        %text | @sed 's/\$$//'
        #|$ cmd_version
        #|$ cmd_usage     $
      }
      When call cmd_help
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End
  End

  Describe 'cmd_init'
    COMMAND=init

    It 'initializes the whole store'
      result() {
        %text | @sed 's/\$$//'
        #|$ check_sneaky_path $
        #|$ do_init  recipient-1 recipient-2
        #|DECISION=default
        #|OVERWRITE=yes
      }
      When call cmd_init recipient-1 recipient-2
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'initializes the whole store conservatively with a long option'
      result() {
        %text | @sed 's/\$$//'
        #|$ check_sneaky_path $
        #|$ do_init  recipient-1 recipient-2
        #|DECISION=keep
        #|OVERWRITE=yes
      }
      When call cmd_init --keep recipient-1 recipient-2
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'initializes the whole store conservatively with a short option'
      result() {
        %text | @sed 's/\$$//'
        #|$ check_sneaky_path $
        #|$ do_init  recipient-1 recipient-2
        #|DECISION=keep
        #|OVERWRITE=yes
      }
      When call cmd_init -k recipient-1 recipient-2
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'initializes the whole store interactively with a long option'
      result() {
        %text | @sed 's/\$$//'
        #|$ check_sneaky_path $
        #|$ do_init  recipient-1 recipient-2
        #|DECISION=interactive
        #|OVERWRITE=yes
      }
      When call cmd_init --interactive recipient-1 recipient-2
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'initializes the whole store interactively with a short option'
      result() {
        %text | @sed 's/\$$//'
        #|$ check_sneaky_path $
        #|$ do_init  recipient-1 recipient-2
        #|DECISION=interactive
        #|OVERWRITE=yes
      }
      When call cmd_init -i recipient-1 recipient-2
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'initializes a subdirectory with a collapsed long option'
      result() {
        %text
        #|$ check_sneaky_path sub
        #|$ do_init sub recipient
        #|DECISION=default
        #|OVERWRITE=yes
      }
      When call cmd_init --path=sub recipient
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'initializes a subdirectory with an expanded long option'
      result() {
        %text
        #|$ check_sneaky_path sub
        #|$ do_init sub recipient
        #|DECISION=default
        #|OVERWRITE=yes
      }
      When call cmd_init --path sub recipient
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'initializes a subdirectory with a collapsed short option'
      result() {
        %text
        #|$ check_sneaky_path sub
        #|$ do_init sub recipient
        #|DECISION=default
        #|OVERWRITE=yes
      }
      When call cmd_init -psub recipient
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'initializes a subdirectory with an expanded short option'
      result() {
        %text
        #|$ check_sneaky_path sub
        #|$ do_init sub recipient
        #|DECISION=default
        #|OVERWRITE=yes
      }
      When call cmd_init -p sub recipient
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'interactively initializes a directory with collapsed short options'
      result() {
        %text
        #|$ check_sneaky_path sub
        #|$ do_init sub recipient
        #|DECISION=interactive
        #|OVERWRITE=yes
      }
      When call cmd_init -ipsub recipient
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'conservatively initializes a directory with long options'
      result() {
        %text
        #|$ check_sneaky_path sub
        #|$ do_init sub recipient
        #|DECISION=keep
        #|OVERWRITE=yes
      }
      When call cmd_init --path sub --keep recipient
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'de-initializes a subdirectory'
      result() {
        %text
        #|$ check_sneaky_path sub
        #|$ do_deinit sub
        #|DECISION=default
      }
      When call cmd_init -p sub ''
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'supports recipients starting with dash'
      result() {
        %text | @sed 's/\$$//'
        #|$ check_sneaky_path $
        #|$ do_init  -recipient
        #|DECISION=default
        #|OVERWRITE=yes
      }
      When call cmd_init -- -recipient
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    usage_text() { %text
      #|Usage: prg init [--interactive,-i | --keep,-k ]
      #|                [--path=subfolder,-p subfolder] age-recipient ...
    }

    It 'reports a bad option'
      cat() { @cat; }
      When run cmd_init -q arg
      The output should be blank
      The error should equal "$(usage_text)"
      The status should equal 1
    End

    It 'reports conflicting options (`-i` then `-k`)'
      cat() { @cat; }
      When run cmd_init -ik arg
      The output should be blank
      The error should equal "$(usage_text)"
      The status should equal 1
    End

    It 'reports conflicting options (`-k` then `-i`)'
      cat() { @cat; }
      When run cmd_init --keep --interactive arg
      The output should be blank
      The error should equal "$(usage_text)"
      The status should equal 1
    End

    It 'reports a missing recipient'
      cat() { @cat; }
      When run cmd_init -p sub
      The output should be blank
      The error should equal "$(usage_text)"
      The status should equal 1
    End

    It 'reports a missing path'
      cat() { @cat; }
      When run cmd_init -p
      The output should be blank
      The error should equal "$(usage_text)"
      The status should equal 1
    End

    It 'reports a lack of argument'
      cat() { @cat; }
      When run cmd_init
      The output should be blank
      The error should equal "$(usage_text)"
      The status should equal 1
    End
  End

  Describe 'cmd_insert'
    COMMAND=insert

    It 'inserts a few new entries'
      result() {
        %text
        #|$ check_sneaky_path secret1
        #|$ check_sneaky_path secret2
        #|$ do_insert secret1
        #|ECHO=no
        #|MULTILINE=no
        #|OVERWRITE=no
        #|$ do_insert secret2
        #|ECHO=no
        #|MULTILINE=no
        #|OVERWRITE=no
      }
      When call cmd_insert secret1 secret2
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'inserts a new flag-like entry'
      result() {
        %text
        #|$ check_sneaky_path -c
        #|$ do_insert -c
        #|ECHO=no
        #|MULTILINE=no
        #|OVERWRITE=no
      }
      When call cmd_insert -- -c
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'inserts a new entry with echo (short option)'
      result() {
        %text
        #|$ check_sneaky_path secret
        #|$ do_insert secret
        #|ECHO=yes
        #|MULTILINE=no
        #|OVERWRITE=no
      }
      When call cmd_insert -e secret
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'inserts a new entry with echo (long option)'
      result() {
        %text
        #|$ check_sneaky_path secret
        #|$ do_insert secret
        #|ECHO=yes
        #|MULTILINE=no
        #|OVERWRITE=no
      }
      When call cmd_insert --echo secret
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'forcefully inserts a new entry with echo (short option)'
      result() {
        %text
        #|$ check_sneaky_path secret
        #|$ do_insert secret
        #|ECHO=yes
        #|MULTILINE=no
        #|OVERWRITE=yes
      }
      When call cmd_insert -fe secret
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'forcefully inserts a new entry with echo (short options)'
      result() {
        %text
        #|$ check_sneaky_path secret
        #|$ do_insert secret
        #|ECHO=yes
        #|MULTILINE=no
        #|OVERWRITE=yes
      }
      When call cmd_insert -e -f secret
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'forcefully inserts a new entry with echo (long option)'
      result() {
        %text
        #|$ check_sneaky_path secret
        #|$ do_insert secret
        #|ECHO=yes
        #|MULTILINE=no
        #|OVERWRITE=yes
      }
      When call cmd_insert --force --echo secret
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'inserts a new multiline entry (short option)'
      result() {
        %text
        #|$ check_sneaky_path secret
        #|$ do_insert secret
        #|ECHO=no
        #|MULTILINE=yes
        #|OVERWRITE=no
      }
      When call cmd_insert -m secret
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'inserts a new multiline entry (long option)'
      result() {
        %text
        #|$ check_sneaky_path secret
        #|$ do_insert secret
        #|ECHO=no
        #|MULTILINE=yes
        #|OVERWRITE=no
      }
      When call cmd_insert --multiline secret
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'forcefully inserts a new multiline entry (short option)'
      result() {
        %text
        #|$ check_sneaky_path secret
        #|$ do_insert secret
        #|ECHO=no
        #|MULTILINE=yes
        #|OVERWRITE=yes
      }
      When call cmd_insert -mf secret
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'forcefully inserts a new multiline entry (short options)'
      result() {
        %text
        #|$ check_sneaky_path secret
        #|$ do_insert secret
        #|ECHO=no
        #|MULTILINE=yes
        #|OVERWRITE=yes
      }
      When call cmd_insert -m -f secret
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'forcefully inserts a new multiline entry (long option)'
      result() {
        %text
        #|$ check_sneaky_path secret
        #|$ do_insert secret
        #|ECHO=no
        #|MULTILINE=yes
        #|OVERWRITE=yes
      }
      When call cmd_insert --force --multiline secret
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'reports a bad option'
      cat() { @cat; }
      When run cmd_insert -u secret
      The output should be blank
      The error should equal \
        'Usage: prg insert [--echo,-e | --multiline,-m] [--force,-f] pass-name'
      The status should equal 1
    End

    It 'reports incompatible long options'
      cat() { @cat; }
      When run cmd_insert --multiline --echo secret
      The output should be blank
      The error should equal \
        'Usage: prg insert [--echo,-e | --multiline,-m] [--force,-f] pass-name'
      The status should equal 1
    End

    It 'reports incompatible short options'
      cat() { @cat; }
      When run cmd_insert -em secret
      The output should be blank
      The error should equal \
        'Usage: prg insert [--echo,-e | --multiline,-m] [--force,-f] pass-name'
      The status should equal 1
    End

    It 'reports a lack of argument'
      cat() { @cat; }
      When run cmd_insert
      The output should be blank
      The error should equal \
        'Usage: prg insert [--echo,-e | --multiline,-m] [--force,-f] pass-name'
      The status should equal 1
    End
  End

  Describe 'cmd_list_or_show'
    COMMAND=

    It 'lists the whole store'
      result() {
        %text | @sed 's/\$$//'
        #|$ do_list_or_show $
        #|SELECTED_LINE=1
        #|SHOW=text
      }
      When call cmd_list_or_show
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'shows multiple entries'
      result() {
        %text
        #|$ check_sneaky_path arg1
        #|$ check_sneaky_path arg2
        #|$ check_sneaky_path arg3
        #|$ do_list_or_show arg1
        #|SELECTED_LINE=1
        #|SHOW=text
        #|$ do_list_or_show arg2
        #|SELECTED_LINE=1
        #|SHOW=text
        #|$ do_list_or_show arg3
        #|SELECTED_LINE=1
        #|SHOW=text
      }
      When call cmd_list_or_show arg1 arg2 arg3
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'shows a flag-like entry'
      result() {
        %text
        #|$ check_sneaky_path -c
        #|$ do_list_or_show -c
        #|SELECTED_LINE=1
        #|SHOW=text
      }
      When call cmd_list_or_show -- -c
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'copies an entry into the clipboard (short option)'
      result() {
        %text
        #|$ check_sneaky_path arg
        #|$ do_list_or_show arg
        #|SELECTED_LINE=1
        #|SHOW=clip
      }
      When call cmd_list_or_show -c arg
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'copies an entry into the clipboard (long option)'
      result() {
        %text
        #|$ check_sneaky_path arg
        #|$ do_list_or_show arg
        #|SELECTED_LINE=1
        #|SHOW=clip
      }
      When call cmd_list_or_show --clip arg
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'copies a line of an entry into the clipboard (short option)'
      result() {
        %text
        #|$ check_sneaky_path arg
        #|$ do_list_or_show arg
        #|SELECTED_LINE=2
        #|SHOW=clip
      }
      When call cmd_list_or_show -c2 arg
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'copies a line of an entry into the clipboard (short option)'
      result() {
        %text
        #|$ check_sneaky_path arg
        #|$ do_list_or_show arg
        #|SELECTED_LINE=2
        #|SHOW=clip
      }
      When call cmd_list_or_show --clip=2 arg
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'shows an entry as a QR-code (short option)'
      result() {
        %text
        #|$ check_sneaky_path arg
        #|$ do_list_or_show arg
        #|SELECTED_LINE=1
        #|SHOW=qrcode
      }
      When call cmd_list_or_show -q arg
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'shows an entry as a QR-code (long option)'
      result() {
        %text
        #|$ check_sneaky_path arg
        #|$ do_list_or_show arg
        #|SELECTED_LINE=1
        #|SHOW=qrcode
      }
      When call cmd_list_or_show --qrcode arg
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'shows the line of an entry as a QR-code (short option)'
      result() {
        %text
        #|$ check_sneaky_path arg
        #|$ do_list_or_show arg
        #|SELECTED_LINE=3
        #|SHOW=qrcode
      }
      When call cmd_list_or_show -q3 arg
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'shows the line of an entry as a QR-code (long option)'
      result() {
        %text
        #|$ check_sneaky_path arg
        #|$ do_list_or_show arg
        #|SELECTED_LINE=3
        #|SHOW=qrcode
      }
      When call cmd_list_or_show --qrcode=3 arg
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'reports incompatible show options'
      cat() { @cat; }
      result() { %text
        #|Usage: prg [list] [subfolder]
        #|       prg [show] [--clip[=line-number],-c[line-number] |
        #|                   --qrcode[=line-number],-q[line-number]] pass-name
      }
      When run cmd_list_or_show -q -c arg
      The output should be blank
      The error should equal "$(result)"
      The status should equal 1
    End

    It 'reports a bad option for both commands'
      cat() { @cat; }
      result() { %text
        #|Usage: prg [list] [subfolder]
        #|       prg [show] [--clip[=line-number],-c[line-number] |
        #|                   --qrcode[=line-number],-q[line-number]] pass-name
      }
      When run cmd_list_or_show -f arg
      The output should be blank
      The error should equal "$(result)"
      The status should equal 1
    End

    It 'reports a bad option for list command'
      COMMAND=list
      cat() { @cat; }
      result() { %text
        #|Usage: prg [list] [subfolder]
      }
      When run cmd_list_or_show -f arg
      The output should be blank
      The error should equal "$(result)"
      The status should equal 1
    End

    It 'reports a bad option for show command'
      COMMAND=show
      cat() { @cat; }
      result() { %text
        #|Usage: prg [show] [--clip[=line-number],-c[line-number] |
        #|                   --qrcode[=line-number],-q[line-number]] pass-name
      }
      When run cmd_list_or_show -f arg
      The output should be blank
      The error should equal "$(result)"
      The status should equal 1
    End
  End

  Describe 'cmd_move'
    COMMAND=move

    It 'moves multiple files'
      result() {
        %text
        #|$ check_sneaky_path src1
        #|$ check_sneaky_path src2
        #|$ check_sneaky_path src3
        #|$ check_sneaky_path dest
        #|$ do_copy_move src1 dest/
        #|ACTION=Move
        #|DECISION=default
        #|OVERWRITE=no
        #|SCM_ACTION=scm_mv
        #|$ do_copy_move src2 dest/
        #|ACTION=Move
        #|DECISION=default
        #|OVERWRITE=no
        #|SCM_ACTION=scm_mv
        #|$ do_copy_move src3 dest/
        #|ACTION=Move
        #|DECISION=default
        #|OVERWRITE=no
        #|SCM_ACTION=scm_mv
      }
      When call cmd_move src1 src2 src3 dest
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'moves forcefully with a long option'
      result() {
        %text
        #|$ check_sneaky_path src
        #|$ check_sneaky_path dest
        #|$ do_copy_move src dest
        #|ACTION=Move
        #|DECISION=default
        #|OVERWRITE=yes
        #|SCM_ACTION=scm_mv
      }
      When call cmd_move --force src dest
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'moves forcefully with a short option'
      result() {
        %text
        #|$ check_sneaky_path src
        #|$ check_sneaky_path dest
        #|$ do_copy_move src dest
        #|ACTION=Move
        #|DECISION=default
        #|OVERWRITE=yes
        #|SCM_ACTION=scm_mv
      }
      When call cmd_move -f src dest
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'always reencrypts with a long option'
      result() {
        %text
        #|$ check_sneaky_path src
        #|$ check_sneaky_path dest
        #|$ do_copy_move src dest
        #|ACTION=Move
        #|DECISION=force
        #|OVERWRITE=no
        #|SCM_ACTION=scm_mv
      }
      When call cmd_move --reencrypt src dest
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'always reencrypts with a short option'
      result() {
        %text
        #|$ check_sneaky_path src
        #|$ check_sneaky_path dest
        #|$ do_copy_move src dest
        #|ACTION=Move
        #|DECISION=force
        #|OVERWRITE=no
        #|SCM_ACTION=scm_mv
      }
      When call cmd_move -e src dest
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'interactively reencrypts with a long option'
      result() {
        %text
        #|$ check_sneaky_path src
        #|$ check_sneaky_path dest
        #|$ do_copy_move src dest
        #|ACTION=Move
        #|DECISION=interactive
        #|OVERWRITE=no
        #|SCM_ACTION=scm_mv
      }
      When call cmd_move --interactive src dest
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'interactively reencrypts with a short option'
      result() {
        %text
        #|$ check_sneaky_path src
        #|$ check_sneaky_path dest
        #|$ do_copy_move src dest
        #|ACTION=Move
        #|DECISION=interactive
        #|OVERWRITE=no
        #|SCM_ACTION=scm_mv
      }
      When call cmd_move -i src dest
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'never reencrypts with a long option'
      result() {
        %text
        #|$ check_sneaky_path src
        #|$ check_sneaky_path dest
        #|$ do_copy_move src dest
        #|ACTION=Move
        #|DECISION=keep
        #|OVERWRITE=no
        #|SCM_ACTION=scm_mv
      }
      When call cmd_move --keep src dest
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'never reencrypts with a short option'
      result() {
        %text
        #|$ check_sneaky_path src
        #|$ check_sneaky_path dest
        #|$ do_copy_move src dest
        #|ACTION=Move
        #|DECISION=keep
        #|OVERWRITE=no
        #|SCM_ACTION=scm_mv
      }
      When call cmd_move -k src dest
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'moves a file named like a flag'
      result() {
        %text
        #|$ check_sneaky_path -s
        #|$ check_sneaky_path dest
        #|$ do_copy_move -s dest
        #|ACTION=Move
        #|DECISION=default
        #|OVERWRITE=no
        #|SCM_ACTION=scm_mv
      }
      When call cmd_move -- -s dest
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    usage_text() { %text
      #|Usage: prg move [--reencrypt,-e | --interactive,-i | --keep,-k ]
      #|                [--force,-f] old-path new-path
    }

    It 'reports a bad option'
      cat() { @cat; }
      When run cmd_move -s arg
      The output should be blank
      The error should equal "$(usage_text)"
      The status should equal 1
    End

    It 'reports incompatible re-encryption options (-e and -i)'
      cat() { @cat; }
      When run cmd_move -ei src dest
      The output should be blank
      The error should equal "$(usage_text)"
      The status should equal 1
    End

    It 'reports incompatible re-encryption options (-i and -k)'
      cat() { @cat; }
      When run cmd_move -ik src dest
      The output should be blank
      The error should equal "$(usage_text)"
      The status should equal 1
    End

    It 'reports incompatible re-encryption options (-k and -e)'
      cat() { @cat; }
      When run cmd_move -ke src dest
      The output should be blank
      The error should equal "$(usage_text)"
      The status should equal 1
    End

    It 'reports a lack of argument'
      cat() { @cat; }
      When run cmd_move src
      The output should be blank
      The error should equal "$(usage_text)"
      The status should equal 1
    End
  End

  Describe 'cmd_random'
    COMMAND=generate
    GENERATED_LENGTH=25

    random_chars() { mocklog random_chars "$@"; }

    It 'generates random characters with default parameters'
      When run cmd_random
      The status should be success
      The error should equal \
        "$ random_chars ${GENERATED_LENGTH} ${CHARACTER_SET}"
    End

    It 'generates random characters with default character set'
      When run cmd_random 8
      The status should be success
      The error should equal "$ random_chars 8 ${CHARACTER_SET}"
    End

    It 'generates random characters with the given arguments'
      When run cmd_random 8 a-z
      The status should be success
      The error should equal "$ random_chars 8 a-z"
    End

    It 'reports too many arguments'
      cat() { @cat; }
      When run cmd_random 1 2 3
      The output should be blank
      The error should equal 'Usage: prg random [pass-length [character-set]]'
      The status should equal 1
    End
  End

  Describe 'cmd_reencrypt'
    COMMAND=reencrypt

    It 're-encrypts multiple files and directories'
      result() {
        %text
        #|$ check_sneaky_path file-1
        #|$ check_sneaky_path dir/
        #|$ check_sneaky_path sub/file-2
        #|$ do_reencrypt file-1
        #|DECISION=default
        #|$ do_reencrypt dir/
        #|DECISION=default
        #|$ do_reencrypt sub/file-2
        #|DECISION=default
      }
      When call cmd_reencrypt file-1 dir/ sub/file-2
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'interactively re-encrypts with a long option'
      result() {
        %text
        #|$ check_sneaky_path arg
        #|$ do_reencrypt arg
        #|DECISION=interactive
      }
      When call cmd_reencrypt --interactive arg
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 'interactively re-encrypts with a short option'
      result() {
        %text
        #|$ check_sneaky_path arg
        #|$ do_reencrypt arg
        #|DECISION=interactive
      }
      When call cmd_reencrypt -i arg
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    It 're-encrypts a file named like a flag'
      result() {
        %text
        #|$ check_sneaky_path -s
        #|$ do_reencrypt -s
        #|DECISION=default
      }
      When call cmd_reencrypt -- -s
      The status should be success
      The output should be blank
      The error should equal "$(result)"
    End

    usage_text() { %text
      #|Usage: prg reencrypt [--interactive,-i] pass-name|subfolder ...
    }

    It 'reports a bad option'
      cat() { @cat; }
      When run cmd_reencrypt -s arg
      The status should equal 1
      The output should be blank
      The error should equal "$(usage_text)"
    End

    It 'reports a lack of argument'
      cat() { @cat; }
      When run cmd_reencrypt
      The status should equal 1
      The output should be blank
      The error should equal "$(usage_text)"
    End
  End

  Describe 'cmd_usage'
    COMMAND=usage
    CLIP_TIME='$CLIP_TIME'
    GENERATED_LENGTH='$GENERATED_LENGTH'
    cat() { @cat; }

    It 'displays a human-reable usage string'
      When call cmd_usage
      The status should be success
      The first line of output should equal 'Usage:'
      The error should be blank
    End

    It 'includes help about all commands'
      When call cmd_usage
      The status should be success
      The output should include 'prg copy'
      The output should include 'prg delete'
      The output should include 'prg edit'
      The output should include 'prg find'
      The output should include 'prg generate'
      The output should include 'prg git'
      The output should include 'prg gitconfig'
      The output should include 'prg grep'
      The output should include 'prg help'
      The output should include 'prg init'
      The output should include 'prg insert'
      The output should include 'prg [list]'
      The output should include 'prg move'
      The output should include 'prg random'
      The output should include 'prg reencrypt'
      The output should include 'prg [show]'
      The output should include 'prg version'
    End

    It 'rejects unknown commands'
      When run cmd_usage '> ' foo
      The output should be blank
      The error should equal 'cmd_usage: unknown command "foo"'
      The status should equal 1
    End
  End

  Describe 'cmd_version'
    COMMAND=version

    It 'shows the version box'
      cat() { @cat; }
      result() {
        %text
        #|==============================================
        #|= pashage: age-backed POSIX password manager =
        #|=                                            =
        #|=                   v*
        #|=                                            =
        #|=            Natasha Kerensikova             =
        #|=                                            =
        #|=                 Based on:                  =
        #|=   password-store  by Jason A. Donenfeld    =
        #|=          passage  by Filippo Valsorda      =
        #|=             pash  by Dylan Araps           =
        #|==============================================
      }
      When call cmd_version
      The status should be success
      The output should match pattern "$(result)"
    End
  End
End
