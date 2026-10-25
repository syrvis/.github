---
title: User guide
nav_order: 2
has_children: true
---

# User guide

This guide installs Syrvis 2.0.0-alpha.67 on a Synology NAS running DSM 7 and runs it from your computer. Every page is true at that release. Syrvis is alpha software: it runs one production box, and its first install on a second box is being rehearsed.

Syrvis is two programs. The agent, `syrvisd`, runs on the box as a DSM package. The command, `syrvis`, runs on your computer and talks to the agent over mutual TLS on port 7447. The command never opens a shell on the box, and nothing on the box changes until you declare it.

## The pages

| page | what it covers |
|---|---|
| [Install](install.md) | what the box and your computer need, the package, your key, the one root step, and the first connection |
| [First steps](first-steps.md) | checking the install, reading the box, the container plane, self-repair, a second computer, a planned reboot |
| [Commands](commands.md) | every `syrvis` command of this release, the commands run at the box, and the exit codes |
| [Troubleshooting](troubleshooting.md) | the refusals you are likeliest to meet, each with its recovery |
| [Upgrade and undo](upgrade-and-undo.md) | a newer package or client, going back to an older release, and taking Syrvis off the box |

## What the install asks of you

1. A few minutes in DSM, creating a shared folder. Syrvis does not create it for you.
2. One command, run as root on the box. It is the whole privileged part of the install, and you run it again after every upgrade.
3. Three commands on your computer: one mints your key, one records where the box is, and one asks the box what it needs next.

## How to read the commands

- `nas` is the example name of your box on your computer. Every later command carries it as `--context nas`.
- A value in angle brackets, such as `<nas-ip>` or `/volumeN/<share>`, is yours to fill in. Everything else runs as printed.
- "At the box" means as root on the NAS, over SSH or through DSM's Task Scheduler. The install page gives both routes.
- "On your computer" means a terminal on the machine that holds your key.

## Three rules the product keeps

- Every refusal says what it refused, why, and what it did not change, and it ends on the command that finishes the job. A refusal that does not is a defect, and worth reporting.
- Unknown is never a pass. A fact the box cannot read grades unknown, never ok.
- Health is whether the box matches what you declared, not whether it is up.

How each part is built and proven is in the [Design](../design/index.md) pages.
