---
title: Home
nav_order: 1
---

# Syrvis

Syrvis looks after the services on your Synology NAS.
It starts them, stops them and brings them back in the right order, through deployments, reboots and power cuts.
You write down what the server should run, and one small program on the server, the daemon, makes it so and tells you where the server differs from what you wrote.
You drive it from your own computer with one command, `syrvis`, and it never opens a shell on the server.
It is built for one server, so it needs no database, no message broker and no cluster.

**Status:** alpha. The current release is `2.0.0-alpha.72`, and it runs one production server.

If you have a Synology NAS, start with [Install: the first handshake](guide/install.md).
If you want to know how it works, start with [Design](design/index.md).

## Who it is for

Syrvis is for two kinds of reader:

- people who run their own Synology NAS and want its containers, power and health managed from their own computer;
- developers who want to read how each part is built, and how each claim about it is proven.

The server must be an x86_64 Synology NAS on DSM 7.0-40656 or newer.
It needs a storage pool, a volume and an administrator account.
ARM models are not supported.
The [User guide](guide/index.md) lists the rest of what you need.

## What it does today

- Installs, upgrades and uninstalls syrvis on your server from one command, `syrvis install`, and picks up where it stopped.
- Reads the server's volumes, hardware, containers and services into one verdict, and names each thing that needs you with its fix.
- Says whether the server is ready to drain, to shut down and to return to service, with reasons.
- Stages, plans, applies and rolls back a deployment of your containers; a plan shows its time budget and its waves.
- Drains services in order, the floor (the monitoring that watches the rest) last, and restores them in the mirror order.
- Reboots and powers off through a workflow that drains first and waits for your confirm.
- Stops the server in order on UPS battery, with no one present.
- Opens a read-only console in your browser.
- Adds a second computer with its own seat, its own entry on the server's list of computers allowed in.
- Serves an AI assistant through the agent bridge, which can deliver a confirm and never make one.

## How it behaves

Five rules hold across the product:

- Unknown is never a pass: a fact the server cannot answer grades unknown, never healthy.
- Health is the match between what the server shows and what you declared, never uptime.
- Every refusal says what it refused and the way on.
- Every command syrvis prints for you runs as printed, and named tests hold that rule.
- A refusal that stops someone new to syrvis before they get anywhere is a defect.

## The three parts of this site

- [User guide](guide/index.md): install the release as it ships today, pair your computer with your server, and run the commands.
- [Design](design/index.md): one page per component, each ending with how that component is proven.
- [Provability](provability/index.md): how the claims are proven, with a short primer on model checking and the [Scenarios](provability/scenarios.md) TLC checks, in plain words.

## Status

Syrvis is alpha software, and it runs one production server.
Where a page says a thing is planned, the product does not do it yet.
The code lives at [github.com/syrvis](https://github.com/syrvis).
Its code repositories and release pages are private for now, so today the program comes from a release page that needs read access to the organisation.
Every repository is MIT-licensed.
Syrvis is an independent project and is not affiliated with Synology.

The released versions:

| Part | Version | What it is |
|---|---|---|
| the server package | `2.0.0-alpha.72` | the daemon and SyrvisCore, the DSM package it ships in |
| syrvis | `v0.1.12` | the `syrvis` command on your computer |
| the installer | `0.1.2` | the small DSM package that pairs your computer and hands over to the daemon |
