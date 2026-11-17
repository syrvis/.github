---
title: Commands
parent: User guide
nav_order: 3
---

# Commands

`syrvis` runs on your computer and reaches the server through a context, the name your computer keeps for it: `syrvis --context nas <command>`. Below are the commands you run, in the groups `syrvis help` uses, then the commands run at the server itself.

## Help

`syrvis <command> --help` prints that command's usage and dials nothing. `syrvis help <group>` prints one group's commands. To list the global flags:

```
syrvis help flags
```

To list every command:

```
syrvis help all
```

## Global flags and exit codes

`--context N` names the server, from `~/.config/syrvis/contexts/N.json`. Your key, the server's pinned key and the instance pin are checked before the command runs. The environment variable `SYRVIS_CONTEXT` sets a default. `--json` prints the raw wire document, and never changes the exit code. The other global flags are `--no-input`, `--accessible`, `--ascii`, `--color` and `--voice V`; `syrvis help flags` says what each one does.

`syrvis` answers some commands before it opens any connection through a context: `version`, `versions`, `discover`, `completion`, `context`, `api`, `power on`, `install`, `upgrade` and `uninstall`. Of those, `upgrade` and `uninstall` still need `--context` to name the server.

| code | meaning, unless a command's row says otherwise |
|---|---|
| 0 | answered, and the verdict passed where there is one |
| 1 | a verdict that did not pass, or a refusal from the daemon, printed with its recovery |
| 2 | `syrvis` refused before the call: the arguments, an unknown command, or the transport |
| 3 | the context could not be used, or the server at its address is not the pinned instance. For `plan` and `converge`, the plan refused |
| 130 | an interrupted `--wait` or `--watch`, with no verdict |

## Start here

| command | what it does |
|---|---|
| `versions` | the releases of the server package and of `syrvis`, against the server versions this `syrvis` serves. Answered on your computer |
| `discover` | searches this computer's networks for servers. Answered on your computer |
| `install [V] [--pair A] [--package P] [--home H] [--door D] [--docker] [--adopt] [--change W] [--manual] [--again] [--abandon] [--ack]` | installs release V, or the newest when you give no V. It does the first install, as [Install: the first handshake](install.md) walks it, and an upgrade, as [Upgrade the package](upgrade-and-uninstall.md#upgrade-the-package) walks it |
| `upgrade (--to V [--ack] | --abandon)` | the older name for `install V` |
| `uninstall [--keep-identity | --erase-identity] [--last-line L] [--ack]` | takes the install off the server, as [Uninstall](upgrade-and-uninstall.md#uninstall) walks it |

## Inspect

| command | what it does |
|---|---|
| `status [--all]` | where the server stands: its state, each finding that needs you with its fix, and the one act to do first. With `--all`, it grades the host invariants: volumes, home, seam, boot |
| `health` | the health verdict and its reasons |
| `hardware` | kernel, memory, load, CPU, arrays, rebuild progress |
| `census` | roots, volumes, collisions, findings |
| `jobs [--all]` | running jobs, then finished ones |
| `job <id> [--watch] [--plain]` | one job in full, followed live with `--watch` |
| `cancel <job-id>` | asks a running job to stop |
| `events [--since N] [--limit N]` | the event stream, polled once |
| `watch [--since N]` | the live event stream, until Ctrl-C |
| `dash [--port N | --listen ADDR]` | serves the status board in a browser, read-only. `--port N` serves it on 127.0.0.1 at port N |

## Lifecycle

`reboot` is the whole planned reboot. Its rungs stay commands of their own: `drain device --reason R`, `ready shutdown --wait`, `power down --on-boot converge`, the boot, `restore --watch`, and `ready in-service --wait`.

| command | what it does |
|---|---|
| `reboot [--reason R] [--interval D] [--plain]` | drains, waits for the shutdown gate, asks you to confirm the halt, waits for the reboot you perform, releases, and waits for return to service. Ctrl-C leaves it standing; run it again to attach |
| `power-off [--hold] [--budget D] [--reason R] [--interval D] [--plain]` | the planned power-off, closed by the boot you perform. `--hold` keeps the services down after the boot |
| `workflow get <id>` | one procedure: its steps, and what it waits on |
| `workflow list [--ended]` | the standing procedures, and with `--ended` the finished ones |
| `workflow confirm <id> <step>` | closes the confirm a waiting step asks for |
| `workflow observe <id> <step> <predicate>` | asks the server to check the step's declared condition now |
| `workflow abandon <id> --reason R` | closes a procedure with a reason. It destroys nothing |
| `drains [--released]` | the active drains |
| `drain <scope> --reason R [--class C] [--selector S] [--until D] [--by W] [--dependants refuse|cascade|strand] [--on-boot hold|converge] [--adopt]` | declares a drain over a `device`, `volume`, `plane`, `set` or `service` |
| `release <id> [--by W]` | releases a drain, which restores its members |
| `ready [<transition>] [--wait [--timeout D]]` | the gates of `drained`, `shutdown` or `in-service` |
| `power down [--reason R] [--by W] [--on-boot converge|hold] [--halt-only] [--no-wait]` | the graceful whole-fleet shutdown, confirm-gated. It needs a device drain on a server ready for shutdown |
| `power restart [--reason R] [--by W]` | refuses with `power_restart_unmeasured`. Use `reboot` |
| `power on [context] [--mac M] [--broadcast A]` | Wake-on-LAN from your computer, then waits for the daemon to answer. Exit 1 means unknown, not failed |
| `restore [--watch] [--plain] [--interval D] [--timeout D]` | the boot restore, narrated. It starts nothing |

## Deploy

| command | what it does |
|---|---|
| `stage` | stages a deploy bundle from stdin: `syrvis --context nas stage < bundle.json` |
| `plan [id] [--expect-diff D] [--service S,…]` | what changes, then how. Bare, it checks drift. Exit 0 clean, 1 pending, 3 refused |
| `apply <id> [--no-wait] [--expect-diff D]` | applies a staged revision: pull, flip, converge, watch |
| `converge [--no-wait] [--expect-diff D]` | converges again toward the committed revision, or answers `already converged; nothing to do` |
| `revisions` | the staged revisions, the committed one, and the history |
| `prune <service…> [--no-wait]` | stops and removes named orphans from the plan's orphan report. Run at the server |
| `rollback [--to ID] [--no-wait]` | flips back and converges. Run at the server |
| `move <service> <tree> <class> [--dry-run] [--no-wait] [--by W]` | moves one data tree to the class its declaration names: `fast`, `bulk` or `cold` |
| `confirm <prune|rollback|move|power down> [args…]` | mints a confirm token for `prune`, `rollback`, `move` or `power down` |
| `tasks` | every task unit, its window, and what it runs |
| `task <unit>` | runs one task now, by the path its schedule uses |
| `deliver [--plain]` | writes the edge proxy's routes, and restarts the edge if it runs |

`prune`, `rollback`, `move` and `power down` name what they destroy and make you type the challenge back. There is no `--yes`, and a stdin that is not a terminal refuses. `prune` and `rollback` are served only at the server: over a context they refuse and name the command to run there. `seat enroll`, `seat revoke`, `secret forget` and `layer1 declare` also run at the server, under `sudo`, as [At the server](#at-the-server) lists them.

## Diagnose

| command | what it does |
|---|---|
| `logs <service> [-n N] [--since T] [--until T]` | a bounded tail of one declared service's output. It does not follow |
| `fs probe -f <file|->` | metadata about a declared data tree, never its content, with the probe read from a file, or from stdin with `-` |
| `fs probe (--home S | --tree S/T | --apps-root V) [--rel P] [--want W]` | the same probe, named on the command line |
| `placement check <file>` | the server judges a placement registry, and writes nothing |
| `layer1 check <file>` | the server judges a layer-1 registry, and writes nothing |
| `layer1 declare [--dry-run] [--secret <name>=<path>]... <file>` | places the registry document and its secret files on the server. Run at the server |
| `layer1 ensure <member> [--recreate] [--plain]` | `layer1 ensure dash` builds the dashboard sidecar. The other members refuse by name |
| `methods` | the daemon's capability schema |
| `version` | this `syrvis`'s build, then the server versions it serves, then the API contract it speaks. Answered on your computer |
| `completion <shell>` | prints the completion script for bash, zsh or fish. Answered on your computer |

`syrvis version` prints three lines. The second, `bound: serves boxes from <version>; tested with <version>`, says which servers it serves: the server must run the first version or a later one.

## Transport

A seat is one computer's key that the daemon accepts calls from, at a grade: read-only, operator or admin. To pin a server is to record the key it presents and accept only that key from then on.

| command | what it does |
|---|---|
| `api enroll-request --context <name> [--grade operator] [--from <ip>] [--rotate]` | mints this computer's key and prints the paste-line. `--from <ip>` picks the address, `--rotate` mints a fresh key. Answered on your computer |
| `context pin <name>` | pins again from what the context holds, proved by a read |
| `context pin <name> <addr>:<port> <fingerprint>` | the first pin: where the server is, and which key it must present |
| `context test <name>` | walks the connection layer by layer, and names the first failure and its fix |
| `context test --gate <gate> <name>` | the same walk, then the named gate |
| `context certificate <name>` | the certificate the server serves, as one PEM block |
| `context dial --gate <gate> <name>` | the four facts another program needs to reach that gate, as one JSON object |
| `context list` | the servers this computer can reach. It dials nothing |
| `context show <name>` | one context, with the file it was read from and the full sentence for the state it is in. It dials nothing |
| `whoami` | what this connection's key holds: grade, expiry, renewal |
| `seat enroll --client "<paste-line>" [--grade read-only|operator|admin] [--replace]` | enrols a computer's key from its paste-line. Run at the server |
| `seat update <name> [--grade read-only|operator] [--renew] [--ttl <duration>]` | `--renew` renews one live key. `--grade read-only` demotes it; a raise refuses |
| `seat list [--all]` | who can reach the server, at what grade, from where, until when |
| `seat revoke <name> [--roster | --account]` | revokes a key now. A revoked key stays barred. Run at the server |
| `secret list` | the ids in the server's secret store, never a value |
| `secret seed <id>` | seeds one value into the server's secret store |
| `secret forget <id>` | removes one id from the secret store. Run at the server |
| `account get <name>` | the server's account of that name: its uid, and whether it can run a workload, with no login and outside administrators |
| `account ensure <name>` | makes a workload's account, or adopts one fit, and prints its uid |
| `mcp` | the Model Context Protocol bridge on stdio, for an LLM host |

## At the server

These run as root on the server, over SSH or through Task Scheduler. `sudo` on DSM does not put the package's directories on its PATH, so each command is spelled in full. `/usr/local/bin/syrvis` is the copy of `syrvis` that SyrvisCore links there while its daemon serves.

| command | what it does |
|---|---|
| `sudo /var/packages/syrviscore/target/bin/syrvis-enable` | the root step. Its flags include `--home`, `--docker-socket`, `--api-listen`, `--api-client`, `--service-user` and `--arm-compensation`. With no flags it is safe to run again. The first install's root line is the installer's, and an upgrade's is the one `syrvis install <version>` prints |
| `sudo /var/packages/syrviscore/target/bin/syrvis-enable --uninstall-help` | prints what `--uninstall` will stop, remove and keep, and the two words its prompt takes. It changes nothing |
| `sudo /var/packages/syrviscore/target/bin/syrvis-enable --uninstall` | takes the daemon down and removes what the package cannot. Its prompt takes `keep-identity` or `erase-identity` |
| `sudo /usr/local/bin/syrvis seat enroll --client "<paste-line>"` | enrols a computer's key on a running daemon |
| `sudo /usr/local/bin/syrvis seat revoke <name>` | revokes a key now. A revoked key stays barred |
| `sudo /usr/local/bin/syrvis secret forget <id>` | removes one id from the secret store |
| `sudo /usr/local/bin/syrvis layer1 declare <file>` | places the layer-1 registry and its secret files on the server |
| `sudo /usr/local/bin/syrvis prune <service>` | stops and removes a named orphan |
| `sudo /usr/local/bin/syrvis rollback` | flips back and converges |
| `sudo /usr/local/libexec/syrvisd/current/syrvisd api fingerprint --pin-line` | prints the pin line again |
| `sudo /usr/syno/bin/synosystemctl restart pkg-syrviscore.service` | restarts the daemon, which reads its settings only at start |
| `sudo /usr/bin/journalctl -u pkg-syrviscore.service -n 50` | the daemon's last 50 log lines |

How `syrvis` is built and tested: [Client](../design/client.md).
