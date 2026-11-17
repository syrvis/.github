# syrvis/.github

The source of the page GitHub shows at [github.com/syrvis](https://github.com/syrvis), and of the organisation's security and contributing policies. Syrvis runs your own services on a Synology NAS from one document that declares them, and it gives you four ways to manage the server: the `syrvis` command on your computer, a console in your browser, an AI agent through its MCP bridge, and an OpenTofu provider.

Read the site at [syrvis.github.io](https://syrvis.github.io/): the user guide takes you from the install to your first services, the design pages describe each component, and the provability pages say what the TLA+ models check. Its source is the repository [syrvis.github.io](https://github.com/syrvis/syrvis.github.io).

## What is here

| path | what it is |
|---|---|
| `profile/README.md` | the organisation's front page on GitHub |
| `docs/` | one small page for each of the site's earlier addresses, which forwards to the same page at [syrvis.github.io](https://syrvis.github.io/) |
| `SECURITY.md`, `CONTRIBUTING.md` | how to report a vulnerability or a bug, and how to contribute, for every repository of the organisation that has no file of its own |
| `scripts/hygiene`, `scripts/hygiene-gate` | the scan that keeps private names out of the published files |

## Check a change

```
make check
```

It needs git, shasum and `/usr/bin/python3`. It confirms the scanner matches its pinned sum, runs the hygiene scan with every group judged, and refuses an em-dash in a page. A pull request needs it green.

## The organisation's repositories

| repository | what it holds |
|---|---|
| [syrvis](https://github.com/syrvis/syrvis) | the daemon on your server, its DSM packages, its API and the OpenTofu provider |
| [syrvis-cli](https://github.com/syrvis/syrvis-cli) | the `syrvis` command for your computer |
| [syrvis-client](https://github.com/syrvis/syrvis-client) | the Go library a program embeds to talk to the daemon |
| [syrvis-console](https://github.com/syrvis/syrvis-console) | the console in your browser |
| [syrvis-workflow](https://github.com/syrvis/syrvis-workflow) | the workflow engine |
| [syrvis-deploy](https://github.com/syrvis/syrvis-deploy) | the deployment service |
| [syrvis-mtls](https://github.com/syrvis/syrvis-mtls) | the mutual TLS transport |
| [syrvis-common](https://github.com/syrvis/syrvis-common) | the shared layers beneath the services |
| [syrvis.github.io](https://github.com/syrvis/syrvis.github.io) | the website |

## Reporting

A mistake in a page of the site: open an issue on [syrvis.github.io](https://github.com/syrvis/syrvis.github.io/issues). A mistake in this repository's pages: open an issue [here](https://github.com/syrvis/.github/issues). A bug in Syrvis: [CONTRIBUTING.md](CONTRIBUTING.md) says which repository takes it. A security problem: follow [SECURITY.md](SECURITY.md), never an issue.

MIT licensed; see `LICENSE`.
