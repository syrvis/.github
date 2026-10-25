---
title: Engine
parent: Design
nav_order: 2
---

# Engine: syrvis-workflow

The engine is a Go library that a host compiles into its own binary to run workflows durably on one box. It runs each effect at most once per attempt and keeps every fact in one fsynced journal. What it cannot know, it reports as unknown and holds for a person. Its liveness promise: every admitted step is begun within a stated bound of up-time. Once begun, it closes or holds within its budget, or the engine reports it stuck with its cause and pages. The syrvis daemon and the syrvis client each require it at `v0.2.0`.

## What it is

The module `github.com/syrvis/syrvis-workflow` holds one package, `workflow`, on the standard library alone. An instance lives inside its host's process, with no socket and no worker process, and two instances in one process share nothing. The engine assumes one host, one clock and one writer, so it carries no partition or clock-skew machinery. The syrvis daemon builds its instance at boot; the client embeds one per run, which replays, ticks and exits.

## Definitions

A definition is a JSON document, schema `syrvis.workflow/1`: a namespace, a name, a version, inputs, a start, steps, a failure step and outputs. It names operations, conditions and signals by key and never carries code. A step has one of three shapes:

- `call` runs an operation the host registers, with its idempotence, guard, lease and default budget.
- `wait` closes on a signal from a person or the host, a condition, a timer, or `any` of up to three.
- `child` starts, or attaches to, an instance of another definition.

No expression language exists: `when` compares a binding with a literal or reads a host condition, and `next` moves only forward. A binding reads `$inputs`, `$steps`, `$instance` or a `$host` value the host registers.

Five templates preset the start, expanded before hashing; a member the document writes wins.

| template | preset |
|---|---|
| `task` | one standing instance per key, and a failure step waiting for a person's `ack`, due in 24 h |
| `singleton` | one standing instance; an equal start attaches to it |
| `multistep` | one standing instance per key |
| `subflow` | started only by a parent's `child` step |
| `scheduled` | started only by the engine's clock |

Definitions are compiled into the host and handed to `New` in `Config.Definitions`; nothing is published at run time. `Open` validates each against the host's registry and refuses to open on a fault. Each refusal names the member's path, such as `steps[1].call.args.k`, a fault word and its recovery. Refusals include `retry` on an operation that is not idempotent, a person's wait with no `due`, and a call with no budget. A duration must be one Go reads: `168h`, never `7d`. A member its step never reads is refused as `member_unread`.

## Versions

A version is pinned by the sha256 of its expanded bytes and never changes. An instance stays pinned to the version it started on; only a migration moves it. A build retires a version by no longer carrying it. A standing instance on a dropped version then moves forward by one journaled `migrated` record. A carried version's `migrate` block must reach it, at most six versions back. Otherwise it holds `version_absent`, and `Health` names the refusal and its recovery. A begun item never migrates.

## The journal

Each engine instance has one append-only journal, CRC-framed and fsynced, with a snapshot. A frame may batch records, which land together or not at all. Everything else, the queue included, is derived from the journal at replay. A torn last frame is cut aside and reported. A failed fsync latches the journal, and every instance reads `record_inconsistent` until a restart.

Retention drops a whole family of linked instances 30 to 31 days after its last member ends, and never a standing, held or begun one. It runs only while the clock vouches. A retried start naming a dropped instance's request id is refused `request_unknown` for a year.

## The queue and its leases

A work item is one attempt of one call step, and its idempotency key, `(instance, step)`, is the same on every attempt. A ready item is offered until a runner begins it; an expired lease or a restart makes it ready again. A runner acts only after `Begin` journals `begun`, and `Begin` succeeds once per attempt. So the offer is at least once and the effect at most once. A retry exists only after a `Fail` on an idempotent operation whose step declares `retry`.

A lease lives in memory, 30 s by default, between 5 s and 10 min. Its token names the engine's epoch, the item and a counter that never resets, so a stale token begins nothing. `Serve`, the library's worker pool, calls `Begin` before the operation runs and heartbeats while it runs.

The outcome between an effect and its `done` record is unknown, and the engine says so. An item begun when its lease is lost, or whose operation panics, holds `outcome_unknown` and is never begun again. A late answer under the begun token lifts the hold, or a person abandons the instance. One exception: a step marked `ends_the_boot` whose boot id moved closes `done (boot moved)`.

Emergency items are offered first. An operation may declare `max_concurrent`, counting begun and held items. A reserved worker leases emergency items only, so an emergency stop never waits behind ordinary work.

## Waits and human confirms

A human step is a wait on a signal `from: person` under any name, such as `confirm`, `ack` or `done`. `choices` limits the answer, and `fields` types each field `text`, `whole` or `duration`. A `Confirm` that breaks these is refused with its path, fault and recovery, and the step keeps waiting. Every signal is journaled before its sender is answered, and a resend under the same request id is a no-op.

A confirm may cover a later guarded call: the person sees the arguments and the digest the operation's deriver computed. `Begin` derives the digest again and fails the call on drift. It reads the digest only from a person's covering confirm, marked `covers` in the journal.

A condition is polled each tick off the engine's lock, and an unknown answer refuses or holds, never passes. A timer's instant is journaled at entry, so it fires once across restarts. A baseline wait on a condition the host marks `Boot` is answered from the engine's own boot id.

## Schedules

The engine starts a scheduled definition on its own tick; no caller may claim the `schedule` door. The first start is due at the first tick the clock vouches for after the first `Open` that carries the schedule. Later starts fall a whole `every` from that anchor, journaled in a `scheduled` record. After a stop of any length the engine starts once, not once per missed period. Under `standing: one` or `one-per-key`, a due period passes with no start while an instance still stands. Nothing starts while the clock does not vouch, and `Health` names `clock_unsynced`.

## Budgets, dues and stuck reports

Every call attempt has a budget, the step's or the operation's default. Every wait on a person, a host signal or a condition has a due, and an instance may carry a `span`. Each pages a person, again at each `page.every`, and never revokes work. At each one-second tick the engine reports what is late, with its cause, through `Health`, `Get` and the pager.

| cause | when | recovery |
|---|---|---|
| `no_runner` | ready past 2 ticks, no worker for its key | give `Serve` a worker |
| `not_leased` | ready past 2 ticks, its workers busy | more workers |
| `lease_churn` | three leases expired before `Begin` | read `Serve`'s log |
| `over_budget` | begun past its budget | pages again each `page.every` |
| `overdue` | past its due, or past the span | pages again each `page.every` |
| `engine_stalled` | no tick for 120 s | restart the host |
| held `outcome_unknown` | a lease lost after `Begin` | a late answer, or an abandon |
| held `record_inconsistent` | the journal latched | free the volume, then restart |
| held `unresolved` | a key the version names is unregistered | register it again |
| held `version_absent` | the pinned version is not in the build | ship a build with it, or abandon |

## The API

The engine's contract is Go functions and methods in package `workflow`, with no wire API.

| group | names |
|---|---|
| life | `New`, `Open`, `Run`, `Stop`, `Health` |
| definitions | `Decode`, `Validate`, `ValidateFor`, `Definitions`, `Definition` |
| instances | `Start`, `Get`, `Confirm`, `Observe`, `Abandon`, `List`, `Signal`, `Events` |
| runners | `Lease`, `Begin`, `Heartbeat`, `Ack`, `Fail`, `Release`, `Serve` |

The host hands `New` one `Config`: a `Store`, a `Clock`, its `Definitions` and `Operations`, `Conditions`, `Values`, `Admission`, a `Pager` and an `Events` sink. The library ships `OpenFileStore` as the store. Callbacks other than `AdmitStart` run off the engine's lock, each under a 5 s deadline, and should answer within 200 ms.

The host's own API stands in front, and the engine is never exposed. In syrvis the operator's window is the daemon's API, through the client's `syrvis workflow list`, `get`, `observe`, `confirm` and `abandon`, which read and steer instances and never create one. A start comes only through a service's operation or door; see the [daemon](daemon.md) and the [client](client.md).

## What it leaves out

- No exactly-once claim for an effect: the window after `Begin` is reported unknown.
- No run-time publishing: a definition changes only with a build.
- No revoking: a budget, a due or a span pages and never stops work.
- No assumed progress: a person may never act and a condition may never hold, so both end in a page.
- No queue over a message bus: a host's bus is a wake that calls `Signal`, never the truth.

Across daemons, the design plans a journaled call into the other daemon's own engine, with a feed library once a second daemon exists.

## Provability

Two TLA+ models check the design, and trace tests tie them to the Go.

- `Queue.tla`: the work queue, with two instances, two workers and a reserved emergency worker, tokens, `Begin` before any effect, expiry, retries and crashes.
- `Engine.tla`: the evaluator over every valid one-step program (22) and five fixed ones, with crashes, rebuilds, reboots, replay and migration, over a stub queue.
- `Composed.tla`: the engine model over the queue model, one instance of two calls, both sets of invariants at once.
- `EngineFull.tla`: the engine's invariants over every valid program of two steps (1,006) and three steps (65,040), about an hour, outside the everyday gate.
- `QueueTrace.tla`, `EngineTrace.tla`: each model with a label per action, so TLC's random traces replay against the Go.
- `QueueBroken.tla`, `EngineBroken.tla`: the duals; three one-line shims run the liveness properties and a floor with no migration.

The queue model checks twelve invariants, such as `AtMostOneBegin` and `NoEffectTwice`, over 1,014,379 distinct states, and three liveness properties. The engine model checks fifteen, such as `PinnedForLife` and `ConfirmByHuman`, over 479,849 states, and `Ends`, `PagesOn` and `HeldLifts`. The [engine scenarios](../provability/scenarios.md#engine) explain each in plain words.

Each guard has a broken twin, a dual, that must fail. The queue has ten duals and the engine sixteen, one of them for the property `Ends`. The runner reads a dual green only when TLC names its violation, so no proof is green by vacuity. Each trace test replays 2,000 TLC traces against the real queue or engine, step by step, with zero divergences allowed. Go mutants in the replays must diverge, and the crash tests stop the engine at every point of its crash table.

The October 2026 review read both model families at the commit this page describes and filed 25 findings. One exposed a live defect in the Go, one of the two the whole round found (the other is the [deployment](deployment.md#what-the-october-2026-review-found) service's); the other 24 are at the lowest severity.

That defect sat where the queue model has no held instance. An emergency item of a held instance, leasable by no one, stopped every ordinary lease on the box. It was reported as `not_leased`, whose recovery, more workers, is wrong. It was reproduced and fixed after the reviewed commit, and the fix ships in `v0.2.1`, a planned patch version.

| kind | where | what the review found |
|---|---|---|
| proven well | both | Every guard is wired, every dual reaches its violation, and the replays hold the Go to the models step by step. |
| gap | `Queue.tla` | Four rules have no invariant, among them that a held attempt is never retried and a token's counter never resets. |
| gap | `Engine.tla` | `ConfirmByHuman` checks the digest, never that a person confirmed; the Go refuses a timer's close, but the model would miss a regression. |
| gap | `Engine.tla` | The failure step, a signal to a held instance, and an unknown condition answer are outside the model. |
| gap | liveness | Only `Ends` has a dual, and the composed model checks no liveness. |
| excess | both | `NoSuccessReportedFailed`, `MovesWhenDropped` and `EmergencyBound` cannot fail, and two queue invariants hold by construction. |
| excess | `Queue.tla` | `BudgetBound` proves a queue page the engine discards; the page a person gets is the evaluator's, held by a Go test. |
| excess | `EngineFull.tla` | Its program set lags a validator change in both directions. |

Every finding is filed as a fixup in the engine's own list of work. The [provability overview](../provability/index.md) covers every component.
