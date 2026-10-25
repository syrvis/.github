---
title: Home
nav_order: 1
---

# Syrvis

Syrvis keeps a Synology NAS running DSM 7 in the state you declare.

It is two programs.
`syrvisd` is an agent on the box, installed as a DSM package.
`syrvis` is a command on your own computer, and it reaches the agent over mutual TLS.
Nothing on the box changes until you declare it, and the client never opens a shell there.

If you have a box, start with the [User guide](guide/index.md).
If you want to know how it works, start with [Design](design/index.md).

## Who it is for

Syrvis is for two kinds of reader:

- people who run their own Synology NAS and want its containers, power and health managed from their own computer;
- developers who want to read how each part is built, and how each claim about it is proven.

The box must be an x86_64 Synology NAS on DSM 7.0-40656 or newer.
It needs a storage pool, a volume and an administrator account.
ARM models are not supported.
The [User guide](guide/index.md) lists the rest of what you need.

## What it does today

At `2.0.0-alpha.67` the agent does these things:

- reads the box's volumes, hardware, containers and services into one health verdict;
- reports whether the box is ready to drain, to shut down and to return to service, with reasons;
- converges your containers to a revision you declare, and rolls back or prunes on your word;
- drains services, dependants first, and restores them, dependencies first;
- reboots and powers off through a workflow that waits for your typed confirm;
- stops the box on UPS battery, with no one present;
- renews each client's credential as its renewal window opens.

## How it behaves

Five rules hold across the product:

- Unknown is never a pass: a fact the box cannot answer grades unknown, never ok.
- Health is the match between what the box shows and what you declared, never uptime.
- Every refusal says what it refused, why, and what it did not change.
- Every command the client prints for you runs as printed, and named tests hold that rule.
- A refusal that stops someone new to Syrvis before they get anywhere is a defect.

## The three parts of this site

The site has three parts, one per kind of question:

- [User guide](guide/index.md): install the release as it ships today, connect your computer, and run the verbs.
- [Design](design/index.md): one page per component, each ending with how that component is proven.
- [Provability](provability/index.md): a short primer on model checking, and the [scenarios](provability/scenarios.md) TLC checks, in plain words.

## Status

Syrvis is alpha software.
It runs one production box, and a first install on a second box is being rehearsed.
Where a page says a thing is planned, the product does not do it yet.

The code lives in six repositories at [github.com/syrvis](https://github.com/syrvis).
They are private for now, and each opens on its own once it is ready.
Each is MIT-licensed.
This site describes them at these versions:

| Repository | Version | What it holds | Design page |
|---|---|---|---|
| `syrvis` | `2.0.0-alpha.67` | the agent, its DSM package and the box's API | [Daemon](design/daemon.md) |
| `syrvis-workflow` | `v0.2.0` | the workflow engine | [Engine](design/engine.md) |
| `syrvis-client` | `v0.1.1` | the `syrvis` command | [Client](design/client.md) |
| `syrvis-mtls` | `v0.1.0` | the mutual TLS transport | [Transport](design/transport.md) |
| `syrvis-deploy` | `v0.1.0` | the deployment service | [Deployment](design/deployment.md) |
| `syrvis-common` | `v0.1.1` | the libraries below the services | [Commons](design/commons.md) |
