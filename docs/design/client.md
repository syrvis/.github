---
title: Client
parent: Design
nav_order: 3
---

# Client

`syrvis-client` is the `syrvis` command line: the tool you run on your own computer to read and change a box through the daemon's mutual-TLS API. Each release states in `manifest.json` which box versions it serves, and tests on both sides of the wire hold that statement true. Its rule is that every command it prints runs as printed, and named tests hold the rule.

This page reads `main` at commit `e616a46`, with the daemon at `1069e15b`. The release is `v0.1.1`, the one the package `2.0.0-alpha.67` carries, and its verbs, contexts, ladder layers, manifest and renderer are as below. Three things here are on main and not yet released, and each is marked: the flows that run on the client's own workflow engine, the guarded start they give reboot and power-off, and the box-upgrade recovery line.

## What it is built from

The module is the Go standard library plus first-party modules, each pinned to a tag and vendored: two in the release, and on main a third, the engine. The build gate refuses anything else.

| module | tag | what the client takes from it |
|---|---|---|
| `github.com/syrvis/syrvis/api` | `v0.1.1` | the sealed method registry, the one wire client, the context store, the box's paths and port, the recorded answers |
| `github.com/syrvis/syrvis-mtls` | `v0.1.0` | the pin, the seat grammar, the one pinned dial; see [Transport](transport.md) |
| `github.com/syrvis/syrvis-workflow` | `v0.2.0`, on main only | the engine its flows run on; see [Engine](engine.md) |

The wire client lives in the daemon's contract module, so the daemon's tests and the provider share it. The client holds the verbs, the flows, the renderer, an MCP bridge (`syrvis mcp`) and a read-only local web board (`syrvis dash`).

The dispatch table holds 43 verbs that reach a box and 4 keys the client answers alone: `version`, `context`, `api`, and `power on`, which wakes a box that is off. An unknown verb refuses before any address resolves, so a typo never opens a connection.

A release carries binaries for macOS on arm64 and amd64 and for Linux on amd64, with `SHA256SUMS` and `manifest.json`. The box's package carries a copy of the release at `/usr/local/bin/syrvis`.

## Contexts

A context is one file, `~/.config/syrvis/contexts/<name>.json`, schema `syrvis-context-tls/1`. It holds the address to dial, the daemon's pinned key, the paths of this client's key and certificate, this client's pin, the source address it enrolled from, the box's instance id, and its MAC address for wake-on-LAN. The CLI, the MCP bridge and the provider read contexts through one store, so a name means one box on a machine.

A verb that reaches a box takes the form `syrvis --context <name> <verb>`. When one refuses, run `syrvis context test <name>`. Listing the contexts reads the store and dials nothing:

```sh
syrvis context list
```

A context comes to exist in two steps, one paste each way; the [user guide](../guide/index.md) walks them. `syrvis api enroll-request --context <name> --grade operator` mints an Ed25519 key that never leaves the computer and prints one paste-line for the root step at the box. The root step prints a pin line, and `syrvis context pin <name> <address>:7447 <64 hex>` records the box's address and key, then takes the first authenticated read.

## The ladder: `context test`

`syrvis context test <name>` dials one layer at a time and stops at the first failure, printing that layer's recovery. `--gate <gate>` adds a gate's layers. On main, unreleased, the walk runs as the `ladder` workflow definition on an engine instance in memory, so it takes no lock and runs beside a waiting flow.

| rung | passes when | on failure the client prints |
|---|---|---|
| context | the file loads and records an address and a pin | the `syrvis context pin` line, and where the fingerprint comes from |
| tcp | the address accepts a connection | a timeout: a filtered port or a dark host; a reset: nothing listens |
| identity | this client's key and certificate load | run `syrvis api enroll-request` again |
| tls | the daemon presents exactly the pinned key over TLS 1.3 | re-pin, or find out what answered in the daemon's place |
| client-auth | the daemon admits the key and answers a read | enroll, renew or fix the source address, then test again |
| instance | the box's instance id equals the one pinned | re-pin deliberately: the box was rebuilt, or the name aims elsewhere |
| version | informational only | the skew against the client's bound, and what closes it |

A rung has three postures. A pass gets a tick. A failure ends the walk with exit 1. A fact the box does not serve is stated with its recovery and no tick, and reads `"ok": false` under `--json` while the exit stays 0: unknown is never a pass. The transport's refusals are on [Transport](transport.md#the-dial-ladder-and-its-refusals).

## The bound: the pinned manifest

Each release carries `manifest.json` with seven keys, and the binary embeds it, so `syrvis version` prints the bound the release ships:

| key | holds |
|---|---|
| `box_min` | the highest `since` over `calls`: the oldest box this client serves |
| `box_tested` | the box version whose recorded answers the client's tests replay |
| `calls` | every method the client names: 40 at this commit |
| `verbs` | the dispatch keys and their flags |
| `methods_sha256` | the sha256 of the sealed registry the client was built against |
| `contracts` | each contract module and its tag |
| `client` | the client's version |

Four tests hold the bound, two on each side:

| test | side | fails when |
|---|---|---|
| `TestTheManifestIsCurrent` | client | the committed manifest differs from the tree's own, so a newer call moves `box_min` in a reviewed diff |
| `TestTheCallSetIsServed` | client | the client names a method the vendored registry lacks or has retired |
| `TestReleasedClientsAreServed` | daemon | a method a released client calls (`v0.1.0` and `v0.1.1` are pinned under `api/clients/`) leaves the registry without a retired row naming its replacement |
| `TestRecordedAnswersAreServed` | daemon | an answer the client's tests replay differs from what the daemon serves |

The daemon also checks the client commands it prints against the pinned manifest's `verbs`. At run time, a box older than a method the client calls answers `unknown method`; on main, unreleased, the client then prints the box upgrade that clears it. The bound tracks method names, not parameters: an older box refuses a new parameter by its schema.

## Flows on the client's own engine

This section is on main and not yet released. In `v0.1.1`, `syrvis reboot` and `syrvis power-off` find a standing procedure of their kind and follow it, and call `Power.Begin` only when none stands, so running one again attaches rather than starting a second.

On main, the client runs its multi-step flows as compiled workflow definitions on its own engine instance: one per context, its journal at `~/.config/syrvis/engine/<context>/` under a lock. Three definitions ship in `internal/flows/`: `ladder` for `context test`, and `reboot` and `power-off`, which ask the box to begin its procedure and then follow it.

The start is guarded, because a power request cannot safely be sent twice. Before calling `Power.Begin` the host writes a mark beside the step's key, and after it the instance id the box returned. A later run reads by the id first and follows that instance. A mark with no id sends nothing and waits on a person: the `settle` step names `syrvis --context <name> workflow list` and is overdue after 10 minutes. Only a key with neither mark nor id sends the start.

Only the flow verbs open the context's instance and take its lock, so any printed command runs while a flow waits. A second flow verb on the same context is refused by name with its recovery. The confirm of a reboot or power-off stays on an attended terminal, outside the definition, because the box spends its token when it verifies it.

Planned, and not in this release: a client-driven install and upgrade, in which `syrvis install` pairs with a small installer package on the box, fetches and verifies the main package on your computer, and pushes it, each half a workflow on its own engine.

## The live follow and its renderer

On a terminal, a follow redraws one block in place: a header, one line per step the procedure has reached, and a fleet line, each `<mark> <kind> <action> ... <timer>` (`cmd/syrvis/livefollow.go`). The cursor moves up by the block's own height and no further. The screen is never cleared, history never scrolls, and the finished follow leaves the log form behind, so scrollback reads as a record.

The choice is made once per run (`internal/live`). The live block runs only when stdout is a terminal, and never under `--plain`, `--json`, a set `NO_COLOR`, `TERM=dumb` or `--accessible`, which keeps the prompts. Otherwise the log form prints one line per transition and never rewrites one. Width comes from `COLUMNS`, else the terminal, else 80 columns. Four marks carry every state: a check mark for done, `!` for attention, a middle dot for in progress and an arrow for a transition. Colour is never information.

The package also holds a log-and-footer writer, a JSON object per event, and three voices (`bluf`, `eli5`, `technical`), built for the planned install. At this commit `--voice` is checked against the three names and does not yet change what a verb prints, and `SYRVIS_VOICE` and `SYRVIS_ACCESSIBLE` are not read.

## Printed commands run as printed

The daemon cannot know which context name a caller used, so it writes recoveries as `syrvis --context <ctx> ...`, and the client fills in its own context (`cmd/syrvis/contextfill.go`). A renderer that does not know the context leaves the placeholder standing, since a bare command would aim at a local socket that is not there. Every string from the wire passes one fence before it prints (`TestEveryWireStringTheClientPrintsIsFenced`). The MCP bridge never dispatches a method that carries a secret.

## Provability

No TLA+ model covers the client. Its proof is Go: 1,052 `func Test` declarations in 225 files at this commit, run by `make check` with no box and no network, every listener loopback or a unix socket under a hermetic home.

| evidence | what it holds |
|---|---|
| the recorded answers | `internal/fakedoor` replays the daemon's own recorded answers, and the daemon holds them to what it serves |
| the bound's four tests | the manifest is the tree's, every call is served, every released client stays served |
| the crash tests, on main | under `testing/synctest`: killed at `Power.Begin` and run again, no second begin; killed with the id kept, the follow ends it; the mark alone waits on a person; the lock refuses a second flow |
| the engine's kit, on main | `TestTheHostKit` runs the shipped definitions through the engine's own test kit, then a reboot end to end |
| the definition checks, on main | no definition ends or waits on a boot; `TestTheValidatorBites` breaks `reboot.json` and requires a refusal |
| the printed surface | the wire fence, the four marks, and named tests that hold a printed recovery runnable as printed |

`make check` runs nine gates, from gofmt and vet through the dependency wall and the tests to the em-dash and hygiene scans, and a pre-push hook refuses a push to `main` without a green record.

**Would a model pay?** Not yet. On main, the client's durable state is the engine's journal plus the guarded start's mark and id. The engine's models cover the journal: no acknowledged signal lost, no step closed twice, no second attempt except on a call declared safe to retry; see the [engine's provability section](engine.md#provability). The client's own logic is the three-way read of mark and id, which the crash tests enumerate whole. A model pays when two journals on two machines must agree, as in the planned client-driven install, whose design carries a draft model that no repository holds yet.

**Scenarios.** What the engine's model checks for the flows the client runs, in plain words, is under [Engine on the scenarios page](../provability/scenarios.md#engine).

**Keeping it honest.** The engine's model carries broken twins, copies with one guard removed that must fail, and a trace test ties it to the Go. The client's tests keep the rule in Go: `TestTheValidatorBites` proves the definition check can fail, `TestTheCallSetIsServed` fails when it finds no call to scan, and each crash test counts what the fake door was asked.

**What the October 2026 review found.** The round reviewed TLA+ models, and the client has none, so the findings that bear on it are the engine's, on the [engine page](engine.md#provability). The client's own proof, as its own reviews leave it, stands so:

| finding | what it says |
|---|---|
| proven well | on main, the guarded start: a run killed before the id is kept and one killed after it each have a test, and neither sends the request twice |
| gap | `box_min` (`2.0.0-alpha.67`) sits above `box_tested` (`2.0.0-alpha.66`), so at least one method the client calls was never replayed from a box that serves it |
| gap | the voice and accessibility variables have no row in the hermetic test environment, so the client reads neither yet |
| excess | none recorded |

Both gaps are filed as fixups.

Back to [Provability](../provability/index.md).
