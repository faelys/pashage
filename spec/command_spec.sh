Describe 'Command Functions'
  Include src/pashage.sh
  Set 'errexit:on' 'nounset:on' 'pipefail:on'

  age() {
    case "$1" in
      -e)
        shift
        MOCK_AGE_OUTPUT="$(@mktemp "${PREFIX}/mock-age-encrypt.XXXXXXXXX")"
        while [ $# -gt 0 ]; do
          case "$1" in
            -R|-i)
              @sed 's/^/ageRecipient:/' "$2" >>"${MOCK_AGE_OUTPUT}"
              shift 2 ;;
            -r)
              printf 'ageRecipient:%s\n' "$2" >>"${MOCK_AGE_OUTPUT}"
              shift 2 ;;
            -o)
              [ $# -eq 2 ] || printf 'Unexpected age -e [...] %s\n' "$*" >&2
              @sed 's/^/age:/' >>"${MOCK_AGE_OUTPUT}"
              @mv -f "${MOCK_AGE_OUTPUT}" "$2"
              shift 2 ;;
            *)
              printf 'Unexpected age -e [...] %s\n' "$*" >&2
              exit 1
              ;;
          esac
        done
        ;;
      -d)
        [ "$2" = '-i' ] || echo "Unexpected age -d \$2: \"$2\"" >&2
        @grep -v '^age' "$4" >&2 && echo "Bad encrypted file \"$4\"" >&2
        @grep -qFx "ageRecipient:$(@cat "$3")" "$4" \
          || echo "Bad identity \"$3\": $(@cat "$3")" >&2
        @sed -n 's/^age://p' "$4"
        ;;
      *)
        echo "Unexpected age \$1: \"$1\"" >&2
        ;;
    esac
  }

  setup() {
    %putsn 'moi' >"${SHELLSPEC_WORKDIR}/.age-recipients"
    %putsn 'moi' >"${SHELLSPEC_WORKDIR}/identity"
    %text >"${SHELLSPEC_WORKDIR}/my-file.age"
      #|ageRecipient:moi
      #|age:foo
      #|age:bar
  }

  cleartext() {
    %text
    #|foo
    #|bar
  }

  cleanup() {
    @rm -f "${SHELLSPEC_WORKDIR}/.age-recipients"
    @rm -f "${SHELLSPEC_WORKDIR}/identity"
    @rm -f "${SHELLSPEC_WORKDIR}/my-file.age"
    @rm -f "${SHELLSPEC_WORKDIR}/my-file.txt"
    @rm -f "${SHELLSPEC_WORKDIR}/result.age"
  }

  BeforeEach 'setup'
  AfterEach 'cleanup'

  Specify 'do_decrypt'
    AGE=age
    IDENTITIES_FILE="${SHELLSPEC_WORKDIR}/identity"
    When call do_decrypt "${SHELLSPEC_WORKDIR}/my-file.age"
    The output should equal "$(cleartext)"
  End

  Specify 'do_encrypt'
    AGE=age
    PREFIX="${SHELLSPEC_WORKDIR}"
    Data cleartext
    When call do_encrypt "result.age"
    The file "${SHELLSPEC_WORKDIR}/result.age" should be exist
    The contents of file "${SHELLSPEC_WORKDIR}/result.age" should equal \
      "$(@cat "${SHELLSPEC_WORKDIR}/my-file.age")"
  End
End
