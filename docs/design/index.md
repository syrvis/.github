---
title: Design
nav_order: 3
has_children: true
---

# Design

Syrvis runs one daemon per box, `syrvisd`, assembled from Go libraries that each stand alone with their own tests.
The libraries that hold state also carry a TLA+ model, which TLC checks in a repository's gate: the commons' lifecycle model is checked in `syrvis`.
The client reaches the daemon through one API over mutual TLS, and that API's registry is composed from one contract package per service.
Five repositories hold the libraries and the client; `syrvis` assembles the daemon and serves the API.
This page is the map, and each component has a page of its own.

## The shape

```text
your computer                           the box (a Synology NAS on DSM 7)
+---------------------+                 +-----------------------------------------------+
| syrvis              |  srpc/1 over    | syrvisd                                       |
|   verbs, MCP bridge |  mutual TLS,    |   transport door: pin, seat, judge            |
|   engine (on main)  |  7447/tcp       |   dispatcher: one sealed method registry      |
|   dial: pin, seat   | --------------> |   services: lifecycle, deployment, chores     |
+---------------------+                 |   engine: journal, durable queue, workflows   |
                                        |   commons: primitives, probes, grading, frame |
                                        +-----------------------------------------------+
```

Inside the daemon, two halves stay apart.
The substrate answers what is true about the box: the census, the probes and the health fold.
The orchestrator makes declared state so: intent, convergence, drains, jobs and the power conductor.
Neither imports the other, only the wiring packages compose both, and `internal/archtest/` in `syrvis` fails the gate on a crossing.

The running system has three layers.
Layer 0 is the host and the agent.
Layer 1 is the box's own platform services, such as the edge proxy, which the agent stands up from its own registry.
Layer 2 is the fleet a declared revision names.
Boot brings them up in that order, and deploy work waits for layer 1 to read ready.

## The components

| Component | Repository | What it owns | Its TLA+ model | Page |
|---|---|---|---|---|
| Daemon | `syrvis` | the DSM package, the assembly, the lifecycle and chores services, the API server and its sealed registry | `Chores`, `Conductor`, `EventBus`, `SeamCred`, `SeamFraming` and the `Workflow` family; its gate also checks the commons' `Lifecycle` | [Daemon](daemon.md) |
| Engine | `syrvis-workflow` | the evaluator, the journal, the durable work queue, versions and migration, steps that wait on a person | `Engine`, `Queue` and `Composed`, each tied to the Go by a trace replay | [Engine](engine.md) |
| Client | `syrvis-client` | the `syrvis` command, the MCP bridge, and on main, unreleased, an engine host for reboot and power-off | none; tests hold the printed commands | [Client](client.md) |
| Transport | `syrvis-mtls` | `pin`, `seat` and `dial`, the decision both ends share | none in its repository; `SeamCred` in `syrvis` models the credential plane around it | [Transport](transport.md) |
| Deployment | `syrvis-deploy` | revisions, plans, convergence, the drain set, the stop and restore plans | `Deploy`, `DeployStore`, `DeployCycle` and `DeployLive` | [Deployment](deployment.md) |
| Commons | `syrvis-common` | seven modules below the services, from `primitives` to `secretstore` | `Lifecycle`, kept in `frame/lifecycle/` and checked in `syrvis` | [Commons](commons.md) |

`syrvis` requires `syrvis-workflow` at `v0.2.0`, `syrvis-mtls` at `v0.1.0` and all seven commons modules at `v0.1.1` (`go.mod`).
The client's release, `v0.1.1`, requires the transport and the box's contract module, `github.com/syrvis/syrvis/api`; its main branch adds the engine, unreleased.
`syrvis-deploy` is tagged `v0.1.0`, but the daemon still builds its own copy in `internal/deployment/`; switching to the tag is planned.

## How the daemon composes them

The design gives every library the same seven rules:

1. A library meets another only through an interface the consumer owns, or a shared value type; only the assembly imports them all.
2. `New(cfg)` validates and does no I/O, `Open(ctx, root)` takes the library's folder, `Ready()` reports, and `Close()` releases.
3. A library owns one folder under the daemon's state fence, lent as an `*os.Root`, and no other file.
4. A library never registers itself: no `init()` side effect, no global registry, no package-level singleton.
5. A service hands its operations, conditions and definitions to the engine's `Config` at build time, and no definition arrives at run time.
6. A step's code runs in process, called by the engine's workers; no worker process or socket sits between libraries on one box.
7. A library that serves methods keeps its contract package beside its code.

What holds today: `TestTheTaggedEngineHasOneDoor` (`internal/archtest/engine_wall_test.go:115`) keeps `internal/daemon/engine.go` the only importer of the engine.
The deployment facade in `syrvis-deploy` has `New`, `Open` and `Ready`, and its `Close` is not built yet.
One `assemble` function in fixed, ordered steps is planned; today `internal/daemon` wires the libraries in its constructor.

## One API

The box serves srpc/1, which is length-framed JSON-RPC 2.0.
Your computer reaches it over mutual TLS on 7447/tcp, and the destructive class answers only at the attended local socket on the box.

`api/methods.json` is the sealed registry: 45 methods at `2.0.0-alpha.67`, and each retired name beside the method that replaced it.
Six contract packages each hold a fragment of it: `daemonapi`, `lifecycleapi`, `deployapi`, `seatapi`, `choresapi` and `box/receipt`.
`api.Seal` (`api/api.go:223`) composes them, and it refuses a name two fragments serve or a retired name served again.
`TestTheBoxSealIsTheSealedFile` (`internal/daemon/seal_test.go:58`) holds the composed registry JSON-equal to the file; generating the file from the fragments is planned.

One implementation sits behind every surface: one registry, one dispatcher, one capability judge and one wire client.
The command line, the MCP bridge and the OpenTofu provider share them, and the provider's build guard keeps prune and rollback out of its reach.

A client proves a seat: a roster row with a grade and an expiry, in the daemon's own store.
An operator seat reaches reads and the converge class, and a read-only seat is refused past reads.
Every act records its actor: a uid, a seat or a workflow instance.

The engine's own API is not exposed.
A person or a program sees workflows through the daemon's methods `Workflow.Get`, `Workflow.Observe`, `Workflow.Confirm` and `Workflow.Abandon`.

## Two engines while the move finishes

The daemon carries two engines for now.
New starts go to the tagged engine from `syrvis-workflow`: the power procedures, the drain pair, the UPS pair, credential renewal and declared chores.
One path still reaches the older engine, `internal/workflow`: the chore reconciler's start for a kind other than credential renewal.
The older engine also finishes instances that stood before their kinds moved.
Its removal is planned, and its model, `specs/Workflow.tla`, retires with it.

## More than one daemon

This section is planned; none of it is built.
The same libraries are designed to serve several daemons, each with its own engine instance and API.
A layer 1 daemon would start as a profile of the same assembly, and become a binary only when a box needs it alone.
Daemons would share libraries pinned at build time, never a store, a journal, a lock or a process.
Between daemons, a workflow would advance by a journaled call into the receiving engine, idempotent by key.
The event bus stays an observation plane, since it is lossy by design and its sinks never block the publisher.
A durable feed library is planned for when a second daemon exists.

## Open questions

1. When does the daemon build with `syrvis-deploy`? Check: `grep -n 'syrvis-deploy' go.mod` in `syrvis` prints a require line, and `internal/deployment/` is gone.
2. When does the older engine retire? Check: `ls internal/workflow specs/Workflow.tla` in `syrvis` reports no such file.
3. When is `api/methods.json` generated? Check: `TestTheBoxSealIsTheSealedFile` compares bytes rather than JSON values.
4. When is the composition itself proved? Check: `specs/Assembly.tla` exists in `syrvis`, and `make verify-spec` runs its cfg.

## Provability

Each model states what it assumes of its host and what it guarantees.
For safety properties, composing two models is their conjunction, so a seam holds when each side's assumption is the other side's guarantee.
Liveness does not compose for free: a library's progress rests on its host's fairness, and that premise needs a proof on the composed system.
That proof, `Assembly.tla`, is planned.
Until it lands, each seam below is checked from one side, or by a Go test.

| Seam | The library assumes | Checked today by |
|---|---|---|
| engine and its host | the host ticks, answers each callback within its deadline, and keeps a worker per key plus a reserved emergency worker | the engine's host kit tests, and `TestTwoInstances` under `-race` |
| deployment and lifecycle | a drained box admits no apply, rollback or prune | `Lifecycle.tla`'s `Quiescence`; `Deploy.tla` takes it as an assumption |
| engine and admission | admission is a pure read under the engine's lock | the lifecycle table's conformance test |
| transport and daemon | the judge runs under the daemon's clock and lock, and the seat store is the daemon's folder | `SeamCred.tla`, and `TestTransportSeamVector` |
| dispatcher and libraries | every registered method has one handler and one schema | the seal test and the schema tests in `api/` |
| engine and event bus | a slow subscriber overflows rather than blocking the publisher | the commons' Go tests; `EventBus.tla` checks only that the overflow signal closes once, and models code that has moved |

Most properties have a dual: a copy of the model with one guard removed, which must fail.
A dual guards against a property that passes because it checks nothing, and the review lists the properties that have none.
In `syrvis-workflow` and `syrvis-deploy` a dual counts only when TLC reports its named property violated.
Some duals in `syrvis` are graded on a reached latch instead, which shows less.
Trace tests tie models to code: the engine and the queue each replay 2,000 TLC traces against the Go, and a divergence fails.
The lifecycle's Go tables are held byte for byte to the model's literal by `TestTheGoTablesEqualTheSpecificationsLiteral`.

In October 2026, six reviewers read every model against its code.
They asked whether each proves the right things, enough, and not too much, and reported 71 findings.
Two name real defects in the code, and Go tests then reproduced both.

- The queue model has no instance hold, so it could not see one held emergency instance stop every ordinary lease on the box. The engine fixed it with one condition and a unit test, and the fix ships in `v0.2.1`, which is planned.
- The deployment model lets a cancelled job's last step land after the stop has reported its service stopped. So a service that is mid-start when a device drain is declared can come up and run into the power-off. A Go test in `syrvis-deploy` reproduces it, the daemon's own copy of the code has the same window, and it is being fixed in the daemon first.

| Family | Findings | Proven well | Most worth fixing |
|---|---|---|---|
| Queue (`syrvis-workflow`) | 11 | every guard's dual reaches its violation, and the Go follows the model step by step | no instance hold, which hid the first defect above, now fixed in the Go |
| Lifecycle (`syrvis-common`, checked in `syrvis`) | 13 | the table in the model is the Go table, byte for byte | no property proves that a reboot never stands over a released drain |
| Daemon services (`syrvis`) | 14 | `Chores`, `SeamCred` and `SeamFraming` are sound, with gaps | `Conductor` proves the wrong thing, and `EventBus` models code that has moved |
| Engine (`syrvis-workflow`) | 14 | every dual reaches its violation, and the trace replay holds | `ConfirmByHuman` checks the confirmed arguments, never that a person confirmed |
| Deployment (`syrvis-deploy`) | 10 | each dual plants one bug, and `DeployCycle` covers its whole space | no property reads the containers against the drain, which hid the second defect above |
| Old workflow engine (`syrvis`) | 9 | in force, with gaps, for the engine it models | it proves the engine that is leaving, at about six and a half minutes of local TLC |

The gaps are proving too little: a guarantee no property states, or a shape the code has and the model cannot reach.
The excess is proving too much, or proving code that has moved.
Examples are the model of the retiring engine, the stale bus model, and a program set that lags its validator.
Each finding is being filed as a fixup in the list of work of the repository it names.

Each component page ends with what its own models prove and miss.
[Provability](../provability/index.md) explains the method, and [Scenarios](../provability/scenarios.md) lists what TLC checks, in plain words.
