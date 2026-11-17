# Syrvis

Syrvis brings the working practices of site reliability and systems engineering to the services on your Synology NAS.
It runs on top of DSM, Synology's own system, so that those services are easier to manage and to make your own.
You write down what the server should run.
One small program on the server, the daemon, makes it so, keeps it in order through deployments, reboots and power cuts, and tells you where the server differs from what you wrote.
You manage it from your own computer, with no password and no shell on the server.

**Status:** alpha. The released pair is the server's `2.0.0-alpha.72` and `syrvis` `v0.1.12`, and it runs one production server.

Start at the [Syrvis site](https://syrvis.github.io/.github/).
If you have a Synology NAS, the [User guide](https://syrvis.github.io/.github/guide/) takes you through the install; the [Design](https://syrvis.github.io/.github/design/) shows how each part is built.

## Syrvis and DSM

DSM already runs services: Container Manager runs your containers, Task Scheduler runs scripts, and DSM's UPS setting shuts the server down when the power fails.
Syrvis keeps all three and works beside them; it needs Container Manager to run your containers.
What it adds is one written record of what the server should run, and the order, checks and history that follow from it.
The left column is our reading of DSM's own tools, not a measured comparison.

| | With DSM alone | With syrvis |
|---|---|---|
| What runs | Each container or project is set up in Container Manager's screens, with its own restart setting | One document declares every service on the server, and syrvis plans, orders and watches each one |
| Making a change | A change takes effect where you make it | You stage a change, read its plan with a time budget, then apply it; each apply is a revision, and a rollback runs at the server itself |
| Order | At a shutdown, as syrvis's design reads it, Container Manager stops containers all at once | Each group of services says what it provides and requires, and one order follows for draining, rebooting, the stop on battery and the start after boot |
| On UPS battery | DSM shuts down after a delay or at low battery | Syrvis stops your services in that order first, then hands the last step to DSM; DSM's own low-battery shutdown stays as the last resort |
| Scheduled jobs | Task Scheduler runs a script on a schedule or at boot | A chore, a task declared with its service, runs inside that service's container, is watched to its end, and is held and reported if it fails |
| Knowing it is right | DSM's screens show what is running | The server is checked against what you declared, and each thing that needs you is named with its fix |
| Where you manage from | DSM's pages, signed in as an administrator | Your computer, the console, an AI agent or OpenTofu, all through one API |

**Your own services, today.** You declare a container of your own in one document, then stage, plan and apply it from your computer.
A service that keeps data also needs a placement file, written by hand and put in place by a root line, one command you run at the server.
Three things that would make this shorter are decided and not built at this release: a catalog of ready-made service descriptions, a first service with no OpenTofu in the way, and the install writing the placement file for you.

## Ways to manage

You reach the server four ways, and all four use the same API.

- **The `syrvis` command** on your computer does every act: install, status, deployments, drains, reboot, power-off, workflows, seats and logs.
- **The console** opens in your browser from `syrvis dash`. It is read-only: it shows services, deployments, workflows, chores, checks and events, changes nothing, and opens nothing new on the server.
- **An AI agent** reaches the server through the agent bridge, `syrvis mcp`, which speaks the Model Context Protocol (MCP) to the program that hosts the agent. The agent holds the seat it runs under and no more. It can read, plan and apply a deployment someone else staged; it cannot stage one, and it can deliver a confirm a person made but never make one. No agent host has been tested with the bridge yet, so there is no setup line to copy.
- **The OpenTofu provider** declares the server's whole deployment in an OpenTofu file: `tofu plan` stages and plans it, `tofu apply` applies the plan you reviewed, and `tofu destroy` only detaches, leaving your services running. It is tested against a real daemon over a stand-in container engine and is not yet tested on a real server. It is not released: you build it and place it by hand. Nothing in syrvis requires it.

Beneath all four sits one API on the server: a fixed list of 47 named calls, with no shell behind them.
Every connection uses mutual TLS, where each side proves itself by its key and your computer pins the daemon's key, so it knows the daemon by that key alone.
Each computer or agent has a seat, its own entry on the server's list of who may connect, with a grade: read-only, operator, or admin, and admin is granted only at the server itself.
One implementation stands behind every way in, so a grade, a refusal and a confirm behave the same from each.
You extend what the server runs without writing code: your own containers, scheduled chores, expiry dates, virtual machines declared so they stop in order, and a gate that opens your own service's API to named seats.
New calls and new kinds of workflow are compiled into the daemon, so today only a release adds one.

## Workflows and chores

A workflow is a job the daemon runs step by step, writing each step to its journal before the next.
A workflow under way survives a reboot or a daemon restart, and a step cut off by a crash is held until you act, never run again blindly.

| Workflow | What it does | Started by |
|---|---|---|
| Planned reboot | Drains, waits for your confirm, then restores after the restart | `syrvis reboot` |
| Power-off | Waits for your confirm, drains, powers off; restores after boot, or holds until you confirm | `syrvis power-off` |
| UPS stop | On UPS battery, drains in order, then powers off, with no confirm | The daemon |
| UPS restore | Restores once the power is back and holding | The daemon |
| Seat renewal | Renews a seat before it expires | The daemon |
| Declared chore | Runs a service's declared task in its container, for 1 to 29 minutes | Its schedule, at boot, or `syrvis task` |
| Upgrade | Receives the new version, keeps your answers, hands over to the root step | `syrvis install` with a newer version |

A drain stops services in a planned order, and the restore brings them back.
For the planned reboot, in this release you press restart in DSM, and the reboot end to end is not yet measured at this release.

The daemon also does this upkeep on its own:

- **Seat renewal.** Each seat is renewed 21 days before it expires, by 180 days, with no confirm, and never to more than 365 days ahead. A seat's life ends 730 days after it was made: then it is read-only for 30 days, then closed, and you make a new key on your computer and replace the seat once.
- **Chores you declare.** Watched to their end, held and reported on failure or overrun; a service that declares a database gets a nightly dump.
- **Bringing services back.** Every 60 seconds by default, a declared service found stopped is started again, with backoff.
- **Tidying.** It keeps the newest ten revisions, plus the current one and the rollback target, and deletes a finished workflow 30 days after it ends.

Not automatic today: rotating a secret (you raise its revision number), updating images (they are pulled when you apply), and renewing DSM's own certificate.

## Why it is built this way

### Zero dependencies

Nothing extra lands on your server: no database, no message broker, no language runtime, no cloud account.
Every part of syrvis is written in Go against Go's standard library and syrvis's own modules.
On your server that means two DSM packages, the installer and SyrvisCore; on your computer, one program.
The one exception is the optional OpenTofu provider, which keeps a third-party framework and runs on your computer, never on the server.

### One server, on purpose

Software that runs across many machines spends much of its effort keeping those machines in agreement.
Syrvis runs on one server, where one program holds the truth, so it drops that work and keeps the patterns worth having.

| What a cluster has to solve | What one server lets syrvis drop | The pattern it keeps |
|---|---|---|
| A database to run, back up and upgrade | The database: state is plain files, a snapshot and a checksummed journal | A change lands whole, by one atomic rename, or not at all |
| A message broker between the parts | The broker: each step runs inside the daemon | A durable work queue kept in the journal, so work survives a restart |
| Agreement between copies (consensus, leader election) | The copies: one process holds the truth | A single writer, held by one lock on its state folder |
| Health checks by heartbeat | The heartbeats: there is nothing to gossip with | Health means the server matches what you declared, checked fact by fact |
| A remote shell for administration | The shell: one API with a fixed list of named calls | Named calls with typed parameters; the destructive ones answer only at the server itself |

The install is the one part that spans two machines, and there syrvis uses the full pattern: each side journals its own steps, so closing your laptop mid-install loses nothing.
The [Engine](https://syrvis.github.io/.github/design/engine.html) page shows how the journal works.

### One declaration, used everywhere

Each group of services says what it `provides` and what it `requires`.
A requirement names a need, such as `metrics`, never a program, so you can swap the program behind `metrics` without editing what uses it.
Syrvis binds each need to exactly one group that provides it, or refuses and names the candidates.

<img src="https://syrvis.github.io/.github/images/provides-requires.svg" alt="Two groups of services: media requires metrics and is bound to observer, which provides it. Below, the order services stop in and the mirror order they start in." width="820">

Syrvis reads that one graph when it checks a staged deployment, and when it drains, stops on battery, reboots and starts after boot.
The floor, the monitoring that watches the rest, stops last and starts first.
Ordering by group inside an apply, and a group waiting at boot on what another group provides, are not built yet.
The [Deployment](https://syrvis.github.io/.github/design/deployment.html) page has the order in full.

## Pairing, with no password

`syrvis install` makes a key on your computer, and only its public half travels: you paste it into DSM, where you are already signed in as an administrator, and the installer admits that one key.
A root step you start in DSM's Task Scheduler installs SyrvisCore and adds your key; then your computer pins the daemon's key.
Your computer's first connection to the installer is taken on trust on your local network, and the screen says so; a one-time code that proves the server at that first meeting is decided and not built.

<img src="https://syrvis.github.io/.github/images/pairing.svg" alt="Your computer and your server in four steps: you paste your computer's key in DSM, your answers and the checked package go to the installer, the root step starts the daemon, and your computer pins the daemon's key." width="820">

The picture shows the four moves between the two machines; the guide walks you through your five steps in [Install: the first handshake](https://syrvis.github.io/.github/guide/install.html).

## What it looks like

You press Run on the root step in DSM, and `syrvis install` finishes on your computer.
The names and numbers in this screen are example values.

```
✓ root step   ran on the box                                     1m4s  5/5
✓ paired      nas at 127.0.0.1:50002, its key is the one the installer sent

Installed SyrvisCore 2.0.0 on nas in 14m56s. All 5 of your steps done.
syrvis status · nas · syrvisd 2.0.0-alpha.42 (client 0.0.0-dev)

● healthy   nothing needs you
```

## How it is proven

The libraries that hold state come with TLA+ models, written descriptions of their behaviour that the model checker TLC explores state by state.
The checks cover claims such as the floor stopping last, the start mirroring the stop, and a loop of needs being refused, and each runs in its repository's gate.
The [Provability](https://syrvis.github.io/.github/provability/) pages say what each model proves and what it misses.

## The repos

| Repo | Its job | Design |
|---|---|---|
| [syrvis](https://github.com/syrvis/syrvis) | the daemon, `syrvisd`, its DSM packages (SyrvisCore and the installer), the server's API and the OpenTofu provider | [Daemon](https://syrvis.github.io/.github/design/daemon.html) |
| [syrvis-cli](https://github.com/syrvis/syrvis-cli) | the `syrvis` command you run on your computer, with the console and the agent bridge | [Client](https://syrvis.github.io/.github/design/client.html) |
| [syrvis-client](https://github.com/syrvis/syrvis-client) | the library `syrvis` and the console share to reach the server | [Client](https://syrvis.github.io/.github/design/client.html) |
| [syrvis-console](https://github.com/syrvis/syrvis-console) | the read-only console in your browser | none yet |
| [syrvis-workflow](https://github.com/syrvis/syrvis-workflow) | the workflow engine: every step journaled, so a workflow resumes after a crash or a reboot | [Engine](https://syrvis.github.io/.github/design/engine.html) |
| [syrvis-mtls](https://github.com/syrvis/syrvis-mtls) | the mutual TLS connection both ends share, where each side checks the other's key | [Transport](https://syrvis.github.io/.github/design/transport.html) |
| [syrvis-deploy](https://github.com/syrvis/syrvis-deploy) | deployments, revisions, the drains and the stop and start order | [Deployment](https://syrvis.github.io/.github/design/deployment.html) |
| [syrvis-common](https://github.com/syrvis/syrvis-common) | the libraries beneath the services, as seven Go modules | [Commons](https://syrvis.github.io/.github/design/commons.html) |

## Status

Syrvis is alpha software, and it runs one production server.
Its code repositories and release pages are private for now, so today the program comes from a release page that needs read access to the organisation.
This page and the [User guide](https://syrvis.github.io/.github/guide/) are public.
Every repository is MIT-licensed.
Syrvis is an independent project and is not affiliated with Synology.
