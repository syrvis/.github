---
title: Provability
nav_order: 4
has_children: true
---

# Provability

Syrvis model-checks the parts of its design where concurrency, crashes and reboots meet. Each model is a TLA+ specification, and the TLC model checker runs it in a build gate. Each guard in a model comes with a broken twin that must fail. An October 2026 review found the central properties sound, named each gap and each excess with its smallest fix, and found two real defects in the code, both since fixed.

## The problem

A test runs one ordering of events, and a concurrency bug lives in an ordering no test picked. The Syrvis daemon runs on a Synology NAS under DSM 7 and does many things at once: workflows advance, a queue hands out jobs, timers fire, a person confirms, and on a power cut a battery shutdown starts. A crash or a reboot can cut any of them off between two steps.

Familiar systems fail the same way:

- Two people book the last seat at the same moment. Each check sees one seat free, and both are sold it.
- A bank transfer is cut off halfway, and the money leaves one account without reaching the other.
- An elevator must never move with its doors open, in any order of buttons, sensors and power cuts.

The first is two correct steps interleaving. The second is a crash between two writes. The third is a rule over every state, including the states no test visits.

## TLA+ and TLC

TLA+ describes a system as states and actions. A state gives each variable a value, such as the step a workflow is on. An action is one atomic step to a next state: a worker takes a job, the power fails, a person confirms.

An invariant must hold in every reachable state: no seat is sold twice. A liveness property says something eventually happens: every stop plan ends within its budget. Liveness rests on fairness, the assumption that an action that stays enabled eventually runs.

TLC takes every enabled action from every state it reaches, crashes and reboots included, until no new state appears. A broken property comes back as a trace of the steps that break it.

Bounds keep the search finite: two crashes, two attempts, a few steps. A passing run means no behavior inside the bounds breaks a property. It says nothing past the bounds, and nothing about the Go code unless a test ties the code to the model. A property that no reachable state could break passes by vacuity and proves nothing.

## How Syrvis uses it

The daemon, the engine, the deployment service and the commons run TLC over every model in `make check`. A missing JVM or checker fails the gate, since unchecked is never a pass. The largest runs, such as the engine's sweep of every valid program up to three steps, take about an hour and run before a version is tagged.

A guard's dual is the model with that guard turned off. The dual must fail, which shows the property the guard protects cannot pass by vacuity. In the engine and the deployment service, the gate accepts a dual only when TLC reports the exact property its configuration names, and a proof there that reaches fewer than two states fails the gate. In the daemon, each dual must reach its violation on every fair behavior.

Trace tests tie the engine's queue and evaluator models to the Go code. TLC writes 2,000 random behaviors of the model. A Go test replays each against the real code and compares the state after every step, and one divergence fails the gate. A byte-equality test holds the lifecycle's 208-cell rules table to its Go copy.

## What the October 2026 review found

Six reports covered every model and asked of each property whether it proves the right thing, proves enough, and proves no more than it should. They list 71 findings. Two are real defects in the code, and a Go test reproduced each.

In the engine's queue, a held emergency workflow, one paused until a person lifts it, blocked every ordinary job on the server, under the wrong cause. The queue model has no held workflows, so no model could see it; a reviewer found it by reading the code. It is fixed, and the fix ships in the engine's patch version `v0.2.1`, now tagged.

In the deployment service, a service that a deploy was starting when the whole server drained could come up after the stop had counted it, and run while the server reported it stopped. The power-off checks the services again first, so the power never went off under a running service; the harm was a broken promise and a wrong report. The model allows that order, and no property checked for it. The daemon's code had the same window. Both are now fixed: the stop waits a bounded time for the jobs the drain cut off, then checks once more and stops anything that came up.

Two properties check less than their names say, and past bugs lived in those gaps before the code fixed them. The engine's `ConfirmByHuman` checks the confirmed arguments; it does not check that a person confirmed. No property of the daemon's credential model checks that each new call is judged against its key's current permissions.

The other findings are gaps and excess. The gaps are rules the code relies on with no property, properties with no dual or true by construction, and liveness resting on fairness the code does not give. The excess is models of moved or retiring code, such as the daemon's older workflow engine, and duplicate models no test holds equal. Each finding is being filed as a fixup in its component's repository.

## By component

- [Daemon](../design/daemon.md#provability): chores, the power conductor, credentials, framing, the older workflow engine.
- [Engine](../design/engine.md#provability): the evaluator, the queue, their composition, the trace tests.
- [Client](../design/client.md#provability): no TLA+ model, and what proves it instead.
- [Transport](../design/transport.md#provability): no TLA+ model of its own, and what proves it instead.
- [Deployment](../design/deployment.md#provability): stop and restore plans, the revision store, admission under a drain.
- [Commons](../design/commons.md#provability): the lifecycle rules table and the event bus.
- [Scenarios](scenarios.md): each checked scenario in plain words.
