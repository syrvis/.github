---
title: Upgrade and undo
parent: User guide
nav_order: 5
---

# Upgrade and undo

An upgrade is two acts: install the newer package in Package Center, then run the root step with no flags, so the box serves the new build. Going back to an older release is the full undo, then a first install of that release. The undo itself is one root command, run before Package Center's uninstall.

## Upgrade the package

1. Download the newer `syrvisd-<version>.spk` and its `.spk.sha256` and `.daemon.sha256` files from the release page.
2. Hash the package, and compare the result with the `.spk.sha256` file. On Linux, use `sha256sum`:
   ```
   shasum -a 256 syrvisd-<version>.spk
   ```
3. In Package Center, choose Manual Install > Browse, pick the newer `.spk`, and follow the dialog.
4. At the box, run the root step with no flags:
   ```
   sudo /var/packages/syrviscore/target/bin/syrvis-enable
   ```
5. If it prints the line `about to install the daemon from`, compare the `sha256` under it with the `.daemon.sha256` file.
6. On your computer, check the agent's version:
   ```
   syrvis --context nas status
   ```

Step 4 is owed after every upgrade. DSM does not restart a root service that is already running, so the box serves the old build until you run it. The run compares the installed build with the serving one, and restarts the agent without asking when they differ. The restart drops every open connection to the agent. When the builds match, the run changes nothing and asks for no restart.

If the run prints `could not compare the serving daemon against the installed build`, restart the agent, then run step 4 again:

```
sudo /usr/syno/bin/synosystemctl restart pkg-syrviscore.service
```

## Upgrade the client

Between package releases, take a newer client from the client's own releases:

```
https://github.com/syrvis/syrvis-client/releases
```

Install and check it as the install's [step 1](install.md#step-1-get-the-client) does. Then run `syrvis version`. Its second line, `bound: serves boxes from <version>; tested with <version>`, says which boxes it serves: the box must run the first version or a later one. Client v0.1.1, the one 2.0.0-alpha.67 carries, serves boxes from 2.0.0-alpha.67.

## Go back to an older release

On DSM 7.4.1 no older package installs over a newer one. Package Center refuses with `You cannot roll back to the older version`, and `synopkg install` refuses with `cannot downgrade to older version`. So a downgrade is the undo below, then a first install of the older release, as the [Install](install.md) page walks it. The box's state is not carried: each computer pairs again, and you apply your declaration anew.

## Undo

Run the undo before Package Center's uninstall, because the uninstall deletes the script that carries it. To read the whole teardown first, at the box:

```
sudo /var/packages/syrviscore/target/bin/syrvis-enable --undo-help
```

1. While the agent still runs, retire the services you deployed. Declare the box without them and apply that, then `prune` the orphans the plan reports. `prune` is served only at the box; over a context it refuses and names the command to run there. The product never removes a Docker volume, and the containers and networks a layer-1 registry named stay too: remove the ones you want gone in Container Manager.
2. At the box, take the agent down and remove what the package cannot:
   ```
   sudo /var/packages/syrviscore/target/bin/syrvis-enable --undo
   ```
   It lists what it will remove and what it will leave, read off the box, and asks for one word. `undo` disarms boot start, stops the agent, waits until DSM reports the unit inactive, and only then removes the agent's root-owned copy. It leaves `/usr/local/etc/syrvisd/`. `undo-identity` removes that folder too, and with it the key roster, so every computer must enrol again. Anything else stops the run with nothing changed. Through Task Scheduler there is no prompt, so give the word on standard input:
   ```
   echo undo | sudo /var/packages/syrviscore/target/bin/syrvis-enable --undo
   ```
3. Remove the rescue copy and its boot script, which no uninstall can take. Until you do, the boot script runs that copy as root at every boot:
   ```
   sudo rm -f /usr/local/etc/rc.d/S99syrvisd.sh /usr/local/lib/syrviscore/syrvisd-rescue /usr/local/lib/syrviscore/syrvisd-rescue.version
   ```
4. In Package Center, choose SyrvisCore > Uninstall. It deletes nothing of yours, and DSM removes the package's own data directory with it.
5. Delete `.syrvis-volume.json` from the top of the shared folder, then the folder if you no longer want it.
6. Remove `/var/services/homes/syrvis/` if it exists, and the firewall rule you added, if you no longer want them.
