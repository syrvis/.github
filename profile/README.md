# Syrvis

Syrvis looks after the services on your Synology NAS.
It starts them, stops them and brings them back in the right order, through deployments, reboots and power cuts.
You write down what the server should run, and one small program on the server, the daemon, makes it so and tells you where the server differs from what you wrote.
You drive it from your own computer with one command, `syrvis`, and it never opens a shell on the server.
It is built for one server, so it needs no database, no message broker and no cluster.

**Status:** alpha. The current release is `2.0.0-alpha.72`, and it runs one production server.

If you have a Synology NAS, start with the [User guide](https://syrvis.github.io/.github/guide/).
To see how each part is built, read the [Design](https://syrvis.github.io/.github/design/).

## Why it is built this way

### Zero dependencies

Nothing extra lands on your server: no database, no message broker, no language runtime, no cloud account.
Every part of syrvis is written in Go against Go's standard library and syrvis's own modules, and nothing else.
On your server that means two DSM packages, the installer and SyrvisCore; on your computer, one program.
Container Manager is needed only to run your services.
The one exception is the optional OpenTofu provider, which keeps a third-party framework and runs on your computer, never on the server.
Fewer parts leave less to audit and less to break.

### One server, on purpose

Software that runs across many machines spends much of its effort keeping those machines in agreement.
Syrvis runs on one server, where one program holds the truth, so it drops that work and keeps the patterns worth having.

| What a cluster has to solve | What one server lets syrvis drop | The pattern it keeps |
|---|---|---|
| A database to run, back up and upgrade | The database: state is plain files, a snapshot and a checksummed journal | A change lands whole, by one atomic rename, or not at all |
| A message broker between the parts | The broker: each step runs inside the daemon | A durable work queue kept in the journal, so work survives a restart |
| Agreement between copies (consensus, leader election) | The copies: one process holds the truth | A single writer, held by one lock on its state folder |
| Health checks by heartbeat | The heartbeats: there is nothing to gossip with | Health as conformance: what the server shows is checked against what you declared, and a fact it cannot answer reads unknown, never healthy |
| A remote shell for administration | The shell: one API with a fixed list of named commands | Named commands with typed parameters; the destructive ones answer only on the server itself |

One part does span two machines: the install, which runs between your computer and the server.
There syrvis uses the full pattern.
Each side keeps a journal of its own steps, a call between them is retried under one key the other side recognises, and the receiver writes down what it got before it answers.
That is why closing your laptop mid-install loses nothing.
The [Engine](https://syrvis.github.io/.github/design/engine.html) page shows how the journal works.

### One declaration, used everywhere

You put your services in groups, and each group says what it `provides` and what it `requires`.
A requirement names a need, such as `metrics`, never a program's name, so you can swap the program behind `metrics` without editing everything that uses it.
Syrvis binds each need to exactly one group that provides it, or refuses and names the candidates.

<img src="https://syrvis.github.io/.github/images/provides-requires.svg" alt="Two groups of services: media requires metrics and is bound to observer, which provides it. Below, the order services stop in and the mirror order they start in." width="820">

Syrvis reads that one graph in five places:

- **Deploying.** You stage a deployment, which hands it to the server to check before anything runs. If it names a need that no group meets, or that two groups meet, the server refuses it and names the fix, and nothing on the server changes. Ordering by group inside the apply that follows is not built yet.
- **Draining.** A drain stops services in a planned order: the services that need others go first, and the floor, the monitoring that watches the rest, goes last.
- **The power-off on UPS battery.** The same drain, timed from what each service declares, then a power-off, with no one present.
- **The planned reboot and power-off.** The same drain, then the restart; in this release you press restart in DSM, and the reboot end to end is not yet measured at this release.
- **The start after boot.** The mirror of the stop, for a start syrvis orders: the floor first, then each need before what needs it, each service held until it is ready. A group waiting on what another group provides is not built yet.

The [Deployment](https://syrvis.github.io/.github/design/deployment.html) page has the stop and start order in full.

## Pairing, with no password

Pairing your computer with your server takes no password and no shell.
`syrvis install` makes a key on your computer, and only its public half travels: you paste it into DSM, where you are already signed in as an administrator, and the installer admits that one key.
A root step you start in DSM's Task Scheduler installs SyrvisCore and enrols your key; then your computer pins the daemon's key, which means it knows the daemon by that key alone from then on.
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

## What it does today

- Installs, upgrades and uninstalls syrvis on your server from one command, `syrvis install`, and picks up where it stopped.
- Reads the server's volumes, hardware, containers and services into one verdict, and names each thing that needs you with its fix.
- Says whether the server is ready to drain, to shut down and to return to service, with reasons.
- Stages, plans, applies and rolls back a deployment of your containers; a plan shows its time budget and its waves.
- Drains services in order and restores them.
- Reboots and powers off through a workflow that drains first and waits for your confirm.
- Stops the server in order on UPS battery, with no one present.
- Opens a read-only console in your browser.
- Adds a second computer with its own seat, its own entry on the server's list of computers allowed in.
- Serves an AI assistant through the agent bridge, which can deliver a confirm and never make one.

## How it is proven

The libraries that hold state come with TLA+ models, written descriptions of their behaviour that the model checker TLC explores state by state.
The checks cover claims such as the floor stopping last, the start mirroring the stop, and a loop of needs being refused, and each runs in its repository's gate.
The [Provability](https://syrvis.github.io/.github/provability/) pages say what each model proves and what it misses.

## The repos

| Repo | Its job | Design |
|---|---|---|
| [syrvis](https://github.com/syrvis/syrvis) | the daemon, `syrvisd`, its DSM packages (SyrvisCore and the installer), the server's API and the optional OpenTofu provider | [Daemon](https://syrvis.github.io/.github/design/daemon.html) |
| [syrvis-cli](https://github.com/syrvis/syrvis-cli) | the `syrvis` command you run on your computer | [Client](https://syrvis.github.io/.github/design/client.html) |
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
