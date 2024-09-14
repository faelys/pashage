[![Casual Maintenance Intended](https://casuallymaintained.tech/badge.svg)](https://casuallymaintained.tech/)

# pashage

Yet Another Opinionated Re-engineering of the Unix Password Store

Core objectives:

- same interface and similar feature set
  as [pass](https://www.passwordstore.org/)
- simplicity, understandability, and hackability, from using POSIX shell,
  like [pash](https://github.com/dylanaraps/pash)
- [age](https://age-encryption.org) as encryption backend,
  like [passage](https://github.com/FiloSottile/passage)
- validation using [shellcheck](https://www.shellcheck.net/)
  and [shellspec tests](https://shellspec.info/)

Portability is not a core objective, but a nice side-effect of using
basic POSIX shell, and it is embraced when possible.

Security is not branded as a core objective, because the author does not
have the clout to declare anything secure, and you should probably not
trust random READMEs anyway.
However the simplicity should help you assess whether this password store
is a worthwhile trade-off for _your_ threat model.

For the reference, the author has views [similar to those of Filippo
Valsorda](https://words.filippo.io/dispatches/passage/) and considers
the password store shell script to be about as critical as the rest
of her computer, and relies mostly on age to provide secure encryption
at rest and on a [YubiKey](https://www.yubico.com/) to gatekeep decryption.

## Licencing

This project was written from scratch, and every character of the script
was typed with my fingers.
However I looked deeply into pass, passage, and pash code bases.
I don't know whether that's enough to make it a derivative work covered
by the GPL, so to be on the safe side I'm using GPL v2+ too.

## Differences with `pass`

### Behavior Differences

- The `edit` command does not warn a about using `/tmp` rather than
`/dev/shm`, because the warning does not seem actionable and quickly
becomes ignored noise.

- The `edit` command uses `$VISUAL` rather than `$EDITOR` when it set and
the terminal is not dumb.

- The `find` command search-pattern is a regular expression rather than
a glob.

- The `init` command is redesigned to accommodate `age` backend.
I didn't really understand the original `init` command, so I'm not sure
how different it is; but now it installs `.age-recipients` and re-encrypts.

- TODO

### New Features and Extensions

- The new `random` command leverages password generation without touching
the password store.

- TODO

## Manual

TODO
