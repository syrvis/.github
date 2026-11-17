---
title: Scenarios
parent: Provability
nav_order: 1
---

# Scenarios

A model checker tries the orderings of events that tests miss. The server does many things at once, and the power can fail or the server restart at any moment. A test tries a few of those moments. A model checker, a program called TLC, tries every order of events within small limits. It checks a written model of the design; the code itself stays outside the check.

Most checks also have a broken twin: a copy of the model with one rule removed. The twin must fail, which shows the check can catch the problem it names.

Each scenario below first says what the checker makes sure of. An everyday picture of what could go wrong follows, then why it matters to you. Where the October 2026 review found a check weak, the scenario says so. The [Provability](index.md) page explains how the checking works.

## Daemon

The daemon is the Syrvis program that runs on the server. It runs your workflows, watches the power and answers your computer. Its checks run with its tests, in the same gate. The lifecycle rules are checked here too, and in release 2.0.0-alpha.67 the event bus. They belong to the commons, so they are described under [Commons](#commons).

### Upkeep that warns you once

The server tracks upkeep it must do, called chores; renewing a certificate before it expires is one. The checker makes sure a chore never has two runs going at once. Each warning about a chore goes out at most once while the chore stays open. A status reading that was cut off never counts as all clear. Every open chore ends up cleared, gone, or flagged as overdue.

Picture a smoke alarm with a low battery: one chirp tells you, and a chirp every minute for a week only adds noise. You get one clear warning per open chore, and a half-read status never hides a real problem.

The review found most of these rules hold because of how the model is written, so the model tests little here and the code's own tests check more. The promise that every chore settles also assumes every run ends well. The real server leaves a chore open after a failed run, so you see it, and that is on purpose.

### When the power goes out

On a power cut the server keeps running on a battery unit called a UPS, which lasts only so long. The conductor, the part of the daemon that handles this, stops your services and turns the server off before the battery runs out. The checker makes sure it starts at most one shutdown per power cut. It never fights a shutdown that a person already started. It turns the server off only once your services are down. If the power comes back midway, it starts nothing new.

A power cut ends in an orderly stop: your services stop in turn instead of losing power all at once.

The review found that only the first of these could ever fail in this model; the others repeat the model's own rules back to it. The model also never pauses a stop midway when the power returns. A stronger test runs the real conductor code through every case within its limits, pauses included. The review suggests treating that test as the conductor's proof, or giving the model a job only it can do.

### A key that stops working when you cancel it

Your computer talks to the server with a key paired with the server. Each key has a grade, such as read, operator or admin. The checker makes sure a computer can never choose its own grade. Every call stays inside what its key's grade allows. No call of the most destructive kind is served over this connection. A key you revoke never comes back to life, and once you revoke a key, every connection using it ends.

Picture a hotel key card: a pool card never opens the office, and when you check out, your card stops opening your room. A key you cancel stays cancelled, and a key meant for reading can only read.

The review found the check on each new call is never put to the test, and a real bug once lived there: a key whose limits were tightened kept its old reach for up to 30 seconds. The code is fixed, and the model still needs a check for that case. The review also found the model never runs the restart case for revoked keys.

### A message split into pieces

Messages between your computer and the server travel as a stream of bytes, and the stream may split a message at any point. The checker makes sure every message arrives whole and in order. An oversized message is refused, never delivered. Unless a broken header closes the stream, everything sent arrives.

Picture a long letter pushed through a mail slot a few pages at a time; the pages on the mat must still read as one letter, in order. The server acts on exactly the command you sent and never on half of one.

The review found that one size check compares the wrong sizes: it measures the raw message where it should measure the message as it is sent. A test in the code checks the real sizes.

### Work cut off by a crash, in the older engine

The daemon still carries its older workflow engine, which finishes work that began before the new engine took over. Nearly all new work goes to the new engine, described under [Engine](#engine). The checker makes sure a step not safe to repeat starts at most once, through crashes and reboots. A step whose result is unknown is paused for you, never retried. A signal the server has acknowledged is never lost. A wait for a reboot ends only after a real reboot.

Picture paying a bill when your phone dies mid-payment: when it comes back, you cannot tell if the payment went through, and paying again might pay twice. Here a risky step, like a power-down, never runs twice, and work cut off by a crash waits for you instead of guessing.

The older engine is planned to retire, and this model will go with it. The review found the model skips some shapes the shipped reboot uses, such as a recovery step that runs after a failure. Tests in the code cover those until the model retires.

## Engine

The engine runs workflows. A workflow is a list of steps; a planned reboot is one, which stops the services, waits for your confirm, restarts, and brings the services back. The engine writes each step to a journal first, and after a crash it reads the journal and carries on. Its jobs wait in a queue until a worker takes them.

The engine's checks run with its tests, in the same gate. Two of its models are also tested against the real code: the checker writes 2,000 random runs of the model, a test plays each run on the real engine, and every step must match.

### The rules do not change halfway

Each workflow is pinned to the version it started with, so an upgrade on the server does not change a running workflow's rules. The checker makes sure a workflow advances only by its pinned version. If an upgrade drops that version, the workflow pauses and says why. It moves to a newer version only once the old one is gone, and the newer version must say it can take over from that step. The move is always written down. Nothing moves while one of its jobs is paused.

Picture cooking when a new edition of the cookbook comes out: you finish the recipe you started. An upgrade never changes a reboot halfway through.

The review found one gap: the model can move a workflow whose job has already begun. The real code refuses that, and only a code test guards it.

### A confirm means you said yes

Some steps, such as a planned reboot, wait for your confirm. The checker makes sure your confirm is saved before the server says it got it, so a crash cannot lose it. The guarded step runs only with the details you saw when you confirmed.

Picture your bank asking you to confirm a large payment: the yes should come from you, for the amount you saw, and a confirm here holds to the same rule.

The review found a hole in this check. It makes sure the details match; it does not check that a person gave the confirm. In the model a timer could close the confirm, and the check would still pass. The real code refuses that case. A past bug lived exactly there, and the code fixed it. Adding the stronger check to the model is open work.

### Try again only when it is safe

Some steps are safe to repeat; others, such as powering the server down, are not. The checker makes sure only a step marked safe to repeat gets a second try. No step is closed twice. A result the server does not know is never reported as a failure while the step might still succeed.

Picture sending a text twice by mistake, which is harmless, against sending a payment twice. A hiccup never makes the server repeat a risky step, and you are never told something failed when it may have worked.

The review found the last of these checks is always true in the model, so it tests nothing yet. The review wrote down the fix.

### Nothing waits in silence

Many steps wait: for you, for a condition, or for a timer. Each wait has a due time. The checker makes sure an overdue wait sends you an alert, called a page, and that a crash in between does not swallow the alert. Every workflow ends, pauses, waits on something it names, or is reported late. A pause lifts once its cause is gone.

Picture a parcel that is running late, and the message you want about it. The server never stalls without telling you.

The review found the model sends one alert per wait, while the real server alerts again at each interval. Tests in the code cover the repeats.

### Counting the right restart

Some steps restart the server, and the next step waits for the server to come back. The checker makes sure that wait counts from the moment the restart step began, so it sees the restart it asked for.

Picture asking a friend to text you when the train leaves: if they start watching too late, they wait for a train that never comes. A planned reboot finishes instead of waiting for a second restart.

The review found this case checked well here: its broken twin fails as it should. The older engine's model missed this case.

### One job, one worker, no stale tickets

Workers take jobs from the queue under a lease, which works like a numbered ticket. A lease that ran out is stale, and so is one from before a restart. The checker makes sure each try of a job starts at most once. A job that is not safe to repeat acts at most once in all. A stale ticket can never finish a job. After you abandon a workflow, none of its jobs starts again.

Picture a coat check: your ticket claims your coat, and yesterday's ticket, or a copy of yours, claims nothing. A slow or restarted worker never doubles up work and never finishes work it no longer owns.

### The power-cut job goes first

When the power fails, the stop job is an emergency, and one worker is kept free for emergencies only. The checker makes sure an emergency job waits at most one clock tick whenever the emergency worker is free. No kind of job runs more copies at once than its limit. A job left waiting too long is reported late.

Picture an ambulance lane on a busy road. The battery shutdown never queues behind ordinary work.

The review found a real defect here, in the code. Suppose an upgrade pauses the power-cut workflow. Then every ordinary job on the server waits too, until a person lifts the pause, and the server blames a lack of workers, which is the wrong cause. The model has no paused workflows, so it could not see this. The review found it by reading the code, and a test of the real code then showed it happening. The engine is fixed in its new version, `v0.2.1`. The review also found that the one-tick promise cannot fail as the model is written, and that four queue rules, such as emergencies first, have no check of their own.

## Deployment

The deployment service starts, stops and updates your services. Each service runs in a container. Some services depend on others, the way a service depends on its database. Before a shutdown, the server drains: it stops your services in a safe order.

The model checks a small made-up set of four services: two services and a monitor depend on one database. Its checks run with its tests, in the same gate, and larger runs happen before each new version is tagged.

### The guard leaves last

Some services, such as monitoring, watch over the rest; Syrvis calls them the floor. The checker makes sure the floor stops last when the whole server shuts down, only after every other service has stopped. Stopping one service that the floor relies on is refused. The refusal names a way to accept losing monitoring for a while, but no command takes that way yet; it is planned.

Picture a building at closing time, where the guard stays until everyone else is out. You can see what the server is doing until the end.

The review found the model never tried stopping the monitor on its own, so that refusal was not checked. The model now tries it, so the refusal is checked.

### Waking up in the right order

When the server comes back, services start in the order they need. The checker makes sure the floor starts first, and each service starts only after the services it depends on have started.

Picture turning on the water main before you open the taps. Your services come back working, and none starts against a database that is not up yet.

The review found the check read when each service starts and ignored when it is ready. Waiting for ready was in the model, but nothing checked it. Now the check waits for each service to be ready, too.

### A loop of needs

Services can depend on each other in a loop, and then no order can stop them safely. The checker makes sure such a plan is refused: nothing is stopped, and the refusal names the loop.

Picture two people at a door, each waiting for the other to go first. You get a clear answer you can fix, and the server is never left half-stopped.

### A stop that always finishes

Each service is asked to stop and given some time. If it does not stop, it is killed, then checked. The checker makes sure every stop plan finishes within its time budget, even when a service never stops on its own.

Picture closing time at a restaurant: staff ask the last guest to leave, wait a little, then show the guest out. A shutdown never hangs on one stubborn service.

### Never two copies at once

Updating a service replaces its container, and a crash can strike at any point while that happens. The checker makes sure a service never has two managed containers at once: the old one goes before the new one is made, and a finished update leaves one container, running.

Picture two cooks stirring one pot, each following the recipe. Two copies of a service never fight over the same files.

### Old versions go to the shred pile first

The deployment service keeps past versions of your setup, called revisions, so you can roll back. The checker makes sure no crash leaves an erased revision still listed. The current revision is always listed. Cleanup never removes the current one, the newest kept ones, or your rollback target.

Picture clearing out old papers: you move them to a shred pile first, and you never shred the copy you use or your backup. A rollback always has something real to go back to.

The review found the rollback target was checked only when every update succeeded, though a run of failed updates is the case it exists for. The model now covers that case.

### No new work during a shutdown

When the whole server drains for a shutdown, deploy work must stop. The checker makes sure no update, rollback or cleanup starts while the server drains, and no update or rollback starts while it restores. A job cut off by the drain may finish only the step under way. Background repair may only create a missing container, without starting it.

Picture a theater after the last show, where nobody new is let in. A shutdown is never undone by an update that slips in.

The review found a real defect here. A cut-off job's last step could start a service after the stop counted it stopped. That service then ran while the server said every service was stopped. The final power-off checks again first, so the power never went off under it, but the drain's promise was broken and its report was wrong. A test of the real code showed it happening, and the daemon had the same code. Both are now fixed. The drain notes the jobs it cut off. The stop waits a limited time for them to end, then checks once more and stops any service that came up.

The review also found the model let a cleanup start once the stop had finished, before the drain was released. The real code refuses that, and now the model does too.

## Commons

The commons is shared code the Syrvis components build on. Two parts of it have models: the lifecycle rules and the event bus. In release 2.0.0-alpha.67 the daemon's checks run both models. Since then the commons checks the lifecycle model next to its rules, as the review suggested, and the event bus model has been retired.

The lifecycle rules are one table of 208 cells. A test holds the code's copy of the table equal to the model's, comparing them byte for byte.

### One place at a time

The server is always in one of seven places, among them booting, in service, draining, shutting down and down. Several conditions can be true at once, and one fixed order decides which place wins. The checker makes sure the server is in exactly one place at all times.

Picture a traffic light, which shows one color at a time. There is one answer to what the server is doing.

The review found this check cannot fail as written: it confirms a definition. A test in the code checks the order that picks the place.

### Closing time, with the fire exit open

When the server drains for a reboot or shutdown, new deploy work, such as an update or a rollback, must wait. The checker makes sure none starts in four places: draining, drained, shutting down and down. None starts while a reboot or shutdown is running, or while the server runs on battery. The emergency power stop can always start, unless the server is already off.

Picture a shop at closing time: no new customers come in, and the fire exit still opens. An update never lands in the middle of a shutdown, and a power cut can always start a safe stop.

The review found the first rule watches place names and misses the drain itself: two places, booting and unfit, can hold a drain the rule does not see. The review also found the emergency check proves the stop may start and does not prove the stop succeeds.

### One reboot at a time

A reboot or shutdown runs as a procedure with several steps. The checker makes sure at most one such procedure runs at a time. A running reboot can always declare its own drain, and while it runs, nobody can declare a server-wide drain by hand.

Picture a plane with two pilots, only one flying it at a time. Two procedures never pull the server in different directions.

The review found one check aimed at the wrong thing. The model says nobody can release a running reboot's drain by hand. The real product allows it: it first abandons the reboot, then releases the drain. The product's real promise is that no reboot keeps running over a released drain, and that promise is not checked yet.

### A slow listener

Inside the daemon, events go out to listeners, and a slow listener can fall behind. The checker makes sure the dropped-messages signal is sent at most once, and two senders never step on each other while sending.

Picture a friend who reads your messages slowly: when their inbox fills up, you tell them once that some were dropped. One slow part of the daemon cannot crash the rest.

An earlier version of this code could send that signal twice, and with its lock removed, the model shows that old bug. The review found this code has since moved into the commons, where a test explores the same steps, written in Go. The review suggested keeping a single proof, next to the code, and that test is now the only one: the model has been retired.
