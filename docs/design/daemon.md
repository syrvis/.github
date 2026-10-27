---
title: Daemon
parent: Design
nav_order: 1
---

# Daemon

`syrvisd` is one static Go program on a Synology NAS running DSM 7, installed as a DSM package. It reads what the box is, changes what the box runs only toward a declared intent, and grades health against that intent. The `syrvis` repository holds the daemon, its package, the box's API contract under `api/` and the local services. This page describes its main branch at version 2.0.0-alpha.67, and marks as planned anything not built.

## The process

One process runs per box, built from the Go standard library and first-party syrvis modules: the [engine](engine.md), the [transport](transport.md) and the [commons](commons.md), each pinned to a tag and vendored, and the nested module `api/` from the same tree. Two doors speak srpc/1, which is JSON-RPC 2.0 in length-prefixed frames. A local UNIX socket serves the box, and an API door serves remote callers over mutual TLS (mTLS). Tests keep the substrate, what is true about the box, and the orchestrator, what should run, from importing each other.

`syrvisd serve` runs the daemon. `syrvisd rescue` answers the census with no daemon, socket, state store or home. `syrvisd init` is the first run, below.

## The package and the root step

A release ships `syrvisd-<version>.spk`, DSM's package file, with sha256 files for the package and for the daemon inside it. After Package Center's Manual Install, DSM starts the daemon as the package's own user, which reads and changes nothing.

The one root step, `syrvis-enable`, is the whole privileged part of an install. It prints the daemon's sha256, then copies it to a root-owned path outside the package tree, so the package user never rewrites what root runs. It installs a rescue copy and a boot stub on the system disk, runs `syrvisd init`, and promotes the daemon to a supervised root service. An SPK upgrade leaves the old build serving until `syrvis-enable` runs again, and that run restarts the daemon only when the running build is stale. `spk/validate-spk.sh` reads each built package the way DSM will. Package signing is not built; the printed sha256 is the integrity check.

## The init flow

`syrvisd init` is the one device-side first run. A run takes any of its halves in one attended act:

| flag | what it writes |
|---|---|
| `--home /volumeN/<share>` | the managed home, its marker, and this install's identity |
| `--api-listen <address>:7447` | the API door's address; with none given or declared, it refuses to choose and lists the candidates |
| `--api-client "<line>"` | the first client's seat |
| `--docker-socket <path>` | the container engine the box converges through |
| `--arm-compensation` | self-repair for the named invariants |
| `--service-user <name>` | a service's account, with no login and outside administrators |

The product fixes no volume or share name. There is no `syrvis init`: the client's `syrvis next` asks the box what it still needs, prints the one next act, and writes nothing. A refusal before a stranger's first install gets anywhere is a defect.

## The API contract

`api/` is the nested module `github.com/syrvis/syrvis/api`, standard library only, which the client and the OpenTofu provider require. It holds the frame (`Actor`, `Handler`, `Typed`, `Fragment`, `Seal`), the srpc/1 framing and wire client, the wire types under `api/box/`, and the sealed registry `api/methods.json`. Six contract packages split the registry: `daemonapi`, `lifecycleapi`, `deployapi`, `seatapi`, `choresapi` and `box/receipt`.

Each row names a method, its class (read, watch, converge or destructive), its tier, the release that added it, a summary and a params schema. Writes refuse unknown fields; reads are tolerant. A method's summary states its burden: who calls it, and why no existing read or declaration can carry it. A retired method stays listed with its replacement.

The registry lists 45 methods and six retired names. Its five receipt methods first ship in 2.0.0-alpha.68, for the planned client-driven install. A test holds the seal of the six fragments equal to the file; generating the file from them is planned. `Meta.Methods` with `parts: ["workflows"]` also serves the box's workflow registry: each kind, its versions, its steps and the method that starts it.

## The local services

The services run in one process. Each consumer owns the interface it calls, calls pass Go values, and a refusal is a typed value that names its recovery. The event bus is for observation only: a slow reader sees a gap, and the bus never advances a workflow.

| service | code | model |
|---|---|---|
| power lifecycle | `internal/lifecyclesvc`, over the commons' table | `Lifecycle`, `Conductor` |
| deployment | `internal/deployment` | `Deploy`, in `syrvis-deploy` |
| chores | `internal/choresvc` | `Chores` |
| workflow engine | `syrvis-workflow` v0.2.1 on main (v0.2.0 in `2.0.0-alpha.67`) | in its own repository |
| seats and the API door | `internal/apiroster`, `internal/server`, `syrvis-mtls` | `SeamCred`, `SeamFraming` |
| substrate | the daemon, with the commons' event bus | `EventBus` at `2.0.0-alpha.67`, retired on main |

The [deployment](deployment.md) service stops services when the lifecycle says so, and refuses a deployment the daemon did not start while the box is drained. Moving the daemon onto the service's copy in `syrvis-deploy` is planned.

### Workflows

Every definition is compiled in beside the engine, and nothing is published at run time. Nine kinds ship: `drain-device`, `restore-device`, `planned-reboot`, `power-off`, `power-off-hold`, `credential-renewal`, `declared-chore`, `ups-stop` and `ups-restore`. A person reads and steers an instance through `Workflow.Get`, `Workflow.Confirm`, `Workflow.Observe` and `Workflow.Abandon`. A start comes only through a service's door, such as `Power.Begin` or `Task.Run`. The older in-process plane, `internal/workflow`, finishes instances that predate the tagged engine, and its removal is planned.

### Power and the lifecycle

The box is in exactly one of seven places: `in-service`, `draining`, `drained`, `shutting-down`, `down`, `booting` or `unfit`. One table of 208 cells, by place, side marks and operation, answers every admission. One `Admit` function serves the start door, the fence and the instance id mint. A drained box starts no deploy, and on battery no release or service work starts. One reboot or shutdown stands at a time, and the UPS stop is admitted everywhere but `down`. Every refusal names the place, the operation and what would admit it.

The fence reads without a lock, and a drain write asks again under the admitter's lock. So a hand drain that a reboot overtook refuses and names the reboot, while the reboot's own drain step passes.

`Power.Begin` starts `planned-reboot`, `power-off` or `power-off-hold`. `Power.Down` is the last second: it adopts the standing device drain, verifies the fleet down, writes a deliberate-stop stamp and powers off. An unclean stop halts and never forces the poweroff. `Power.Restart` refuses until a DSM-safe reboot path is measured.

On battery, the power conductor declares the same drain a person would. It weighs the drain left against the runtime left, and powers off only with the terminal lease held and the fleet down. `ups-stop` needs no confirm, and `ups-restore` restores the services if power holds. At boot, a device drain is released only when an earlier boot's stamp is present and the drain says `on_boot converge`. Planned: a DSM update as a procedure of its own, and a bounded, ordered stop when a reboot the daemon did not start reaches it.

### The drain

A drain is the one way to suppress a service, for the device or for named services. It lives in the daemon's own store with a root-only mirror, ordered by one sequence number, and no push of desired state changes it. `Drain.Declare` runs a reverse-topological stop as a watchable job, and `Drain.Release` runs the readiness-gated restore. A drained, stopped service reads drained, never broken. Reboot and power-off share the drain through the `drain-device` and `restore-device` child workflows.

One defect was found here, and it is fixed on main, after the `2.0.0-alpha.67` tag. A device drain cancels the deploys it covers and starts its stop at once, and the stop lists only what is running. So a service a deploy was starting could come up after that list and run under the drain, while the stop reported every member stopped. It did not reach the power-off: `Power.Down` and the battery's power-off each read the fleet first, and halt or run the stop again while a service runs. A Go test reproduced it. Now the drain records the jobs it cancelled. After its waves, the stop waits a bounded time for them to end, then checks once more each member it skipped or stopped, and stops any that came up. The [deployment](deployment.md#what-the-october-2026-review-found) page has the detail, and the narrower window main has since closed.

### Chores

`credential-renewal` starts when a seat's renewal window opens. `declared-chore` runs a service's declared task on its schedule, inside that service's container. It holds and pages a failed run until a person acts, and pages a run past its budget. Read from a feed, a declared unit's output, each open item gets one instance and clears only on a complete reading. `Chores.Declare` takes a consumer's chore as data. The service holds it in memory, so a restart drops it; keeping it on disk is planned.

### Seats and the API door

Each remote caller holds a seat in the daemon's roster: a public key, a grade (read, operator or admin), its address and an expiry. Only the public key travels, and the client pins the daemon's key. The door judges each connection at accept and each call at dispatch, and a 30-second sweep reaches quiet connections. No grade reaches the destructive class remotely, enrolment and revocation answer only at the local socket, and a remote grade change can only lower. Every act records its actor as one event. The [transport](transport.md) page has the rest.

## Health as conformance to declared intent

Health is the conformance of observed state to declared intent, never uptime. `Status.Get` answers one verdict, `ok`, `degraded`, `unhealthy` or `not-bootstrapped`, with its reasons most severe first and a readiness gate for each lifecycle move.

- Unknown is never a pass: an unanswered fact grades unknown, and `fact.Observe` is the one constructor that may answer.
- A declared absence is an answer, and a declared capability that is not observed grades broken.
- A deliberate state is not drift: a drained service is not a failed one.
- An identity fault, such as a missing volume, pages and is never fixed by a guess.

`syrvis verify` prints one row per host invariant. Compensators ship in the binary, armed per row by the person; none has yet been observed repairing a box.

## Provability

TLC, the TLA+ model checker, walks every reachable state of a model within its bounds. At `2.0.0-alpha.67`, `specs/` holds seven model families in 36 configurations: nine proof cases and 27 duals. Main has since retired `EventBus` and its one configuration, leaving 35.

| model | what it checks |
|---|---|
| `Lifecycle` | The commons' table: no deploy work while the box drains, is drained, shuts down or is off; one reboot or shutdown at a time; the UPS stop can start unless the box is off. |
| `Workflow` family | The old plane: one instance survives crashes, reboots and lost writes, and never repeats a step not declared repeatable. |
| `Chores` | One instance per open item, one page per window, and no clear on an incomplete reading. |
| `Conductor` | One drain per battery episode, never against a person's drain, and power-off only with the lease held and the fleet down. |
| `EventBus` | A saturated subscriber's overflow signal closes at most once. Retired on main, where the commons' Go explorer is the bus's one proof. |
| `SeamCred` | No forged grade, no revoked key back, and no call beyond its grade. |
| `SeamFraming` | Every message arrives intact and in order, and an oversize frame is refused. |

The scenarios, in plain words, are on the [scenarios page](../provability/scenarios.md#daemon).

**How the proofs are kept honest.** A property should have a dual, a broken twin with one guard removed, which TLC must show failing, so no proof is green by vacuity. `make verify-spec`, part of `make check`, refuses to pass when no configuration ran or the toolchain is missing. No trace test ties these models to the Go. Instead, the commons' Go table equals the model's literal byte for byte, the old plane's fixtures equal the model's programs, and Go explorers search the real conductor step and the bus algorithm.

**What the October 2026 review found.** Three reviewers ran TLC on mutated copies of these models and filed 36 findings. None is in the two most severe levels, and none shows a live bug in the daemon's code. The drain defect above, now fixed, came from the deployment service's model, whose code the daemon shares.

| verdict | finding |
|---|---|
| proven well | The lifecycle guard is the admission table itself, held byte for byte to the Go, and its four duals bite. |
| proven well | The Chores and Conductor duals bite, and so do `SeamCred`'s two escalation duals. |
| too little | `SeamCred` never checks the per-call re-judge, the space where a since-fixed bug lived. |
| too little | The lifecycle model forbids a drain release that the product allows by abandoning the reboot, and lacks three releases the code performs. |
| too little | The old plane's model never reaches the shipped reboot's boot-wait shape, and the conductor's pause is not modeled. |
| too little | The commons ran no model checker over its lifecycle source, which its own gate now does, and `Assembly.tla`, the fence-then-write proof, is planned. |
| too much | The `Workflow` family proves the plane that is leaving, at about six and a half minutes of TLC per local gate. |
| too much | `EventBus.tla` models code that moved to the commons (retired on main since), and most `Conductor` and `Chores` invariants restate their own guard. |
| too much | `SeamCred`'s stale-serve property is stricter than the design, which serves a quiet connection until the next 30-second sweep. |

Each finding is being filed as a fixup in the list of work of the repository that owns its model. The method, and every component's models, are on the [provability overview](../provability/index.md).
