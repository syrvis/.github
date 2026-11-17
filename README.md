# syrvis/.github

The source of the Syrvis website and of the page GitHub shows at [github.com/syrvis](https://github.com/syrvis). Syrvis runs your own services on a Synology NAS from one document that declares them, and it gives you four ways to manage the server: the `syrvis` command on your computer, a console in your browser, an AI agent through its MCP bridge, and an OpenTofu provider.

Read the site at [syrvis.github.io/.github](https://syrvis.github.io/.github/): the user guide takes you from the install to your first services, the design pages describe each component, and the provability pages say what the TLA+ models check.

## What is here

| path | what it is |
|---|---|
| `profile/README.md` | the organisation's front page on GitHub |
| `docs/` | the site, which GitHub Pages builds with Jekyll: the home page, the user guide (`docs/guide/`), the design pages (`docs/design/`) and the provability pages (`docs/provability/`) |
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

## Reporting

A mistake in a page: open an issue [here](https://github.com/syrvis/.github/issues). A bug in Syrvis: [CONTRIBUTING.md](CONTRIBUTING.md) says which repository takes it. A security problem: follow [SECURITY.md](SECURITY.md), never an issue.

MIT licensed; see `LICENSE`.
