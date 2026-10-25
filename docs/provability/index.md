---
title: Provability
nav_order: 4
has_children: true
---

# Provability

Syrvis model-checks the parts of its design where concurrency, crashes and reboots meet. Each model is a TLA+ specification that the TLC model checker runs in a build gate. A guard in a model comes with a broken twin that must fail. An October 2026 review found the central properties sound, named each gap and excess with its smallest fix, and found two real defects in the code: one fixed, one being fixed.

## The problem

The Syrvis daemon lives on a Synology NAS running DSM 7 and does many things at once. Workflows advance, a queue hands out jobs, timers fire, a person confirms, and on a power cut a battery shutdown starts. A crash or a reboot can cut any of them off between two steps. A test runs one ordering of those events; a concurrency bug lives in an ordering no test picked.

Familiar systems fail the same way:

- Two people book the last seat at the same moment. Each check sees one seat free, and both are sold it.
- A bank transfer is cut off halfway, and the money leaves one account without reaching the other.
- An elevator must never move with its doors open, in any order of buttons, sensors and power cuts.

The first is two correct steps interleaving. The second is a crash between two writes. The third is a rule over every state, not only the states a test visits.

## TLA+ and TLC

TLA+ describes a system as states and actions. A state gives each variable a value, such as the step a workflow is on. An action is one atomic step to a next state: a worker takes a job, the power fails, a person confirms.

An invariant must hold in every reachable state: no seat is sold twice. A liveness property says something eventually happens: every stop plan ends within its budget. Liveness rests on fairness, the assumption that an action that stays enabled eventually runs.

TLC takes every enabled action from every state it reaches, crashes and reboots included, until no new state appears. A broken property comes back as a trace of the steps that break it.

Bounds keep the search finite: two crashes, two attempts, a few steps. A green run means no behavior inside the bounds breaks a property. It says nothing past the bounds, and nothing about the Go unless a test ties the code to the model. A property that no reachable state could break passes by vacuity, and proves nothing.

## How Syrvis uses it

The daemon, the engine and the deployment service run TLC over every model in `make check`. A missing JVM or checker fails the gate, since unchecked is never a pass. The largest runs, such as the engine's sweep of every valid program up to three steps, take about an hour and run before a version is tagged.

A guard's dual is the model with that guard turned off, and it must fail, so the property it protects cannot pass by vacuity. In the engine and the deployment service, a dual is green only when TLC reports the exact property its configuration names. A proof there that reaches fewer than two states is red. In the daemon, each dual must reach its violation on every fair behavior.

Trace tests tie the engine's queue and evaluator models to the Go. TLC writes 2,000 random behaviors of the model. A Go test replays each against the real code and compares the state after every step, and one divergence fails the gate. A byte-equality test holds the lifecycle's 208-cell rules table to its Go copy.

## What the October 2026 review found

Six reports covered every model, asking of each property whether it proves the right thing, enough, and not too much. They list 71 findings. Two are real defects in the code, and a Go test reproduced each.

In the engine's queue, a held emergency workflow, one paused until a person lifts it, blocked every ordinary job on the box, under the wrong cause. The queue model has no held workflows, so no model could see it; a reviewer found it by reading the code. It is fixed, and the fix ships in the engine's next patch version.

In the deployment service, a service a deploy is starting when the whole box drains can come up after the stop has counted it, and run into the power-off. The model allows that order, but no property checked for it. The daemon's code has the same window; the daemon is fixing it first, and the deployment service follows.

Two properties check less than their names say, where past bugs lived before the code fixed them. The engine's `ConfirmByHuman` checks the confirmed arguments, not that a person confirmed. No property of the daemon's credential model checks that each new call is judged against its key's current permissions.

The rest are gaps and excess. The gaps are rules the code relies on with no property, properties with no dual or true by construction, and liveness resting on fairness the code does not give. The excess is models of moved or retiring code, such as the daemon's older workflow engine, and duplicate models no test holds equal. Each finding is being filed as a fixup in its component's repository.

## By component

- [Daemon](../design/daemon.md#provability): chores, the power conductor, credentials, framing, the older workflow engine.
- [Engine](../design/engine.md#provability): the evaluator, the queue, their composition, the trace tests.
- [Client](../design/client.md#provability): no TLA+ model, and what proves it instead.
- [Transport](../design/transport.md#provability): no TLA+ model of its own, and what proves it instead.
- [Deployment](../design/deployment.md#provability): stop and restore plans, the revision store, admission under a drain.
- [Commons](../design/commons.md#provability): the lifecycle rules table and the event bus.
- [Scenarios](scenarios.md): each checked scenario in plain words.
