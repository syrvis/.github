---
title: Troubleshooting
parent: User guide
nav_order: 4
---

# Troubleshooting

Every refusal Syrvis prints names what it refused, why, and what it did not change, and it ends on the command that finishes the job: run that command. When your computer cannot reach the box at all, start with `syrvis context test nas`. A refusal that names no recovery is a defect; report it.

## The connection

```
syrvis context test nas
```

It walks the connection layer by layer, from what the context holds: the context file, the TCP dial, this computer's key, the TLS handshake against the pinned box key, the key's admission, the instance pin, and the version skew. It stops at the first failure and names its fix. A timeout is most often DSM's firewall: allow 7447/tcp from your computer's address. The exit codes are on the [Commands](commands.md#global-flags-and-exit-codes) page.

## Refusals and their recoveries

One refusal has no recovery at the box. When Package Center refuses the install with only an error number, the package is at fault, nothing of Syrvis ran, and nothing was left behind. Stop, and report the number, with the last lines of `/var/log/synopkg.log` if you have SSH.

| what you see | what it means | what to do |
|---|---|---|
| Package Center: Error 281 | your CPU family is not in the package's list | ask for a build with your model's token added |
| Package Center refuses an untrusted publisher | the package is not signed by Synology | set Package Center > Settings > General > Trust Level to allow any publisher |
| Package Center shows the package stopped, or offers Repair | DSM draws its own wrapper unit, which can read stopped while the agent serves | do not click Repair. Before the root step, run the root step. After it, choose Package Center > SyrvisCore > Run. If `verify`'s `pkg.dsm-status` row stays broken, report the row |
| `--home /volumeN/<share> does not exist` | no shared folder has that exact spelling, and nothing changed | create it in DSM with that spelling, then run the same command again |
| `does not exist, but /volumeN/<another spelling> does` | a folder of that name exists in another case | use the spelling the line names, or rename the folder in DSM. Do not create another, and do not reinstall |
| `--api-client needs --api-listen too` | the paste-line came without the box's address, and nothing changed | run the command again with `--api-listen <nas-ip>:7447` added |
| `NOT DONE: the HOME half refused` | the lines above it say what is wrong with the home | do what they say, then run the command the message prints. Expect the next row after it |
| `NOT DONE: the client was NOT enrolled` | the agent already ran as root, so the root step could not seed your key | [the client was not enrolled](#the-client-was-not-enrolled) |
| `NOT DONE: what this run wrote ... is NOT in service` | the run changed a setting the agent reads only at start, and exits non-zero | [restart the agent](#restart-the-agent) when the box can take a few seconds |
| `could not compare the serving daemon against the installed build` | the run could not tell which build serves | restart the agent, then run the root step again |
| `this key was revoked` | the key was retired at the box, for good | mint a fresh one with `syrvis api enroll-request --context nas --grade operator --rotate`, then enrol it at the box as step 2 of [the client was not enrolled](#the-client-was-not-enrolled) does |
| `a live client already holds the name "nas"` | the box refuses a second key under one name | enrol under another `--context` name. If that seat is stale, the `seat revoke` line the refusal prints frees the name |
| `class_confined` from a command that changes something, while `status` answers | your key is read-only, and a grade cannot be raised in place | [replace the key](#replace-a-read-only-key) |
| `the pin did not verify` | the pin's first read failed. The context keeps what you gave it | run `syrvis context test nas` |
| the pin line is lost | nothing is wrong: the fingerprint is not a secret | at the box, run `sudo /usr/local/libexec/syrvisd/current/syrvisd api fingerprint --pin-line` |
| the agent will not start on a file owned by uid 1026, or writable by its group or others | a DSM user wrote a control file, and the agent will not act on a file another identity can rewrite | [fix the file's owner](#fix-a-control-files-owner) |
| `census` prints `finding: MODEL: this box's settings database names two units` | your disks came from another unit. Nothing is wrong with the box | [put the factory model back](#two-model-names) |

## Restart the agent

The agent reads its home, its identity, the door, the container socket and the self-repair list only at start, and has no reload. At the box:

```
sudo /usr/syno/bin/synosystemctl restart pkg-syrviscore.service
```

## The client was not enrolled

`NOT DONE: the client was NOT enrolled. A serving daemon holds the roster` means the agent already ran as root. The run wrote the home and the door, but the door is not open yet, and no fingerprint was printed. At the box, in this order:

1. Restart the agent, which opens the door and mints its key:
   ```
   sudo /usr/syno/bin/synosystemctl restart pkg-syrviscore.service
   ```
2. Enrol your key, with your paste-line inside the quotes:
   ```
   sudo /usr/local/bin/syrvis seat enroll --client "<paste-line>"
   ```
3. Run the root step with no flags. It prints the pin line for your computer:
   ```
   sudo /var/packages/syrviscore/target/bin/syrvis-enable
   ```

Then pin the box as the install's [step 6](install.md#step-6-pin-the-box) does.

## Replace a read-only key

1. On your computer, mint a new key:
   ```
   syrvis api enroll-request --context nas --grade operator --rotate
   ```
2. At the box, revoke the old one:
   ```
   sudo /usr/local/bin/syrvis seat revoke nas
   ```
3. At the box, enrol the new paste-line:
   ```
   sudo /usr/local/bin/syrvis seat enroll --client "<the new paste-line>"
   ```
4. On your computer, pin again with the fingerprint you already have:
   ```
   syrvis context pin nas <nas-ip>:7447 <64 hex>
   ```

## Fix a control file's owner

Use the path the refusal names: on a DSM box `config.json` lives apart from the other control files. At the box:

```
sudo chown 0:0 <the path the refusal names>
sudo chmod 0644 <the path the refusal names>
sudo /usr/syno/bin/synosystemctl restart pkg-syrviscore.service
```

If the refusal says the contents are not yours, move the file aside instead: it is evidence.

## Two model names

The live settings file, `/etc/synoinfo.conf`, still names the old unit's model, while the factory copy, `/etc.defaults/synoinfo.conf`, names this one. Syrvis reads both and writes neither, and `mem.ecc` then stands on your own declaration alone. DSM owns the file, so the fix is at the box:

1. Keep a copy:
   ```
   sudo cp -p /etc/synoinfo.conf /etc/synoinfo.conf.before-model-fix
   ```
2. Print each file's `upnpmodelname` and `upnpmodeldescription`:
   ```
   sudo grep '^upnpmodel' /etc.defaults/synoinfo.conf /etc/synoinfo.conf
   ```
3. Put the factory copy's two values into the live file:
   ```
   sudo /usr/syno/bin/synosetkeyvalue /etc/synoinfo.conf upnpmodelname '<the factory name>'
   sudo /usr/syno/bin/synosetkeyvalue /etc/synoinfo.conf upnpmodeldescription '<the factory description>'
   ```
4. Run `syrvis --context nas verify`. No restart is needed, and the finding is gone.

How the connection itself is built: [Transport](../design/transport.md).
