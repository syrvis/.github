# Security policy

This policy covers every repository of the syrvis organisation that has no policy of its own: the daemon and its DSM packages, the `syrvis` tool, the client library, the console, and the libraries they are built from.

## Report a vulnerability

Report a vulnerability privately, never in a public issue, discussion or pull request.

On GitHub, open the repository where you found the problem, go to its **Security** tab and choose **Report a vulnerability**. Only the maintainers see the report, and we can work out the fix with you there before anything is published. If you cannot tell which repository is at fault, report it on the one whose program you were running, and we move it where it belongs.

## What to include

- What an attacker can do, and from where: your local network, a paired computer, a seat of a given grade, or the server itself.
- The steps that show it, and the versions: `syrvis version` on your computer, and the first line of `syrvis status` for the server.
- What you saw, and what you expected instead.
- Any output or log lines that help. Replace keys, pins, codes and addresses you would rather not share, and never send a private key that is in use; make a fresh one for the test.

## What to expect

- We acknowledge your report within seven days.
- We tell you whether we treat it as a vulnerability, and how we plan to fix it.
- The fix ships in a new release of the programs it affects, with an advisory that credits you, unless you ask us not to.
- Please keep the problem private until the advisory is published, or for 90 days from your report, whichever comes first.

## Supported versions

Syrvis is alpha software. Fixes go into the next release of the server package and of `syrvis`, and earlier releases are not patched: upgrade to the release that carries the fix.

## Out of scope

- DSM itself and Synology's own packages: report those to Synology.
- The images and containers you run with Syrvis: report those to their authors.
- The first connection between your computer and the installer is taken on trust on your local network, as the [install guide](https://syrvis.github.io/guide/install.html) says. A report that shows more is possible than the guide says is in scope.
