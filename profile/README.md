# Syrvis

Syrvis keeps a Synology NAS running DSM 7 in the state you declare.

It is two programs.
`syrvisd` is an agent that runs on the box as a DSM package.
`syrvis` is a command you run on your own computer, and it reaches the agent over mutual TLS.
The client never opens a shell on the box, and nothing there changes until you declare it.
Every refusal names what it refused and how to proceed.

Start with the [user guide](https://syrvis.github.io/.github/guide/) if you have a box, or with the [design](https://syrvis.github.io/.github/design/) to see how it works.

## A short tour

You create a shared folder in DSM and install the package.
Then you run one root step on the box, the only privileged part of the install.

Three commands on your computer complete the setup.
`syrvis api enroll-request` mints a key on your machine.
`syrvis context pin` records where the box is.
`syrvis next` asks the box what it still needs.

The agent reads the box: its volumes, hardware, containers and services.
It grades health as the match between what it observes and what you declared, never as uptime.
A fact the box cannot answer grades unknown, and unknown is never a pass.

You declare your containers as a revision, and the agent converges the box to it.
A drain stops services, dependants first.
A restore brings them back, dependencies first.

Reboot, power-off and the UPS stop run as workflows on a durable engine.
A reboot waits for your typed confirm.
On UPS battery, the agent stops the box with no one present.

Each library the agent composes stands alone, with its own tests.
The libraries that hold state also have TLA+ models, and TLC checks them in a repository's gate; the commons' lifecycle model is checked in the agent's.
The [provability pages](https://syrvis.github.io/.github/provability/) say what each model proves and what it misses.

## The repos

### [syrvis](https://github.com/syrvis/syrvis)

The agent, `syrvisd`, and the DSM package it ships in.
It assembles the libraries below into one process per box and serves the box's one API.
The repository also holds that API's contract module, an OpenTofu provider for declared state, and the install guide.
It is at `2.0.0-alpha.67`.
Design: [the daemon](https://syrvis.github.io/.github/design/daemon.html).

### [syrvis-workflow](https://github.com/syrvis/syrvis-workflow)

The workflow engine, a Go library the agent and the client embed.
Definitions are compiled into the program that runs them, and nothing is published at run time.
Every step is journaled, so after a crash or a reboot the engine knows where each workflow stood.
A step that may have run holds with a named cause rather than run twice.
A step that waits on a person, such as a confirm, is one more kind of wait.
The agent's main branch requires it at `v0.2.1`, which carries a fix the provability review found; the agent's release `2.0.0-alpha.67` and the client on main require `v0.2.0`.
Design: [the engine](https://syrvis.github.io/.github/design/engine.html).

### [syrvis-client](https://github.com/syrvis/syrvis-client)

The `syrvis` command, built for macOS on Apple silicon and Intel, and for Linux on x86_64.
It reaches the box over mutual TLS, and every command it prints for you runs as printed.
Its main branch, not yet released, runs its own copy of the engine for reboot, power-off and the connection test.
`syrvis mcp` serves an AI agent over MCP; an agent may deliver a confirm, and only a person mints one.
Its release is `v0.1.1`.
Design: [the client](https://syrvis.github.io/.github/design/client.html).

### [syrvis-mtls](https://github.com/syrvis/syrvis-mtls)

The mutual TLS transport both ends share. Three packages do its work.
`pin` makes the trust decision on a certificate's key.
`seat` holds a client's row on the box's roster and its grammar.
`dial` is the one pinned dial.
It uses the standard library only and holds no state; the agent keeps the listener and the roster's store.
It is at `v0.1.0`.
Design: [the transport](https://syrvis.github.io/.github/design/transport.html).

### [syrvis-deploy](https://github.com/syrvis/syrvis-deploy)

The deployment service, a Go library.
It stages, plans, applies, rolls back and prunes a box's revisions, and converges containers to them.
It holds the drain set, the one way to suppress a service, and the plans that stop and restore.
Its model, `Deploy.tla`, was checked before the code moved in.
It is at `v0.1.0`; the agent still builds its own copy, and switching to this tag is planned.
Design: [deployment](https://syrvis.github.io/.github/design/deployment.html).

### [syrvis-common](https://github.com/syrvis/syrvis-common)

The libraries below the services, as seven Go modules: `primitives`, `declarations`, `adapters`, `probes`, `grading`, `frame` and `secretstore`.
A test holds their order, so a module imports only the modules below it.
All seven are tagged together at one version.
The agent requires each at `v0.1.1`, and the deployment service requires five of them.
Design: [the commons](https://syrvis.github.io/.github/design/commons.html).

## How they fit

Each library is a Go module at a semantic-version tag, and the agent vendors the tags it builds with.

| Repo | Its job | Required by | Version |
|---|---|---|---|
| syrvis | the agent, its DSM package and the box's API | nothing: it is the program on the box | `2.0.0-alpha.67` |
| syrvis-workflow | the workflow engine | syrvis; syrvis-client on main, unreleased | `v0.2.0` |
| syrvis-mtls | the shared transport | syrvis, syrvis-client | `v0.1.0` |
| syrvis-common | the libraries below the services | syrvis, syrvis-deploy | `v0.1.1` |
| syrvis-deploy | revisions, convergence and drains | syrvis, once the switch lands | `v0.1.0` |
| syrvis-client | the `syrvis` command | nothing: it is the program on your computer | `v0.1.1` |

The client and the deployment service also require the box's contract module, `github.com/syrvis/syrvis/api`, at a tag.

## Status

Syrvis is alpha software, and it runs one production box.
A first install on a second box is being rehearsed.
The code repositories are private for now, and each opens on its own once it is ready.
This site is public and describes each repository at the version above.
Every repository is MIT-licensed. Five carry the `LICENSE` file today, and `syrvis` adds its own before it goes public.
Syrvis is an independent project and is not affiliated with Synology.
