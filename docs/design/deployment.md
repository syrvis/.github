---
title: Deployment
parent: Design
nav_order: 5
---

# Deployment

syrvis-deploy is the part of the daemon that turns a declared fleet into running containers and back. It keeps three guarantees: desired state has one address at every instant, across any crash; a drain preempts every deploy it covers; and nothing the fleet runs, or could roll back to, is erased. Eight TLA+ properties state its drain, stop-order, one-container and retention rules, each checked beside a broken twin that must fail. The October 2026 review found the model sound with gaps and filed ten findings. A Go test then showed the first to be a real defect, which the daemon's code shared. Main now fixes it in both, and fixes five more of the findings in the model.

## Where it lives

syrvis-deploy is a Go library that the daemon `syrvisd` embeds on the box, with no process or socket of its own. It reaches Docker only through the `Containers` and `Stopper` interfaces (`seams.go`). It is tagged `v0.1.1` and requires five [commons](commons.md) modules at `v0.1.1`. The daemon still builds from its own copy of these packages; moving it onto `v0.1.1` is planned. It serves ten methods:

| method | what it does |
|---|---|
| `Deploy.Stage` | stores a bundle as a revision |
| `Deploy.Plan` | shows what an apply would do, and does nothing |
| `Deploy.Revisions` | lists the revisions |
| `Deploy.Apply` | flips `current` to a revision and converges |
| `Deploy.Rollback` | applies an earlier revision (confirmed) |
| `Deploy.Prune` | removes named orphan containers (confirmed) |
| `Drain.Declare` | declares a drain and starts its stop |
| `Drain.Release` | releases a drain and starts its restore |
| `Place.Move` | moves a service's data tree, with a dry run (confirmed) |
| `Task.Run` | runs a declared task unit by name |

A confirmed call carries a minted token that the dispatcher verifies and spends before the handler runs. Apply, rollback and prune also ask the lifecycle table first, so each refuses while the box drains, naming the state and the recovery.

## Revisions and the plan

`Deploy.Stage` turns a bundle into a revision whose id is a digest of the bundle with every secret replaced by a fixed placeholder, so staging cannot test a guessed secret (`internal/deploy/canon.go`).

The plan is a pure function of the world, the revision, the drains and what each container last saw (`internal/deploy/plan.go`). For each service it picks one rung: recreate, restart, start, stop, none, create, land, or a refusal. It pairs a cascade stop and start for each running hard dependant of a recreated service, then orders stops dependants first and bring-up dependencies first, gated on readiness. It never removes: an undeclared container is reported as an orphan, for `Deploy.Prune`. Drain coverage is read before any rung, so a drained service is landed (created if absent, never started) or refused.

An apply verifies the revision's bytes against its id, pulls missing images, flips `current`, converges, and writes exactly one history line however it ends (`internal/deploy/exec.go`). The pull comes first, so a bad image reference fails with nothing changed. A spec change that drops a data mount recreates without a refusal today; a guard for it is planned.

## The store

```text
<state>/deploy/
  key              per-device HMAC key, 0600
  revisions/<id>/  0700, never changed once renamed in
    bundle.json    the bundle, secrets redacted
    meta.json      sequence number and stage time
    bindings.json  keyed HMAC of every secret, 0600
  current          the committed id, a regular file
  applied.json     what each container last saw
  history.jsonl    append-only: seq, id, at, by, action, outcome
```

Two steps change what the store declares, and each ends in one rename (`internal/deploy/deploy.go`). Staging writes `revisions/.staging-<id>/`, fsyncs every file and directory, then renames it to `revisions/<id>/`. The flip writes a temporary file, fsyncs it, renames it over `current` and fsyncs the directory. So a revision directory that exists is whole, and an interrupted apply needs no undo log. `current` is a file, not a symlink, because a symlink cannot be fsynced. Every listing skips dot-prefixed names, so staging directories and tombstones are invisible by construction.

## Declaring a drain

A drain is the one way to suppress a service, and no push of desired state undoes it. `Drain.Declare` takes a scope (`device`, `volume`, `plane`, `set` or `service`), a class, a reason and a policy (`deployapi/drain.go`). The drain stores its selector, never a member list, so its members are resolved each time it is read.

| policy field | values | default |
|---|---|---|
| `dependants` | `refuse`, `cascade`, `strand` | `refuse` |
| `deploys` | `land`, `refuse` | `land` |
| `floor` | `default`, `none` | `default` |
| `on_expiry` | `hold`, `restore` | `hold` |
| `on_boot` | `hold`, `converge` | `hold` |
| `on_restore` | `hold`, `restore`, a power drain only | `hold` |

An expiry is a review deadline, not a timer. A drain moves through `draining`, `drained` and `restoring` to `released`, or to `expired`, and suppresses its members until `released`.

`Declare` refuses when drain writes are blocked, and refuses a stop budget on anything but a device drain (`declare.go`). A second device drain joins the standing one or refuses, naming it. Then the declare cancels the running deploys the drain covers, through each job's context, and starts the stop: a drain that arrives during a long image pull cancels the pull. At `v0.1.0` the stop does not wait for a cancelled deploy's last call to land, the defect under [Provability](#what-the-october-2026-review-found). On main, the declare records the jobs it cancelled. After its waves, the stop waits a bounded time for them to end, then checks once more each member it skipped or stopped, and stops any that came up. When a device drain is written, the service asks the lifecycle table again under its lock, so a hand drain that a starting reboot overtook refuses and writes nothing.

## Stop and start order

`PlanStop` is pure, and a separate executor runs its plan (`internal/converge/drain.go`):

1. The floor, the observability services, stops last: the alarm must not stop with what it alarms about. A drain narrower than the device that reaches the floor refuses `floor_in_scope`.
2. The other members stop in reverse dependency waves, dependants first. A cycle refuses `dependency_cycle`, naming its members.
3. Outside dependants follow the policy: `refuse` names them, `cascade` pulls in hard dependants transitively, `strand` reports soft ones as blocked.
4. A device drain stops declared virtual machines in one wave just before the floor.

Each member climbs a five-rung ladder on one absolute clock (`drain_exec.go`): request the stop, poll until down or out of time, send one SIGKILL if it is still up, verify the kill landed, report. The plan's budget bounds the waves at the executor's parallelism. In the model's fleet, `app1` and `app2` depend on `db`, and the floor member `monitor` does too: a device drain stops `{app1, app2}`, `{db}`, then `{monitor}`, within 7 seconds (2 + 3 + 2).

`Drain.Release` writes the release, then starts the restore (`release.go`). The restore mirrors the stop: dependencies first, each wave waiting until the last is ready, and on a device restore the floor first (`rehydrate.go`).

## Prune and reap

Three things remove, each only what nothing declares or needs:

- `Deploy.Prune` stops and removes named orphans, managed containers the revision does not declare.
- The retention pass keeps the newest N revisions (10 by default), `current` and the rollback target, and renames the rest into a tombstone namespace (`internal/deploy/retention.go`).
- The reaper erases the tombstones (`internal/deploy/reap.go`).

The rollback target is the newest successful revision that is not `current` and still exists; the pass and `Deploy.Rollback` call one function for it, so they cannot disagree. A pass runs at the end of every job that holds the mutating slot, after each stage, and when free space runs low. If it cannot read the listing, `current` or the history, it renames nothing: unknown is never a pass.

## The tombstone before the erase

1. The pass renames each victim to `.collecting-<seq>-<id>` under the store's lock, then fsyncs the directory once.
2. The reaper, off every request and job path, fsyncs that directory before each sweep's first erase, then erases one tree at a time, never taking the store's lock.

A power cut mid-erase leaves a torn tombstone, which no reader lists and which refuses nothing; a torn directory under a revision id would refuse every later stage. The reaper retries a failed erase on its next run and reports erased and outstanding ids.

## Provability

`specs/Deploy.tla` (875 lines) models, over a synthetic fleet of four, the stop planner and each member's ladder on a clock, one service's containers through a recreate from its five crash states with three revisions under retention and a crash, and a device drain declared mid-flight with its cancellations and admission gate. `specs/DeployBroken.tla` holds fifteen broken twins, and the other modules are one-line shims that name each configuration. The model assumes, without proving, that the lifecycle refuses deploy work under a device drain (a cell the lifecycle's own model checks; see [Commons](commons.md#provability)) and that a crash keeping an erase keeps the rename before it.

| property | what it says |
|---|---|
| `NeverTwoContainers` | no service has two managed containers, from any crash state |
| `FloorStopsLast` | no floor member is asked to stop before every other member has stopped |
| `NonDeviceDrainRefusesFloor` | a narrower drain whose cascade reaches the floor refuses |
| `RestoreMirrorsStop` | a device restore starts the floor first, then dependencies before dependants |
| `CycleRefuses` | a drain over a dependency cycle stops nothing and refuses |
| `TombstoneBeforeErase` | no crash leaves an erased tree listed; `current`, the newest N and the rollback target are never renamed |
| `NoApplyUnderDeviceDrain` | no apply, rollback or prune is admitted under the device drain, and under it no reconcile steps beyond a cancelled job's last step and converge's land |
| `StopEnds` | every stop plan ends within its budget, even if a container never dies (liveness) |

`make verify-spec` runs five proofs and the fifteen twins in 63.21 s on a development Mac, the largest proof at 8,514,463 distinct states; two longer runs go before each tag: two crashes at 20,364,481 states, and the store under a service drain at 23,105,292. The scenarios, in plain words, are under [Scenarios: Deployment](../provability/scenarios.md#deployment).

The proofs are kept truthful four ways:

- Every property has a broken twin that must fail on it, and the runner passes a twin only when TLC names that property, so no proof is green by vacuity.
- `specs/mutants.tsv` holds 15 edits to the actions, each of which must turn a proof red; the 19 that stayed green are gone, and `specs/copies_test.go` holds each property's copy of an action to its original in `make check`.
- The proofs check deadlock, so any stuck state but the one allowed end fails.
- Eleven Go tests, each named for its property, drive the library over fakes. `make check` also replays 2,000 behaviours TLC simulates from the model against the library (`verify-trace`), and `conform_test.go` holds the Go's words and the lifecycle's cells equal to the model's.

### What the October 2026 review found

No module is stale, every configuration runs, and each twin fails only on its named property. The review filed all ten findings at the lowest of four severity levels, the first to rise if a Go test reproduced it.

A Go test did, failing on five runs of five. A declare cancels the deploys it covers and starts the stop at once, and the stopper lists only running containers. So a container a cancelled deploy was starting comes up after that list and runs under the drain, while the stop reports every member stopped. It does not reach the power-off, which reads the fleet first and halts while a managed container runs; the harm is a broken drain and a stop report that is wrong. The model allowed that order, but no property read the containers against the drain. The daemon's own copy of this code had the same window. The finding rose to the most severe level, and it is fixed on main in both copies, the daemon's first. The declare records the jobs it cancelled. After its waves, the stop waits for them to end, bounded by the engine's call timeout, then checks once more each member it skipped or stopped, and stops any that came up. The Go test passes five runs of five, beside a second test for a cancelled restore. The daemon's copy now records, the same way, the restores its UPS watcher cancels before its own declare. A start that landed after that last check could still run under the drain, and main has fixed that narrower window too, in both copies: the stop now waits, within a bound, for the engine's answer to each start a cancelled job sent, and reports a start left unanswered, never all stopped.

Since the review, main has fixed the model's nine other findings as well, adding broken twins as it went, and checked the store under a service drain; `specs/README.md` now lists twenty-one twins.

| kind | finding | on main |
|---|---|---|
| defect | A cancelled deploy's in-flight start can land after the stopper listed its service, so the service runs under the drain (reproduced in Go). | fixed in the code, here and in the daemon |
| gap | The model admits a prune at `drained`, which the lifecycle refuses. | fixed in the model |
| gap | The rollback target is checked only where every apply succeeded. | fixed in the model |
| gap | The ladder omits the halt between waves and the skip of an empty member. | fixed in the model: `NoLadderOnAbsent` holds the skip, `StoppedStaysDown` the fix's settle, and the model states that no conductor halts the stopper |
| gap | No configuration reaches the floor guard for a scope that holds the floor directly. | fixed in the model |
| gap | The restore's readiness gate is modeled and never checked. | fixed in the model |
| excess | The filesystem-order assumption is now met by the reaper and can leave the model. | fixed: the assumption has left the model |
| excess | The model's vocabulary lists are narrower than the Go's and unread. | fixed: `conform_test.go` holds each list equal to the Go's |
| excess | The model's code citations point at the daemon's older copy. | fixed: every code anchor points at this repository |
| excess | 49 property copies and 19 green mutant rows test the model against itself. | fixed: `specs/copies_test.go` holds each copy to its original, and the green rows are gone |

Each finding is filed as a fixup in syrvis-deploy's list of work. The method behind these proofs is on [Provability](../provability/index.md).
