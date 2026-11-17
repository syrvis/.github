# Contributing to Syrvis

This guide covers every repository of the syrvis organisation that has no guide of its own.

## Report a bug

Open an issue on the repository of the part at fault:

| what went wrong | where to report it |
|---|---|
| `syrvis` on your computer: a command, a refusal, the install | [syrvis/syrvis-cli](https://github.com/syrvis/syrvis-cli/issues) |
| the server: the daemon, its DSM packages, the root step, Package Center | [syrvis/syrvis](https://github.com/syrvis/syrvis/issues) |
| the console in your browser | [syrvis/syrvis-console](https://github.com/syrvis/syrvis-console/issues) |
| a library you use from your own code | that library's repository |
| a page of the site or the user guide | [syrvis/syrvis.github.io](https://github.com/syrvis/syrvis.github.io/issues) |

If you cannot tell which part is at fault, report it where you ran the command, and we move it.

Say what you ran, paste what it printed in full, and say what you expected. Add `syrvis version` from your computer, the first line of `syrvis status` for the server, and your DSM version. A refusal that does not name the command that finishes the job is a bug in itself: report it.

A security problem is never an issue: follow [SECURITY.md](SECURITY.md).

## Change something

- For anything larger than a small fix, open an issue first, so we agree on the shape before you write the code.
- Each repository's README gives its build and test lines. `make check` is the gate, and a pull request needs it green.
- Keep one change to a commit, with a message that says what changed and why.
- What you contribute is published under the repository's MIT licence.
