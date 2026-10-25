---
title: Install
parent: User guide
nav_order: 1
---

# Install

The install is six steps: get the `syrvis` command, create a shared folder, install the package, mint your key, run one root command at the box, and pin the box from your computer. It is done when `syrvis --context nas next` answers `set-up`.

If the box holds data you care about, read the pre-install checklist first. It lists every file Syrvis writes and every file an uninstall leaves, and it ships inside the package. The `.spk` is an ordinary tar, so this line prints the checklist without unpacking anything else:

```
tar -xOf syrvisd-<version>.spk package.tgz | tar -xzOf - doc/preinstall-checklist.md
```

## What you need

| what | why |
|---|---|
| an x86_64 Synology whose CPU family is in the package's list | DSM refuses any other family with Error 281 and leaves nothing behind. ARM models are not supported |
| DSM 7.0-40656 or newer | the package's floor. Syrvis is measured on DSM 7.4.1; the builds between are not tested |
| a storage pool with at least one volume | DSM installs the package on a volume, and Syrvis manages one |
| a DSM administrator account | for the root step. SSH is optional |
| Package Center allowing packages from any publisher | the package is not signed by Synology |
| Container Manager, only to run services | status, census, health and hardware reads work without it |
| a computer whose address does not change | your key is pinned to the address the box sees. Reserve one in your router |
| macOS, or Linux on x86_64 | the client ships as `syrvis-darwin-arm64`, `syrvis-darwin-amd64` and `syrvis-linux-amd64` |

The package's CPU families are `x86_64 avoton v1000 apollolake geminilake denverton broadwellnk r1000`. Your model's token is on the CPU line of Control Panel > Info Center > General. With SSH, this prints `synology_<token>_<model>`:

```
/usr/syno/bin/synogetkeyvalue /etc.defaults/synoinfo.conf unique
```

If your token is not in the list, ask for a build with it added before you install.

## Step 1: Get the client

The client is a release asset, and each package release carries the client it was tested with: 2.0.0-alpha.67 carries client v0.1.1. At this release the repositories are private, so you need read access to the syrvis organisation before the release pages open.

1. Open the releases, and pick 2.0.0-alpha.67:
   ```
   https://github.com/syrvis/syrvis/releases
   ```
2. Download `SHA256SUMS` and the build for your machine into one folder.
3. In that folder, check the build. On Linux, run `sha256sum -c SHA256SUMS --ignore-missing` instead:
   ```
   shasum -a 256 -c SHA256SUMS --ignore-missing
   ```
4. Rename the build to `syrvis`. For Apple silicon:
   ```
   mv syrvis-darwin-arm64 syrvis
   ```
5. If it came through a browser, AirDrop, Messages or Mail, clear the quarantine mark that stops macOS running it:
   ```
   xattr -d com.apple.quarantine syrvis
   ```
6. Make it executable, and put it on your PATH:
   ```
   chmod +x syrvis
   sudo mkdir -p /usr/local/bin && sudo mv syrvis /usr/local/bin/
   ```
7. Run `syrvis version`. Its second line is the bound, `bound: serves boxes from <version>; tested with <version>`. The box must run the first version named, or a later one.

## Step 2: Create the shared folder

Syrvis manages one directory on one volume, which it calls its home. The home is a DSM shared folder that you create, on the volume you want managed, under any name.

1. Open Control Panel > Shared Folder > Create.
2. Pick the volume, and type a name. Leave encryption off: an encrypted share is not tested.
3. Write the spelling down exactly. DSM share names are case-insensitive, so `syrviscore` and `SyrvisCore` are one name.

The folder's path is `/volume1/<name>` on Volume 1, `/volume2/<name>` on Volume 2, and so on. Below, it is `/volumeN/<share>`. The root step writes one file into it, `.syrvis-volume.json`, and nothing else.

## Step 3: Install the package

The package is `syrvisd-2.0.0-alpha.67.spk` on the same release page, beside its `.spk.sha256` and `.daemon.sha256` files. Keep the daemon file for step 5. For this release the package's sha256 is `993f1f1810664d1a9d3eb00f05a3c08fd7878b8c130826e840e45a7fe716f059`, and the daemon's is `a325dfb2de91876d25d6cb2b0c94282a2c72c08e3eb9626131ee714dd934ce7f`.

1. Hash the package, and compare the result with the `.spk.sha256` file. On Linux, use `sha256sum`:
   ```
   shasum -a 256 syrvisd-2.0.0-alpha.67.spk
   ```
2. In Package Center, choose Manual Install > Browse, pick the `.spk`, and click Next.
3. Pick the volume for the package. It may differ from the home's volume.
4. Leave *Run after installation* ticked, and click Apply.

DSM then starts the agent with reduced privileges: it reads, and changes nothing. The dialog prints the commands of steps 4 and 5, which are also below. If the install refuses an untrusted publisher, set Package Center > Settings > General > Trust Level. If Package Center shows the package stopped or offers Repair, do not click Repair: step 5 comes next.

## Step 4: Mint your key

On your computer:

```
syrvis api enroll-request --context nas --grade operator
```

`nas` is your name for the box. `--grade operator` asks for the grade that can change the box. Without it the key is read-only, and raising it later costs a new key and two commands at the box.

The private half of the key never leaves your computer. The command prints the paste-line, `name=nas,spki=<64 hex>,from=<your address>/32,grade=operator`; keep it for step 5. If your computer has several addresses, the command lists them and refuses. Run it again with `--from <address>` added, naming the one on the box's network.

## Step 5: Run the root step

One command, run as root at the box, does the whole device-side first run. It installs a root-owned copy of the agent and a rescue copy with its boot script, names your home, declares the container engine and the address your computer dials, enrols your key, and makes the agent a root service that starts at boot.

| value | where it comes from |
|---|---|
| `/volumeN/<share>` | step 2's path, spelled exactly |
| `/var/run/docker.sock` | Container Manager's socket. You may pass it before Container Manager is installed, or leave out `--docker-socket` and the path |
| `<nas-ip>` | the address you type into a browser to reach DSM: Control Panel > Network > Network Interface |
| `<paste-line>` | step 4's line, inside the quotes |

```
sudo /var/packages/syrviscore/target/bin/syrvis-enable --home /volumeN/<share> --docker-socket /var/run/docker.sock --api-listen <nas-ip>:7447 --api-client "<paste-line>"
```

**Route A, over SSH.** Tick Control Panel > Terminal & SNMP > *Enable SSH service*, and click Apply. Run `ssh <admin>@<nas-ip>`, paste the command, and give `sudo` your DSM password. You can turn SSH off afterwards.

**Route B, without SSH.** Choose Control Panel > Task Scheduler > Create > Scheduled Task > User-defined script. Set User to `root`, paste the command into the script box, and save. Select the task, click Run, then right-click it and choose View Result. Not yet measured: whether View Result shows every line. The last two lines matter most.

Read three things in what it prints:

- The line `about to install the daemon from`, with `sha256 <64 hex>` under it. Compare that hash by eye with the `.daemon.sha256` file. If they differ, stop and report it.
- The pin line, `syrvis context pin nas <nas-ip>:7447 <64 hex>`, under `fingerprint` or under `next`. Copy it whole for step 6.
- Any line beginning `NOT DONE`. It names what did not happen and the command to run next. [Troubleshooting](troubleshooting.md) lists the common ones.

The run also prints the agent's health verdict and an `undo` line; [Upgrade and undo](upgrade-and-undo.md) covers the teardown. Running the same command again with the same flags changes nothing, and prints `start-time keys moved: none`.

## Step 6: Pin the box

If DSM's firewall denies by default, allow 7447/tcp from your computer's address first, or the pin times out. The package asks DSM to list a service named SyrvisCore for that port; if the list does not show it, allow the port number. The package opens no port by itself.

On your computer, paste the pin line:

```
syrvis context pin nas <nas-ip>:7447 <64 hex>
```

It records where the box is and which key the box must present, and takes the first authenticated read. Then ask the box about itself:

```
syrvis --context nas status
syrvis --context nas next
```

`status` answers with the instance id and the agent's version, and `next` answers `set-up`. [First steps](first-steps.md) goes on from here.
