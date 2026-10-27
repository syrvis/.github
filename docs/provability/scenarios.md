---
title: Scenarios
parent: Provability
nav_order: 1
---

# Scenarios

Your box does many things at once. The power can fail at any moment. The box can restart at any moment, too. A test tries a few of those moments. A model checker, a program called TLC, tries every order of events within small limits. It checks a written model of the design, not the code itself.

Most checks also have a broken twin: a copy of the model with one rule removed. The twin must fail. That shows the check can catch the problem it names.

Each scenario below starts with what could go wrong, in an everyday picture. Then it says what the checker makes sure of. Last, it says why that matters to you. If the October 2026 review found a check weak, the scenario says so. The [Provability](index.md) page explains how the checking works.

## Daemon

The daemon is the Syrvis program that runs on your box. It runs your workflows, watches the power and answers your computer. Its checks run with its tests, in the same gate. The lifecycle rules are checked here too, and in release 2.0.0-alpha.67 the event bus. They belong to the commons, so you will find them under [Commons](#commons).

### Upkeep that warns you once

Picture a smoke alarm with a low battery. One chirp tells you. A chirp every minute for a week only adds noise.

Your box tracks upkeep it must do, called chores. Renewing a certificate before it expires is one. The checker makes sure a chore never has two runs going at once. Each warning about a chore goes out at most once while it stays open. A status reading that was cut off never counts as all clear. Every open chore ends up cleared, gone, or flagged as overdue.

For you, this means one clear warning, not a flood. A half-read status never hides a real problem.

The review found most of these rules hold because of how the model is written. So the model tests little here, and the code's own tests check more. The promise that every chore settles also assumes every run ends well. The real box leaves a chore open after a failed run, so you see it. That is on purpose.

### When the power goes out

Picture a power cut. Your box keeps running on a battery unit called a UPS. The battery lasts only so long.

The conductor is the part of the daemon that handles this. It stops your apps and turns the box off before the battery runs out. The checker makes sure it starts at most one shutdown per power cut. It never fights a shutdown that a person already started. It turns the box off only once your apps are down. If the power comes back midway, it starts nothing new.

For you, a power cut ends in an orderly stop. Your apps stop in turn instead of losing power all at once.

The review found that only the first of these could ever fail in this model. The others repeat the model's own rules back to it. The model also never pauses a stop midway when the power returns. A stronger test runs the real conductor code through every case within its limits, pauses included. The review suggests treating that test as the conductor's proof, or giving the model a job only it can do.

### A key that stops working when you cancel it

Picture a hotel key card. A pool card never opens the office. When you check out, your card stops opening your room.

Your computer talks to the box with a key the box has enrolled. Each key has a grade, such as read, operator or admin. The checker makes sure a computer can never choose its own grade. Every call stays inside what its key's grade allows. No call of the most destructive kind is served over this connection. A key you revoke never comes back to life. Once you revoke a key, every connection using it ends.

For you, a key you cancel stays cancelled. A key meant for reading can only read.

The review found the check on each new call is never put to the test. A real bug once lived there. A key whose limits were tightened kept its old reach for up to 30 seconds. The code is fixed, and the model still needs a check for that case. The review also found the model never runs the restart case for revoked keys.

### A message split into pieces

Picture a long letter pushed through a mail slot a few pages at a time. The pages on the mat must still read as one letter, in order.

Messages between your computer and the box travel as a stream of bytes. The stream may split a message at any point. The checker makes sure every message arrives whole and in order. An oversized message is refused, never delivered. Unless a broken header closes the stream, everything sent arrives.

For you, the box acts on exactly the command you sent. It never acts on half of one.

The review found that one size check compares the wrong sizes. It measures the raw message, not the message as it is sent. A test in the code checks the real sizes.

### Work cut off by a crash, in the older engine

Picture paying a bill when your phone dies mid-payment. When it comes back, you cannot tell if the payment went through. Paying again might pay twice.

The daemon still carries its older workflow engine. It finishes work that began before the new engine took over. Nearly all new work goes to the new engine, described under [Engine](#engine). The checker makes sure a step not safe to repeat starts at most once. That holds through crashes and reboots. A step whose result is unknown is paused for you, never retried. A signal the box has acknowledged is never lost. A wait for a reboot ends only after a real reboot.

For you, a risky step, like a power-down, never runs twice. Work cut off by a crash waits for you instead of guessing.

The older engine is planned to retire, and this model will go with it. The review found the model skips some shapes the shipped reboot uses. One is a recovery step that runs after a failure. Tests in the code cover those until the model retires.

## Engine

The engine runs workflows. A workflow is a list of steps. A planned reboot is one. It stops the apps, waits for your confirm, restarts, and brings the apps back. The engine writes each step to a journal first. After a crash, it reads the journal and carries on. Its jobs wait in a queue until a worker takes them.

The engine's checks run with its tests, in the same gate. Two of its models are also tested against the real code. The checker writes 2,000 random runs of the model. A test then plays each run on the real engine. Every step must match.

### The rules do not change halfway

Picture cooking when a new edition of the cookbook comes out. You finish the recipe you started.

Each workflow is pinned to the version it started with. An update to your box does not change a running workflow's rules. The checker makes sure a workflow advances only by its pinned version. If an update drops that version, the workflow pauses and says why. It moves to a newer version only once the old one is gone. The newer version must say it can take over from that step. The move is always written down. Nothing moves while one of its jobs is paused.

For you, an update never changes a reboot halfway through.

The review found one gap. The model can move a workflow whose job has already begun. The real code refuses that, but only a code test guards it.

### A confirm means you said yes

Picture your bank asking you to approve a large payment. The yes should come from you, for the amount you saw.

Some steps, such as a planned reboot, wait for your confirm. The checker makes sure your confirm is saved before the box says it got it. So a crash cannot lose it. The guarded step runs only with the details you saw when you confirmed.

For you, a confirm is your yes, for exactly what you saw.

The review found a hole in this check. It makes sure the details match. It does not check that a person gave the confirm. In the model, a timer could close the confirm, and the check would still pass. The real code refuses that case. A past bug lived exactly there, and the code fixed it. Adding the stronger check to the model is open work.

### Try again only when it is safe

Picture sending a text twice by mistake. That is harmless. Sending a payment twice is not.

Some steps are safe to repeat. Others are not, such as powering the box down. The checker makes sure only a step marked safe to repeat gets a second try. No step is closed twice. A result the box does not know is never reported as a failure. That holds while the step might still succeed.

For you, a hiccup never makes the box repeat a risky step. You are never told something failed when it may have worked.

The review found the last of these checks is always true in the model. So it tests nothing yet. The review wrote down the fix.

### Nothing waits in silence

Picture a parcel that is running late. You want a message, not silence.

Many steps wait, for you, for a condition, or for a timer. Each wait has a due time. The checker makes sure an overdue wait sends you an alert, called a page. A crash in between does not swallow the alert. Every workflow ends, pauses, waits on something it names, or is reported late. A pause lifts once its cause is gone.

For you, the box never stalls without telling you.

The review found the model sends one alert per wait. The real box alerts again at each interval. Tests in the code cover the repeats.

### Counting the right restart

Picture asking a friend to text you when the train leaves. If they start watching too late, they wait for a train that never comes.

Some steps restart the box. The next step waits for the box to come back. The checker makes sure that wait counts from the moment the restart step began. So it sees the restart it asked for.

For you, a planned reboot finishes instead of waiting for a second restart.

The review found this case checked well here. Its broken twin fails as it should. The older engine's model missed this case.

### One job, one worker, no stale tickets

Picture a coat check. Your ticket claims your coat. Yesterday's ticket, or a copy of yours, claims nothing.

Workers take jobs from the queue under a lease, which works like a numbered ticket. A lease that ran out is stale. So is one from before a restart. The checker makes sure each try of a job starts at most once. A job that is not safe to repeat acts at most once in all. A stale ticket can never finish a job. After you abandon a workflow, none of its jobs starts again.

For you, a slow or restarted worker never doubles up work. It never finishes work it no longer owns.

### The power-cut job goes first

Picture an ambulance lane on a busy road.

When the power fails, the stop job is an emergency. One worker is kept free for emergencies only. The checker makes sure an emergency job waits at most one clock tick. That holds whenever the emergency worker is free. No kind of job runs more copies at once than its limit. A job left waiting too long is reported late.

For you, the battery shutdown never queues behind ordinary work.

The review found a real defect here, in the code. Suppose an update pauses the power-cut workflow. Then every ordinary job on the box waits too, until a person lifts the pause. The box blames a lack of workers, which is the wrong cause. The model has no paused workflows, so it could not see this. The review found it by reading the code, and a test of the real code then showed it happening. The engine is fixed in its new version, `v0.2.1`. The review also found the one-tick promise cannot fail as the model is written. And four queue rules, such as emergencies first, have no check of their own.

## Deployment

The deployment service starts, stops and updates your apps. Each app runs in a container. Some apps depend on others, the way an app depends on its database. Before a shutdown, the box drains: it stops your apps in a safe order.

The model checks a small made-up set of four apps. Two apps and a monitor depend on one database. Its checks run with its tests, in the same gate. Larger runs happen before each new version is tagged.

### The guard leaves last

Picture a building at closing time. The guard stays until everyone else is out.

Some services, such as monitoring, watch over the rest. Syrvis calls them the floor. The checker makes sure the floor stops last when the whole box shuts down. It stops only after every other app has stopped. Stopping one app that the floor relies on is refused. The refusal names a way to accept losing monitoring for a while, but no command takes that way yet. It is planned.

You can see what your box is doing until the end.

The review found the model never tried stopping the monitor on its own, so that refusal was not checked. The model now tries it, so the refusal is checked.

### Waking up in the right order

Picture turning on the water main before you open the taps.

When the box comes back, apps start in the order they need. The checker makes sure the floor starts first. Each app starts only after the apps it depends on have started.

So your apps come back working. None starts against a database that is not up yet.

The review found the check read when each app starts, not when it is ready. Waiting for ready was in the model, but nothing checked it. Now the check waits for each app to be ready, too.

### A loop of needs

Picture two people at a door, each waiting for the other to go first.

Apps can depend on each other in a loop. Then no order can stop them safely. The checker makes sure such a plan is refused. Nothing is stopped, and the refusal names the loop.

You get a clear answer you can fix, not a half-stopped box.

### A stop that always finishes

Picture closing time at a restaurant. Staff ask the last guest to leave and wait a little. Then they show the guest out.

Each app is asked to stop and given some time. If it does not stop, it is killed, then checked. The checker makes sure every stop plan finishes within its time budget. That holds even when an app never stops on its own.

A shutdown never hangs on one stubborn app.

### Never two copies at once

Picture two cooks stirring one pot, each following the recipe.

Updating an app replaces its container. A crash can strike at any point while that happens. The checker makes sure an app never has two managed containers at once. The old one goes before the new one is made. A finished update leaves one container, running.

Two copies of an app never fight over the same files.

### Old versions go to the shred pile first

Picture clearing out old papers. You move them to a shred pile first. You never shred the copy you use, or your backup.

The service keeps past versions of your app setup, called revisions. That lets you roll back. The checker makes sure no crash leaves an erased revision still listed. The current revision is always listed. Cleanup never removes the current one, the newest kept ones, or your rollback target.

A rollback always has something real to go back to.

The review found the rollback target was checked only when every update succeeded. A run of failed updates is the case it exists for. The model now covers that case.

### No new work during a shutdown

Picture a theater after the last show. Nobody new is let in.

When the whole box drains for a shutdown, deploy work must stop. The checker makes sure no update, rollback or cleanup starts while the box drains. No update or rollback starts while it restores, either. A job cut off by the drain may finish only the step under way. Background repair may only create a missing container, without starting it.

A shutdown is never undone by an update that slips in.

The review found a real defect here. A cut-off job's last step could start an app after the shutdown counted it stopped. That app then ran while the box said every app was stopped. The final power-off checks again first, so the power never went off under it. But the drain's promise was broken, and its report was wrong. A test of the real code showed it happening, and the daemon had the same code. Both are now fixed. The drain notes the jobs it cut off. The stop waits a limited time for them to end, then checks once more and stops any app that came up.

The review also found the model let a cleanup start once the stop had finished, before the drain was released. The real code refuses that, and now the model does too.

## Commons

The commons is shared code the Syrvis components build on. Two parts of it have models: the lifecycle rules and the event bus. In release 2.0.0-alpha.67 the daemon's checks run both models. Since then the commons checks the lifecycle model next to its rules, as the review suggested, and the event bus model has been retired.

The lifecycle rules are one table of 208 cells. A test holds the code's copy of the table equal to the model's. It compares them byte for byte.

### One place at a time

Picture a traffic light. It shows one color at a time.

Your box is always in one of seven places. Examples are booting, in service, draining, shutting down and down. Several conditions can be true at once. One fixed order decides which place wins. The checker makes sure the box is in exactly one place at all times.

So there is one answer to what your box is doing.

The review found this check cannot fail as written. It confirms a definition. A test in the code checks the order that picks the place.

### Closing time, with the fire exit open

Picture a shop at closing time. No new customers come in. The fire exit still opens.

When your box drains for a reboot or shutdown, new deploy work must wait. Deploy work means things like an update or a rollback. The checker makes sure none starts in four places. They are draining, drained, shutting down and down. None starts while a reboot or shutdown is running. None starts while the box runs on battery, either. The emergency power stop can always start, unless the box is already off.

An update never lands in the middle of a shutdown. And a power cut can always start a safe stop.

The review found the first rule watches place names, not the drain itself. Two places, booting and unfit, can hold a drain the rule does not see. The review also found the emergency check proves the stop may start. It does not prove the stop succeeds.

### One reboot at a time

Picture a plane with two pilots. Only one flies it at a time.

A reboot or shutdown runs as a procedure with several steps. The checker makes sure at most one such procedure runs at a time. A running reboot can always declare its own drain. While it runs, nobody can declare a box-wide drain by hand.

Two procedures never pull your box in different directions.

The review found one check aimed at the wrong thing. The model says nobody can release a running reboot's drain by hand. The real product allows it. It first abandons the reboot, then releases the drain. The product's real promise is that no reboot keeps running over a released drain. That promise is not checked yet.

### A slow listener

Picture a friend who reads your messages slowly. When their inbox fills up, you tell them once that some were dropped.

Inside the daemon, events go out to listeners. A slow listener can fall behind. The checker makes sure the dropped-messages signal is sent at most once. Two senders never step on each other while sending.

One slow part of the daemon cannot crash the rest.

An earlier version of this code could send that signal twice. With its lock removed, the model shows that old bug. The review found this code has since moved into the commons. A test there explores the same steps, written in Go. The review suggested keeping a single proof, next to the code, and that test is now the only one: the model has been retired.
