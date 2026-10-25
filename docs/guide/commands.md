---
title: Commands
parent: User guide
nav_order: 3
---

# Commands

`syrvis` runs on your computer and reaches the box through a context: `syrvis --context nas <command>`. `syrvis <command> --help` prints that command's usage and dials nothing. Below are the commands of client v0.1.1, which 2.0.0-alpha.67 carries, then the commands run at the box.

## Global flags and exit codes

`--context N` names the box, from `~/.config/syrvis/contexts/N.json`. Your key, the box's pinned key and the instance pin are checked before the command runs. The environment variable `SYRVIS_CONTEXT` sets a default. `--json` prints the raw wire document, and never changes the exit code. `version`, `context`, `api` and `power on` need no context: the client answers them alone.

| code | meaning, unless a command's row says otherwise |
|---|---|
| 0 | answered, and the verdict passed where there is one |
| 1 | a verdict that did not pass, or a refusal from the agent, printed with its recovery |
| 2 | the client refused before the call: the arguments, an unknown command, or the transport |
| 3 | the context could not be used, or the box at its address is not the pinned instance. For `plan` and `converge`, the plan refused |
| 130 | an interrupted `--wait` or `--watch`, with no verdict |

## What the box is doing

| command | what it answers |
|---|---|
| `status` | health, readiness and services, in one glance. Exit 1 when unhealthy |
| `health` | the health verdict and its reasons |
| `hardware` | kernel, memory, load, CPU, arrays, rebuild progress |
| `census` | roots, volumes, collisions, findings |
| `next` | the box's state and the one next act. It never writes. Exit 0 set up, 1 work remains |
| `next --seed <key id>` | seeds one secret. It prompts with echo off, or reads stdin |
| `jobs [--all]` | running jobs, then finished ones |
| `job <id> [--watch]` | one job in full, followed live with `--watch` |
| `cancel <job-id>` | asks a running job to stop |
| `events [--since N]` | the event stream, polled once |
| `watch` | the live event stream, until Ctrl-C |
| `dash [--port N]` | a read-only status board in a browser, on 127.0.0.1 |

## Shutdown, reboot and drains

`reboot` is the whole planned reboot. Its rungs stay commands of their own: `drain device --reason R`, `ready shutdown --wait`, `power down --on-boot converge`, the boot, `restore --watch`, and `ready in-service --wait`.

| command | what it does |
|---|---|
| `reboot` | drains, waits for the shutdown gate, asks you to confirm the halt, waits for the reboot you perform, releases, and waits for return to service. Ctrl-C leaves it standing; run it again to attach |
| `power-off [--hold]` | the planned power-off, closed by the boot you perform. `--hold` keeps the services down after the boot |
| `power down --on-boot converge` | the graceful whole-fleet shutdown, confirm-gated. It needs a device drain on a box ready for shutdown |
| `power restart` | refuses at this release with `power_restart_unmeasured`. Use `reboot` |
| `power on nas` | Wake-on-LAN, then waits for the agent to answer. Exit 1 means unknown, not failed |
| `drain <scope> --reason R` | declares a drain over a `device`, `volume`, `plane`, `set` or `service` |
| `drains` | the active drains |
| `release <id>` | releases a drain, which restores its members |
| `ready [<transition>] [--wait]` | the gates of `drained`, `shutdown` or `in-service` |
| `restore [--watch]` | the boot restore, narrated. It starts nothing |
| `workflow list [--ended]` | the standing procedures, and with `--ended` the finished ones |
| `workflow get <id>` | one procedure: its steps, and what it waits on |
| `workflow confirm <id> <step>` | closes the confirm a waiting step asks for |
| `workflow abandon <id> --reason R` | closes a procedure with a reason. It destroys nothing |

## Deploy

| command | what it does |
|---|---|
| `stage` | stages a deploy bundle from stdin: `syrvis --context nas stage < bundle.json` |
| `plan [id]` | what changes, then how. Bare, it checks drift. Exit 0 clean, 1 pending, 3 refused |
| `apply <id>` | applies a staged revision: pull, flip, converge, watch |
| `converge` | converges again toward the committed revision, or answers `already converged; nothing to do` |
| `revisions` | the staged revisions, the committed one, and the history |
| `prune <service>` | stops and removes named orphans from the plan's orphan report |
| `rollback [--to ID]` | flips back and converges |
| `move <service> <tree> <class>` | moves one data tree to the class its declaration names: `fast`, `bulk` or `cold` |
| `confirm <verb> [args]` | mints a confirm token for `prune`, `rollback`, `move` or `power down` |
| `tasks` | every task unit, its window, and what it runs |
| `task <unit>` | runs one task now, by the path its schedule uses |
| `deliver` | writes the edge proxy's routes, and restarts the edge if it runs |

`prune`, `rollback`, `move` and `power down` name what they destroy and make you type the challenge back. There is no `--yes`, and a stdin that is not a terminal refuses. `prune` and `rollback` are served only at the box: over a context they refuse and name the command to run there.

## Look closer

| command | what it does |
|---|---|
| `verify` | grades the host invariants: volumes, home, seam, boot |
| `logs <service> [-n N]` | a bounded tail of one declared service's output. It does not follow |
| `fs probe --tree <service>/<tree>` | metadata about a declared data tree, never its content |
| `placement check <file>` | the box judges a placement registry, and writes nothing |
| `layer1 check <file>` | the box judges a layer-1 registry, and writes nothing |
| `layer1 declare <file>` | places the layer-1 registry and loads it without a restart |
| `layer1 ensure dash` | builds the dashboard sidecar. The other members refuse by name at this release |
| `methods` | the agent's capability schema |
| `version` | the client's build, and the box versions it serves |

## Keys and contexts

| command | what it does |
|---|---|
| `api enroll-request --context <name> --grade operator` | mints this computer's key and prints the paste-line. `--from <ip>` picks the address, `--rotate` mints a fresh key |
| `context pin <name> <addr>:<port> <fingerprint>` | the first pin: where the box is, and which key it must present |
| `context pin <name>` | pins again from what the context holds, proved by a read |
| `context test <name>` | walks the connection layer by layer, and names the first failure and its fix |
| `context test --gate <gate> <name>` | the same walk, then the named gate |
| `context certificate <name>` | the certificate the box serves, as one PEM block |
| `context list` | the boxes this computer can reach. It dials nothing |
| `whoami` | what this connection's key holds: grade, expiry, renewal |
| `seat list [--all]` | who can reach the box, at what grade, from where, until when |
| `seat update <name> --renew` | renews one live key. `--grade read-only` demotes it; a raise refuses |
| `secret list` | the ids in the box's secret store, never a value |
| `account ensure <name>` | makes a workload's account, or adopts one fit, and prints its uid |
| `mcp` | the Model Context Protocol bridge on stdio, for an LLM host |

## At the box

These run as root on the box, over SSH or through Task Scheduler. `sudo` on DSM does not put the package's directories on its PATH, so each command is spelled in full.

| command | what it does |
|---|---|
| `sudo /var/packages/syrviscore/target/bin/syrvis-enable` | the root step. Its flags include `--home`, `--docker-socket`, `--api-listen`, `--api-client`, `--service-user` and `--arm-compensation`. With no flags, it is the run owed after every upgrade |
| `sudo /var/packages/syrviscore/target/bin/syrvis-enable --undo-help` | prints the whole teardown |
| `sudo /var/packages/syrviscore/target/bin/syrvis-enable --undo` | takes the agent down and removes what the package cannot |
| `sudo /usr/local/bin/syrvis seat enroll --client "<paste-line>"` | enrols a computer's key on a running agent |
| `sudo /usr/local/bin/syrvis seat revoke <name>` | revokes a key now. A revoked key stays barred |
| `sudo /usr/local/bin/syrvis secret forget <id>` | removes one id from the secret store |
| `sudo /usr/local/libexec/syrvisd/current/syrvisd api fingerprint --pin-line` | prints the pin line again |
| `sudo /usr/syno/bin/synosystemctl restart pkg-syrviscore.service` | restarts the agent, which reads its settings only at start |

How the client is built and tested: [Client](../design/client.md).
