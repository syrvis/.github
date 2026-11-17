---
title: First look
parent: User guide
nav_order: 2
---

# First look

Your server is paired. `syrvis install` ended on `healthy   nothing needs you`, and from now on every call between your computer and the daemon on your server is checked both ways: your computer checks the daemon's key, and the daemon checks your computer's. This page is what you can read and do in your first ten minutes.

Four commands here only read and change nothing: `status`, `status --all`, `ready` and `dash`. The others stop services in order, and this page says so where each appears and shows how the services come back.

`nas` is the name `syrvis install` gave your server; use the name yours printed. The names and numbers in this page's screens are example values, so your server's will differ.

## Read the server

```
syrvis --context nas status
```

On a server with nothing to do:

```screen
syrvis status · nas · syrvisd 2.0.0-alpha.42 (client 0.0.0-dev)

● healthy   nothing needs you
```

When something needs you, the same command puts it first, then shows each service against what you declared for it:

```screen
syrvis status · lab-ops

● unhealthy   a service diverges from its intent

  ! power off  not safe yet: 1 check holds it; one volume is not writable,
               so a stop could lose the queue's last writes

conformance DIVERGING
  (1 conforming · 1 transitioning · 1 diverging)
! search-indexer-of-the-archive  running  declared          exited    behind  DIVERGING      -
→ queue                          running  floor (deferred)  starting  -       TRANSITIONING  start 40s/120s
  1 more conforming

  more: --all for every check, --json for the evidence
```

Each row of the conformance table is one service, and after its name the columns read:

- **intent**: what the service should be doing, here `running`.
- **source**: where that intent comes from, such as your declaration or the floor (explained under the drain below).
- **observed**: what the server actually sees the service doing.
- **drift**: how far the observed state lags the intent.
- **verdict**: conforming, transitioning or diverging.

Health in syrvis means one thing: whether the server matches what you declared. A fact the server cannot answer reads `unknown`, never ok, so a check that cannot be read never passes quietly.

To list every check, the passing ones too:

```
syrvis --context nas status --all
```

## The console

```
syrvis --context nas dash
```

This opens the console, a read-only status page, in a browser on your computer. It reads through the same connection as your other commands, and nothing new is exposed on the server. `--port N` serves it on 127.0.0.1 at port N. On that address the link syrvis prints carries a handle made for this run, and the page answers only under it. Ctrl-C stops it.

## Is it safe to

Before you stop things, ask the server whether it is ready:

```
syrvis --context nas ready
```

```screen
readiness  phase running · intent in-service

✓ drained     every member stops inside its budget
    ✓ drain.budget
✗ shutdown    one volume is not writable, so a stop could lose the queue's last
              writes
    ! vol.writable         /data/queue answered read-only
    ✓ drain.budget
✓ in-service  the fleet is up
```

There are three questions: can the services be drained, can the server shut down, and is it back in service. Each comes with its reasons.

## Stop things in order, and bring them back

A drain is how syrvis stops services: it works out the order they stop in, then stops them in that order. What depends on a service stops before the service itself. Within each wave at most two stop at once by default, so Container Manager is not overloaded. The floor, the services that watch over the rest such as your monitoring, stops last and starts first, so the stop and the return are both watched. A drain can cover the whole server, one volume or one service, among other scopes.

To take down a service called `web`, together with what depends on it:

```
syrvis --context nas drain service --selector web --reason "image upgrade" --dependants cascade
```

```screen
✓ drain drn-21 declared (service/web)
  members: web, worker
  stop waves: [worker] → [web]
  note: this drain will take ~22m; a syrvisd restart mid-drain abandons the job (the stops complete in dockerd; re-declare to resume)
    this plan's own clock is 1320s; syrvisd's exit budget is 90s, and the two are independent
  stop job: job-drain-stop-21 (running), watch with: syrvis job job-drain-stop-21 --watch
```

The drained services stay down until you release the drain by its id:

```
syrvis --context nas release drn-21
```

The release brings them back in the reverse order: the floor first, then what others depend on, then what depends on it. Each one must pass its readiness check before the next starts. The services within one wave start one at a time.

A drain that would close a loop of needs refuses and stops nothing. So does a narrow drain that would take the floor down.

**A planned reboot.** For a DSM update or any other restart:

```
syrvis --context nas reboot
```

syrvis drains the whole server, waits until it is ready to shut down, and asks you to confirm. You then press restart in DSM yourself. After the boot, syrvis releases the drain and waits until the server is back in service. The procedure keeps a record as it goes, so it picks up after the reboot it caused.

**A planned power-off.** To turn the server off with its services stopped in order:

```
syrvis --context nas power-off
```

```screen
→ wf-power-off-3-1
  ✓   created
  · 1 drain
  ✓ 1 drain
  · 2 ready-for-shutdown
  ✓ 2 ready-for-shutdown
  ✓ 3 confirm-poweroff
  ✓ 4 poweroff
  ✓ 5 restore
  ✓ 6 in-service

✓ the power-off is done; the fleet is back in service
```

The reboot and the power-off use the same drain and the same restore as the commands above, so a fix to the stop order reaches all of them.

**On UPS battery.** When the power goes out, syrvis declares the same drain you would. It works out how long that drain needs from the services you declared, and waits while the battery can afford the wait, counting less runtime than your UPS reports so there is a margin. Then it drains the server and powers it off, with no confirm. If the power comes back and holds, it releases the drain. When you add a service, the shutdown time grows with it, and nobody edits a shutdown script. If your declared groups of services do not fit together, the battery stop still runs, in the order of each service's own dependencies, and says so.

The ordered start covers a start syrvis runs itself: after a drain, a reboot, a power-off or a battery stop. After a crash, Docker restarts containers by its own policy first.

## A second computer

`seat enroll` admits another computer's key as a seat, which is one key the server lets in, at a grade that defaults to read-only. To see every seat, its grade, where it may connect from and until when:

```
syrvis --context nas seat list
```

A one-time code that pairs a second computer in one step is designed and not built yet, so for now [Commands](commands.md) carries the full form of `seat enroll`.

## Run a service

A service reaches your server as a deployment. You stage a bundle that describes it, read the plan, and apply it. `revisions` lists what you have applied, and `rollback` returns a deployment to an earlier revision. A deployment is checked against your declared groups when you stage it, and one that does not fit is refused before anything on the server changes. Container Manager must be installed from Package Center first.

## Where next

- [Upgrade and uninstall](upgrade-and-uninstall.md)
- [Commands](commands.md)
- [Troubleshooting](troubleshooting.md)
