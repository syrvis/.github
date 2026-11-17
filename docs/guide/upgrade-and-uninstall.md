---
title: Upgrade and uninstall
parent: User guide
nav_order: 5
---

# Upgrade and uninstall

An upgrade is one command on your computer and one root line you run on the server, through the Task Scheduler task "syrvis root" you kept from the install. An uninstall is a command on your computer, one root line you run in a terminal on the server, then the same command again with that line's last line. Going back to an older release is an uninstall, then a first install of that release.

## Upgrade the package

When the server runs a release older than your `syrvis` serves, `syrvis` says so and points here:

```screen
upgrade the box to <box_min>: https://syrvis.github.io/.github/guide/upgrade-and-uninstall.html, Upgrade the package
```

1. On your computer, run `install` with the release you want:
   ```
   syrvis --context nas install <version>
   ```
   `syrvis` fetches the release, checks it, and sends the package to the server. Then it prints one root line. Like the install's, it ends in a 16-character code:
   ```screen
   /var/packages/syrviscore/target/bin/syrvis-enable --upgrade --answers <16 hex>
   ```
2. In DSM, put that line into the task you kept. `syrvis` says it in these words: "Control Panel > Task Scheduler > syrvis root > Edit; replace its line with this one (the task runs it as root), then Save and Run; the task stays".
3. Wait for `syrvis` to finish in the terminal. It finishes by itself once the line has run.

As `syrvis` warns, "running this line restarts syrvis; its door closes for about 15 s and every open session drops; nothing you deployed stops".

To see the server's version afterwards, on your computer:

```
syrvis --context nas status
```

## Upgrade syrvis on your computer

Between package releases, take a newer `syrvis` from the same release page you got it from, as [Install: the first handshake](install.md) says under "What you need". You use it as before. Then check which servers it serves:

```
syrvis version
```

Its second line, `bound: serves boxes from <version>; tested with <version>`, says which servers it serves: the server must run the first version or a later one. If yours is older, [upgrade the package](#upgrade-the-package).

## Go back to an older release

On DSM 7.4.1 no older package installs over a newer one. Package Center refuses with `You cannot roll back to the older version`, and `synopkg install` refuses with `cannot downgrade to older version`. So a downgrade is the uninstall below, then a first install of the older release, as [Install: the first handshake](install.md) walks it. The server's state is not carried: each computer pairs again, and you apply your declaration anew.

## Uninstall

Start on your computer:

```
syrvis --context nas uninstall
```

Copies of `syrvis` up to v0.1.6 spell the verb `undo`, and their `undo` takes neither `--keep-identity` nor `--erase-identity`.

To read the whole teardown first, in a terminal on the server:

```
sudo /var/packages/syrviscore/target/bin/syrvis-enable --uninstall-help
```

It prints what the uninstall will stop, remove and keep, and the two words its prompt takes. It changes nothing.

### What the server holds

`syrvis` reads the server and shows three rows: `services`, `home` and `identity`. While services you deployed are still on the server, it waits, and prints the command that removes them:

```screen
syrvis --context nas prune <services>
```

Retire those services first. Declare the server without them and apply that, then `prune` the orphans the plan reports. `prune` is served only at the server; over a context it refuses and names the command to run there. Syrvis never removes a Docker volume, and the containers and networks a layer-1 registry named stay too: remove the ones you want gone in Container Manager.

### Keep or erase the identity

`syrvis` asks one question: "What should uninstall do with this box's identity?" The answers are "Keep it", "Erase it" and "Stop here". To answer before it asks, add `--keep-identity` or `--erase-identity` to the command.

Keeping the identity leaves `/usr/local/etc/syrvisd/` in place. Erasing it removes that folder too, and with it the key roster, so every computer must enrol again. While the identity stands, Package Center will not uninstall SyrvisCore.

### The root line

Under `At the box, as root, run this one line:`, `syrvis` prints the line for your answer. To keep the identity:

```
echo undo | sudo /var/packages/syrviscore/target/bin/syrvis-enable --undo
```

To erase it:

```
echo undo-identity | sudo /var/packages/syrviscore/target/bin/syrvis-enable --undo
```

Run it in a terminal on the server, over SSH, where you can read its last line. Run it before you uninstall SyrvisCore in Package Center, because that uninstall deletes the script that carries it.

The server prints what it will stop, remove and keep, then its prompt, `type keep-identity (or erase-identity), then Enter. Anything else stops and changes nothing:`, which the `echo` at the front of the line answers. It disarms boot start, stops the daemon, waits until DSM reports the unit inactive, and only then removes the daemon's root-owned copy. It also removes the boot hook, the rescue copy and its stamp, the `/usr/local/bin/syrvis` link, and the mark the install left at the handover. Then it prints its rows and `Done. syrvis is off on <host>.`

Its last line depends on your answer. When you keep the identity, it is:

```screen
so it refuses while /usr/local/etc/syrvisd/ stands, naming this line.
```

When you erase it, it is:

```screen
Uninstall removes it.
```

### The last step

Back on your computer, give `syrvis` that last line:

```
syrvis --context nas uninstall --last-line "<its last line>"
```

Once the server refuses its connection, `syrvis` prints three `sudo rm -f` lines it calls "the lines the root step cannot take itself". The root step has already removed those files, so running the lines does no harm. Then it prints what is left for you to do and closes with:

```screen
the uninstall is done; this computer's install record for nas is removed, and the context nas is forgotten, its key kept
```

After an erase, what is left is "Package Center > SyrvisCore > Uninstall, Package Center > syrvis installer > Uninstall, and the marker file".

## After the uninstall

1. In Package Center, choose SyrvisCore > Uninstall. It deletes nothing of yours, and DSM removes the package's own data directory with it. While the identity stands, DSM's uninstall shows "refused: SyrvisCore was not uninstalled." and the package stays, ready for a reinstall, until the root line runs with `undo-identity`.
2. In Package Center, choose syrvis installer > Uninstall.
3. Delete `.syrvis-volume.json` from the top of the shared folder, then the folder if you no longer want it.
4. Either answer leaves `/var/services/homes/syrvis/api-fingerprint.txt`, `/var/log/syrvis/`, and any accounts made with `--service-user`; `/var/packages/syrviscore/var/` stays until the package goes. Remove them, and the firewall rule you added, if you no longer want them.
