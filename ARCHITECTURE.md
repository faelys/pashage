# pashage Architecture and Design Choices

## Source Overview

The following files are present in `src/` directory:

 - `pashage.sh` defines shell functions, providing most of the functionality,
 - `platform-*.sh` defines platform-specific helper shell functions,
 - `run.sh` prepares the environment and calls the relevant function.

Note that `run.sh` detects dynamically the platform, like `pass` and
`passage`, but the author intended `pashage` to be the platform-specific
amalgamation of the relevant sources.

The shell functions are organized in prefix-designated layers, from the
highest to the lowest:

 - `cmd_`-prefixed functions implement the commands, by parsing arguments
and calling the relevant actions;
 - `do_`-prefixed functions implemenmt the actions, which are the core logic
of the program;
 - `scm_`-prefixed functions are an abstraction over git and some file-system
operations on the checkout;
 - `platform_`-prefixed function are an abstraction of platform-specific
operations;
 - prefixless internal helper functions are used throughout the program.

## Test Overview

Best practices are enforced using [shellcheck](https://www.shellcheck.net/),
and tests are performed using [shellspec](https://shellspec.info/)
in sandbox mode.

The following test sets can be found in `spec/` directory:

- `internal_spec.sh` tests internal helper functions in isolation;
- `action_spec.sh` tests action functions in isolation, mocking everything;
- `usage_spec.sh` tests command functions in isolation, mocking everything;
- TODO tests SCM functions in isolation;
- TODO tests integration, calling command functions with minimal mocks;
- TODO tests `pass`-like behavior of the whole script;
- TODO tests `passage`-like behavior of the whole script.

Platform functions are not tested, because the platform adherence make it
too difficult to test it automatically.

`age`, `git`, and `gpg` are always mocked, to make the tests reproducible
and the failures easier to investigate.
