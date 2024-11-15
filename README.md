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

- Not using a terminal does not imply `--force`, instead `pashage` asks for
a confirming `y` on a standard input line.

- When copying a secret to the clipboard, the script keeps running while
waiting for the automatic clearing. This provides a user-facing cue that
the secret may still be the clipboard and allows to clear the clipboard
earlier.

- The commands `copy`, `edit`, `insert`, `list`, `move`, and `show`
accept multiple arguments to operate on many secrets at once.

- The commands `copy` and `move` also operate on unencrypted files in the
password store.

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

- The `insert` command makes the user try again when entering mismatching
passwords.

### New Features and Extensions

- The commands `copy` and `move` have new flags to control re-encryption
(always, never, ask for each file).

- The `generate` command has a new command-line argument to specify
explicitly the character set.

- The `init` command has new flags to control re-encryption (never or
ask for each file).

- The new `gitconfig` command configures an existing store repository to
decrypt before `diff`.

- The new `random` command leverages password generation without touching
the password store.

- The new `reencrypt` command re-encrypts secrets in-place.

## Roadmap

The following features are currently under consideration:

- completion for various shells
- better logic for recursivity in re-encryption
- rewriting of git history to purge old cyphertexts
- partial display of secrets on standard output
- successive clipboard copy of several lines from a single decryption
(e.g. username then password)
- optional interactive confirmation between generation and encryption
(e.g. for iterative attempts against stupid password rules)
- OTP support
- maybe extension support?

## Manual

**pashage** is a _password manager_, which means it manages a database of
encrypted secrets, including encrypting externally-provided new secrets,
generating and encrypting random strings, and decrypting and displaying
stored secrets.

It aims to be simple and composable, but its reliance on Unix philosophy
and customs might make steep learning curve for users outside of this
culture.

It is used through a shell command, denoted as `pashage` in this document,
immediately followed by a subcommand and its arguments. When no subcommand
is specified, _list_ or _show_ is implicitly assumed.

The database is optionally versioned using [git](https://git-scm.com/)
to help with history audit and synchronization. It should be noted that
this prevents re-encryption from erasing old cyphertext, leaving the secret
vulnerable to compromised encryption keys.

The cryptography is done by [age](https://age-encryption.org/) external
command. It decrypts using the _identity_ file given in the environment,
and crypts using a list of _recipients_ per subfolder, defaulting to the
parent _recipient_ list or the _identity_.

## Command Reference

Here is an alphabetical list of all subcommands and aliases:

- `--help`: alias for _help_
- `--version`: alias for _version_
- `-h`: alias for _help_
- `copy`
- `cp`: alias for _copy_
- `delete`
- `edit`
- `find`
- `gen`: alias for _generate_
- `generate`
- `git`
- `gitconfig`
- `grep`
- `help`
- `init`
- `insert`
- `list`
- `ls`: alias for _list_
- `move`
- `mv`: alias for _move_
- `random`
- `re-encrypt`: alias for _reencrypt_
- `reencrypt`
- `remove`: alias for _delete_
- `rm`: alias for _delete_
- `show`
- `version`

### copy

Syntax:

```
pashage copy [--reencrypt,-e | --interactive,-i | --keep,-k ]
             [--force,-f] old-path ... new-path
```

This subcommand copies secrets and recursively copies subfolders,
using the same positional argument scheme as `cp(1)`.
By default it asks before overwriting an existing secret and it re-encrypts
the secret when the destination has a different _recipient_ list.

Flags:
- `-e` or `--reencrypt`: always re-encrypt secrets
- `-f` or `--force`: overwrite existing secrets without asking
- `-i` or `--interactive`: asks whether to re-encrypt or not for each secret
- `-k` or `--keep`: never re-encrypt secrets

Environment:
- `PASHAGE_AGE`: external command to use instead of `age`
- `PASHAGE_DIR`: database directory to use instead of `~/.passage/store`
- `PASHAGE_IDENTITIES_FILE`: _identity_ file to use instead of
  `~/.passage/identities`
- `PASSAGE_AGE`: external command to use instead of `age` when
  `PASHAGE_AGE` is unset
- `PASSAGE_DIR`: database directory to use instead of `~/.passage/store`
  when `PASHAGE_DIR` is unset
- `PASSAGE_IDENTITIES_FILE`: _identity_ file to use instead of
  `~/.passage/identities` when `PASHAGE_IDENTITIES_FILE` is unset
- `PASSWORD_STORE_DIR`: database directory to use instead of
  `~/.passage/store` when both `PASHAGE_DIR` and `PASSAGE_DIR` are unset

### delete

Syntax:

```
pashage delete [--recursive,-r] [--force,-f] pass-name ...
```

This subcommand deletes secrets from the database. By default it skips
subfolders and asks for confirmation for each secret.

Flags:
- `-f` or `--force`: delete without asking for confirmation
- `-r` or `--recursive`: recursively delete all secrets in given subfolders

Environment:
- `PASHAGE_DIR`: database directory to use instead of `~/.passage/store`
- `PASSAGE_DIR`: database directory to use instead of `~/.passage/store`
  when `PASHAGE_DIR` is unset
- `PASSWORD_STORE_DIR`: database directory to use instead of
  `~/.passage/store` when both `PASHAGE_DIR` and `PASSAGE_DIR` are unset

### edit

Syntax:

```
pashage edit pass-name ...
```

This subcommand starts an interactive editor to update the secrets.

Environment:
- `EDITOR`: editor command to use instead of `vi` when `VISUAL` is not set
- `PASHAGE_AGE`: external command to use instead of `age`
- `PASHAGE_DIR`: database directory to use instead of `~/.passage/store`
- `PASHAGE_IDENTITIES_FILE`: _identity_ file to use instead of
  `~/.passage/identities`
- `PASSAGE_AGE`: external command to use instead of `age` when
  `PASHAGE_AGE` is unset
- `PASSAGE_DIR`: database directory to use instead of `~/.passage/store`
  when `PASHAGE_DIR` is unset
- `PASSAGE_IDENTITIES_FILE`: _identity_ file to use instead of
  `~/.passage/identities` when `PASHAGE_IDENTITIES_FILE` is unset
- `PASSWORD_STORE_DIR`: database directory to use instead of
  `~/.passage/store` when both `PASHAGE_DIR` and `PASSAGE_DIR` are unset
- `TMPDIR`: temporary directory for the decrypted file to use instead of
  `/tmp` when `/dev/shm` is not available
- `VISUAL`: editor command to use instead of `vi`

### find

Syntax:

```
pashage find [GREP_OPTIONS] regex
```

This subcommand lists as a tree the secrets whose name match the given
regular expression, using the corresponding `grep(1)` options.

Environment:
- `CLICOLOR`: when set to a non-empty value, use ANSI escape sequences to
  color the output
- `LC_CTYPE`: when it contains `UTF`, the tree is displayed using Unicode
  graphic characters instead of ASCII
- `PASHAGE_DIR`: database directory to use instead of `~/.passage/store`
- `PASSAGE_DIR`: database directory to use instead of `~/.passage/store`
  when `PASHAGE_DIR` is unset
- `PASSWORD_STORE_DIR`: database directory to use instead of
  `~/.passage/store` when both `PASHAGE_DIR` and `PASSAGE_DIR` are unset

### generate

```
pashage generate [--no-symbols,-n] [--clip,-c | --qrcode,-q]
                 [--in-place,-i | --force,-f] pass-name [pass-length]
```

This subcommand generates a new secret from `/dev/urandom`, stores it in
the database, and by default displays it on the standard output and asks
for confirmation before overwriting an existing secret.

Flags:
- `-c` or `--clip`: paste the secret into the clipboard instead of using
  the standard output
- `-f` or `--force`: replace existing secrets without asking
- `-i` or `--in-place`: when the secret already exists, replace only its
  first line and re-use the following lines
- `-n` or `--no-symbols`: generate a secret using only alphanumeric
  characters
- `-q` or `--qrcode`: display the secret as a QR-code instead of using the
  standard output

Environment:
- `CLICOLOR`: when set to a non-empty value, use ANSI escape sequences to
  color the output
- `PASHAGE_AGE`: external command to use instead of `age`
- `PASHAGE_DIR`: database directory to use instead of `~/.passage/store`
- `PASHAGE_IDENTITIES_FILE`: _identity_ file to use instead of
  `~/.passage/identities`
- `PASSAGE_AGE`: external command to use instead of `age` when
  `PASHAGE_AGE` is unset
- `PASSAGE_DIR`: database directory to use instead of `~/.passage/store`
  when `PASHAGE_DIR` is unset
- `PASSAGE_IDENTITIES_FILE`: _identity_ file to use instead of
  `~/.passage/identities` when `PASHAGE_IDENTITIES_FILE` is unset
- `PASSWORD_STORE_CHARACTER_SET_NO_SYMBOLS`: character set to use with
  `tr(1)` when `-n` is specified, instead of `[:alnum:]`
- `PASSWORD_STORE_CHARACTER_SET`: character set to use with `tr(1)` when
  `-n` is not specified, instead of `[:punct:][:alnum:]`
- `PASSWORD_STORE_CLIP_TIME`: number of second before clearing the
  clipboard when `-c` is used, instead of 45
- `PASSWORD_STORE_DIR`: database directory to use instead of
  `~/.passage/store` when both `PASHAGE_DIR` and `PASSAGE_DIR` are unset
- `PASSWORD_STORE_GENERATED_LENGTH`: number of characters in the generated
  secret when not explicitly given, instead of 25
- `PASSWORD_STORE_X_SELECTION`: selection to use when `-c` and `xclip` are
  used, instead of `clipboard`

### git

Syntax:

```
pashage git git-command-args ...
```

This subcommand invokes `git` in the database repository.
Only `git init` and `git clone` are accepted when there is no underlying
repository.

Environment:
- `PASHAGE_DIR`: database directory to use instead of `~/.passage/store`
- `PASSAGE_DIR`: database directory to use instead of `~/.passage/store`
  when `PASHAGE_DIR` is unset
- `PASSWORD_STORE_DIR`: database directory to use instead of
  `~/.passage/store` when both `PASHAGE_DIR` and `PASSAGE_DIR` are unset

### gitconfig

Syntax:

```
pashage gitconfig
```

This subcommand configures the underlying repository to automatically
decrypt secrets to display differences.

Environment:
- `PASHAGE_DIR`: database directory to use instead of `~/.passage/store`
- `PASSAGE_DIR`: database directory to use instead of `~/.passage/store`
  when `PASHAGE_DIR` is unset
- `PASSWORD_STORE_DIR`: database directory to use instead of
  `~/.passage/store` when both `PASHAGE_DIR` and `PASSAGE_DIR` are unset

### grep

Syntax:

```
pashage grep [GREP_OPTIONS] search-regex
```

This subcommand successively decrypts all the secrets in the store and
filter them through `grep(1)` using the given options, and outputs all the
matching lines and the corresponding secret.

Environment:
- `CLICOLOR`: when set to a non-empty value, use ANSI escape sequences to
  color the output
- `PASHAGE_AGE`: external command to use instead of `age`
- `PASHAGE_DIR`: database directory to use instead of `~/.passage/store`
- `PASHAGE_IDENTITIES_FILE`: _identity_ file to use instead of
  `~/.passage/identities`
- `PASSAGE_AGE`: external command to use instead of `age` when
  `PASHAGE_AGE` is unset
- `PASSAGE_DIR`: database directory to use instead of `~/.passage/store`
  when `PASHAGE_DIR` is unset
- `PASSAGE_IDENTITIES_FILE`: _identity_ file to use instead of
  `~/.passage/identities` when `PASHAGE_IDENTITIES_FILE` is unset
- `PASSWORD_STORE_DIR`: database directory to use instead of
  `~/.passage/store` when both `PASHAGE_DIR` and `PASSAGE_DIR` are unset

### help

Syntax:

```
pashage help
```

This subcommand displays on the standard output the version and help text,
including all subcommands and flags and a brief description.

This subcommand is not affected by the environment.

### init

Syntax:

```
pashage init [--interactive,-i | --keep,-k ]
             [--path=subfolder,-p subfolder] age-recipient ...
```

This subcommand initializes an age _recipient_ list, by default of the root
of the password store, and re-encrypts all the affected secrets.
When the _recipient_ list is a single empty string, the _recipient_ list is
instead removed, falling back to a parent _recipient_ list or ultimately to
the age _identity_.

Flags:
- `-i` or `--interactive`: ask for each secret whether to re-encrypt it
  or not
- `-k` or `--keep`: do not re-encrypt any secret
- `-p` or `--path`: operate on the _recipient_ list in the given subfolder
  instead of the root of the password store

Environment:
- `PASHAGE_AGE`: external command to use instead of `age`
- `PASHAGE_DIR`: database directory to use instead of `~/.passage/store`
- `PASHAGE_IDENTITIES_FILE`: _identity_ file to use instead of
  `~/.passage/identities`
- `PASSAGE_AGE`: external command to use instead of `age` when
  `PASHAGE_AGE` is unset
- `PASSAGE_DIR`: database directory to use instead of `~/.passage/store`
  when `PASHAGE_DIR` is unset
- `PASSAGE_IDENTITIES_FILE`: _identity_ file to use instead of
  `~/.passage/identities` when `PASHAGE_IDENTITIES_FILE` is unset
- `PASSWORD_STORE_DIR`: database directory to use instead of
  `~/.passage/store` when both `PASHAGE_DIR` and `PASSAGE_DIR` are unset

### insert

Syntax:

```
pashage insert [--echo,-e | --multiline,-m] [--force,-f] pass-name ...
```

This subcommand adds new secrets in the database, using the provided data
from the standard input. By default asks before overwriting an existing
secret, and it reads a single secret line after turning off the console
echo, and reads it a second time for confirmation.

Flags:
- `-e` or `--echo`: read a single line once without manipulating the
  standard input
- `-m` or `--multiline`: an arbitrary amount of lines from the standard
  input, without trying to manipulate the console, until the end of input
  or a blank line is entered
- `-f` or `--force`: overwrite an existing secret without asking

Environment:
- `PASHAGE_AGE`: external command to use instead of `age`
- `PASHAGE_DIR`: database directory to use instead of `~/.passage/store`
- `PASHAGE_IDENTITIES_FILE`: _identity_ file to use instead of
  `~/.passage/identities`
- `PASSAGE_AGE`: external command to use instead of `age` when
  `PASHAGE_AGE` is unset
- `PASSAGE_DIR`: database directory to use instead of `~/.passage/store`
  when `PASHAGE_DIR` is unset
- `PASSAGE_IDENTITIES_FILE`: _identity_ file to use instead of
  `~/.passage/identities` when `PASHAGE_IDENTITIES_FILE` is unset
- `PASSWORD_STORE_DIR`: database directory to use instead of
  `~/.passage/store` when both `PASHAGE_DIR` and `PASSAGE_DIR` are unset

### list

Syntax:

```
pashage [list] [subfolder ...]
```

This subcommand displays the given subfolders as a tree, or the whole store
when no subfolder is specified.

Note that when a secret is given instead of a subfolder, the _show_ command
will be used instead, without any warning or error.

Environment:
- `CLICOLOR`: when set to a non-empty value, use ANSI escape sequences to
  color the output
- `LC_CTYPE`: when it contains `UTF`, the tree is displayed using Unicode
  graphic characters instead of ASCII
- `PASHAGE_DIR`: database directory to use instead of `~/.passage/store`
- `PASSAGE_DIR`: database directory to use instead of `~/.passage/store`
  when `PASHAGE_DIR` is unset
- `PASSWORD_STORE_DIR`: database directory to use instead of
  `~/.passage/store` when both `PASHAGE_DIR` and `PASSAGE_DIR` are unset

### move

Syntax:

```
pashage move [--reencrypt,-e | --interactive,-i | --keep,-k ]
             [--force,-f] old-path ... new-path
```

This subcommand moves or renames secrets and subfolders recursively,
using the same positional argument scheme as `mv(1)`.
By default it asks before overwriting an existing secret and it re-encrypts
the secret when the destination has a different _recipient_ list.

Flags:
- `-e` or `--reencrypt`: always re-encrypt secrets
- `-f` or `--force`: overwrite existing secrets without asking
- `-i` or `--interactive`: asks whether to re-encrypt or not for each secret
- `-k` or `--keep`: never re-encrypt secrets

Environment:
- `PASHAGE_AGE`: external command to use instead of `age`
- `PASHAGE_DIR`: database directory to use instead of `~/.passage/store`
- `PASHAGE_IDENTITIES_FILE`: _identity_ file to use instead of
  `~/.passage/identities`
- `PASSAGE_AGE`: external command to use instead of `age` when
  `PASHAGE_AGE` is unset
- `PASSAGE_DIR`: database directory to use instead of `~/.passage/store`
  when `PASHAGE_DIR` is unset
- `PASSAGE_IDENTITIES_FILE`: _identity_ file to use instead of
  `~/.passage/identities` when `PASHAGE_IDENTITIES_FILE` is unset
- `PASSWORD_STORE_DIR`: database directory to use instead of
  `~/.passage/store` when both `PASHAGE_DIR` and `PASSAGE_DIR` are unset

### random

Syntax:

```
pashage random [pass-length [character-set]]
```

This subcommand generates a new secret, like the _generate_ subcommand,
then directly displays on the standard output without storing it.

Environment:
- `PASSWORD_STORE_CHARACTER_SET`: character set to use with `tr(1)` when
  `character-set` is not specified, instead of `[:punct:][:alnum:]`
- `PASSWORD_STORE_GENERATED_LENGTH`: number of characters in the generated
  secret when not explicitly given, instead of 25

### reencrypt

Syntax:

```
pashage reencrypt [--interactive,-i] pass-name|subfolder ...
```

This subcommand re-encrypts in place the given secrets, and all the secrets
recursively in the given subfolders.

Flags:
- `-i` or `--interactive`: asks whether to re-encrypt or not for each secret

Environment:
- `PASHAGE_AGE`: external command to use instead of `age`
- `PASHAGE_DIR`: database directory to use instead of `~/.passage/store`
- `PASHAGE_IDENTITIES_FILE`: _identity_ file to use instead of
  `~/.passage/identities`
- `PASSAGE_AGE`: external command to use instead of `age` when
  `PASHAGE_AGE` is unset
- `PASSAGE_DIR`: database directory to use instead of `~/.passage/store`
  when `PASHAGE_DIR` is unset
- `PASSAGE_IDENTITIES_FILE`: _identity_ file to use instead of
  `~/.passage/identities` when `PASHAGE_IDENTITIES_FILE` is unset
- `PASSWORD_STORE_DIR`: database directory to use instead of
  `~/.passage/store` when both `PASHAGE_DIR` and `PASSAGE_DIR` are unset

### show

Syntax:

```
pashage [show] [--clip[=line-number],-c[line-number] |
                --qrcode[=line-number],-q[line-number]] pass-name ...
```

This subcommand decrypts the given secrets and by default displays the
whole text on the standard output.

Note that when a subfolder is given instead of a secret, the _list_ command
will be used instead, without any warning or error.

Flags:
- `-c` or `--clip`: paste the given line (by default the first line) of the
  secret into the clipboard instead of using the standard output
- `-q` or `--qrcode`: display the given line (by default the first line) of
  the secret as a QR-code instead of using the standard output

Environment:
- `PASHAGE_AGE`: external command to use instead of `age`
- `PASHAGE_DIR`: database directory to use instead of `~/.passage/store`
- `PASHAGE_IDENTITIES_FILE`: _identity_ file to use instead of
  `~/.passage/identities`
- `PASSAGE_AGE`: external command to use instead of `age` when
  `PASHAGE_AGE` is unset
- `PASSAGE_DIR`: database directory to use instead of `~/.passage/store`
  when `PASHAGE_DIR` is unset
- `PASSAGE_IDENTITIES_FILE`: _identity_ file to use instead of
  `~/.passage/identities` when `PASHAGE_IDENTITIES_FILE` is unset
- `PASSWORD_STORE_DIR`: database directory to use instead of
  `~/.passage/store` when both `PASHAGE_DIR` and `PASSAGE_DIR` are unset

### version

Syntax:

```
pashage version
```

This subcommand displays on the standard output the version and author
list.

This subcommand is not affected by the environment.
