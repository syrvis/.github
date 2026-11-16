---
title: User guide
nav_order: 2
has_children: true
---

# User guide

This guide takes you from a Synology NAS running DSM 7 to a server that Syrvis runs, driven from your own computer. The install page and First look are written for the server package 2.0.0-alpha.72 and `syrvis` v0.1.12. Commands and Troubleshooting still describe an earlier release in places and are being revised. Syrvis is alpha software.

Syrvis has three parts. `syrvis` runs on your computer. The daemon runs on the server inside the SyrvisCore package, and answers `syrvis` over mutual TLS on port 7447, where each end proves its key on every connection. The installer is a small DSM package that pairs your computer with the server once, then stops. `syrvis` never opens a shell on the server.

## What the install asks of you

Five steps, counted the way the install's screen counts them:

1. On your computer, run `syrvis install`.
2. In DSM, install the installer with Package Center's Manual Install. Your computer's key is already in its one field.
3. In the terminal, choose the shared folder that becomes Syrvis's home.
4. In DSM, create a Task Scheduler task named "syrvis root", run as root.
5. Paste the line `syrvis` prints into that task, and press Run.

The screen closes with "All 5 of your steps done". [Install: the first handshake](install.md) walks each step and shows how your computer and the server come to trust each other.

## How to read a screen

`syrvis` prints one row per step. The mark at the left of a row says where that step stands:

| mark | on the screens in this guide |
|---|---|
| `✓` | the step is done |
| `⠋` | the step is in progress |
| `!` | `syrvis` is waiting, for you or for the server; the row says for what |
| `?` | a question for you, or a row that holds something not checked; the row says which |
| `●` | the server's state, on the status line, such as `healthy` |

At the right of a row, a time is how long the step took. During the install, a count such as `3/5` is which of your five steps you are at. Indented lines with no mark are for you to act on: a click path in DSM, a key, or a line to paste.

The screens say "box" where this guide says "the server". The names, addresses, versions and keys in the guide's screens are example values.

## How to read the commands

- `nas` is the example name your computer keeps for the server. Every later command carries it as `--context nas`.
- A value in angle brackets, such as `<version>`, is yours to fill in. Everything else runs as printed.

## Three rules the product keeps

- Every refusal says what it refused, why, and what it did not change, and it ends on the command that finishes the job. A refusal that does not is a defect, and worth reporting.
- Unknown is never a pass. A fact the server cannot read grades unknown, never ok.
- Health is whether the server matches what you declared. Being up is not enough.

## The pages, in order

| page | what it covers |
|---|---|
| [Install: the first handshake](install.md) | what you need, your five steps, and how your computer and the server come to trust each other |
| [First look](first-steps.md) | `syrvis status` and `status --all`, the console, whether the server is ready, stopping services in order and bringing them back, and a second computer |
| [Commands](commands.md) | the `syrvis` commands and the exit codes; being revised, it still lists two retired commands, `next` and `verify` |
| [Troubleshooting](troubleshooting.md) | the refusals you are likeliest to meet, each with its recovery |
| [Upgrade and uninstall](upgrade-and-uninstall.md) | a newer release with `syrvis install <version>`, and taking Syrvis off the server |

How each part is built and proven is in the [Design](../design/index.md) pages.
