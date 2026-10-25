---
title: First steps
parent: User guide
nav_order: 2
---

# First steps

A healthy new box answers three reads: `next` says `set-up`, `status` names the instance and the agent's version, and `verify` grades every invariant the agent watches. On a new box `verify` shows `home.symlink` broken. That row is the product's debt, not your box's fault.

## Check the install

```
syrvis --context nas next
syrvis --context nas status
syrvis --context nas verify
```

What a new box shows in `verify`:

- `home.symlink` reads broken. Nothing in this release installs that link yet, and the row's own sentence says so. Do not fix it by hand.
- `boot.hook` and `rescue.binary` read ok once the root step has installed the rescue copy and its boot script. If the root step printed `not installed` for the rescue copy, these two rows say so, and running the root step again retries it.
- `mem.ecc` can read `unknown` on a box without ECC memory. Unknown is never a pass, so the host headline may read DEGRADED. That is the rule at work, not a fault.

If `next` says `not-bootstrapped`, the home was not named. Name it with the root step, then restart the agent, which reads its home only at start:

```
sudo /var/packages/syrviscore/target/bin/syrvis-enable --home /volumeN/<share>
sudo /usr/syno/bin/synosystemctl restart pkg-syrviscore.service
```

If `next` adds a note about the container engine, that is the container plane below, not a failed install.

## Read the box

These reads change nothing. Each takes `--json`, and the exit code is the same either way.

| command | what it answers |
|---|---|
| `syrvis --context nas status` | health, readiness and a services overview, in one glance |
| `syrvis --context nas health` | the health verdict and its reasons |
| `syrvis --context nas verify` | one row per host invariant: volumes, home, seam, boot |
| `syrvis --context nas census` | roots, volumes, collisions and findings |
| `syrvis --context nas hardware` | kernel, memory, load, CPU, arrays and rebuild progress |
| `syrvis --context nas events` | the event stream, polled once |
| `syrvis --context nas watch` | the live event stream, until Ctrl-C |
| `syrvis --context nas dash` | a read-only status board in your browser, served on 127.0.0.1 |

To leave out `--context nas`, set the default once in your shell:

```
export SYRVIS_CONTEXT=nas
```

## Turn on the container plane

Syrvis runs services through Container Manager. Install Container Manager from Package Center; on DSM 7.0 and 7.1 it is called Docker. Then run two commands at the box:

```
sudo /var/packages/syrviscore/target/bin/syrvis-enable --docker-socket /var/run/docker.sock
sudo /usr/syno/bin/synosystemctl restart pkg-syrviscore.service
```

On a box already serving, the first command declares the engine and restarts nothing. It ends on `NOT DONE: what this run wrote ... is NOT in service`, names the restart, and exits non-zero. That is the product saying the restart is owed, and when to interrupt the box is yours to choose. Without the restart the engine stays declared and unused. If you passed `--docker-socket` in the root step, skip this section.

## Turn on self-repair

The agent re-reads the box's invariants every thirty minutes. By default it reports drift and repairs nothing. You can arm repair for a named list. This release accepts two names, `home.symlink` and `socket.perms`, and refuses any other before writing a byte:

```
sudo /var/packages/syrviscore/target/bin/syrvis-enable --arm-compensation home.symlink,socket.perms
sudo /usr/syno/bin/synosystemctl restart pkg-syrviscore.service
```

The first command ends on `NOT DONE` as the container plane's does. Not yet observed: whether `home.symlink` clears after this. Treat the section as optional, and expect `verify` to look the same afterwards.

## Add a second computer

Each computer holds its own key under its own name, and needs an address that does not change.

1. Install the client on the new computer, as the install's [step 1](install.md#step-1-get-the-client) does.
2. On the new computer, mint its key under a new name:
   ```
   syrvis api enroll-request --context nas-2 --grade operator
   ```
3. At the box, enrol the paste-line it printed:
   ```
   sudo /usr/local/bin/syrvis seat enroll --client "<paste-line>"
   ```
4. At the box, print the pin line:
   ```
   sudo /usr/local/libexec/syrvisd/current/syrvisd api fingerprint --pin-line
   ```
5. On the new computer, run that line with `nas-2` in place of `<name>`:
   ```
   syrvis context pin nas-2 <nas-ip>:7447 <64 hex>
   ```

`syrvis --context nas seat list` shows every key the box admits: at what grade, from where, and until when.

## A planned reboot

`syrvis reboot` runs the whole planned reboot as one procedure the box owns. It declares the drain and waits for the shutdown gate, asks you to confirm the halt, then waits for the reboot you perform. After the boot it releases the drain and waits for the return-to-service gates.

```
syrvis --context nas reboot
```

Ctrl-C leaves the procedure standing, and the same command attaches to it again. A failure prints its recovery. Not yet measured: the planned reboot end to end on a box at this release.

## Run a service

The box runs services as containers, converged toward a deploy document you declare with OpenTofu and the syrvis provider. A service needs the container plane, OpenTofu 1.12.6 and the provider on your computer, a placement registry on the box, and an account of its own. This guide does not yet carry the provider's install or the deploy walk.

The account is made at the box, and the step prints the uid to declare as the service's `tuning.user`:

```
sudo /var/packages/syrviscore/target/bin/syrvis-enable --service-user example-svc
```

With an operator key, the same act runs from your computer:

```
syrvis --context nas account ensure example-svc
```

Either refuses an account that can log in, is in administrators, is uid 0, has a uid under 1026, or is the package's own user. The refusal names another name to use.
