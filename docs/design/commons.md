---
title: Commons
parent: Design
nav_order: 6
---

# Commons

syrvis-common holds the libraries below the services that every syrvis daemon composes: seven Go modules in one repository, in a strict partial order from the primitives up. It holds no service, no assembly and no definition of the box. Tests hold the order: one refuses a cycle among the modules, and a wall refuses any import from above. The `frame` module holds the lifecycle table and its one evaluator, which admits or refuses each operation on the box, beside the TLA+ model that is the table's source of record.

## The seven modules

Each module is its own `go.mod`, tagged `<module>/vX.Y.Z`. It imports the standard library, syrvis's contract module `api/` at a tag, and only the commons modules its row allows (`layout_test.go`). The daemon requires all seven at `v0.1.1`; the [deployment service](deployment.md) requires five, all but `grading` and `secretstore`.

| module | packages | what it holds | may import |
|---|---|---|---|
| `primitives` | `fact`, `journal`, `events`, `statetable`, `fileproof`, `units`, `conform` | the vocabulary below everything | none |
| `declarations` | `fleet`, `chores`, `ingress` | what the box is told to run | `primitives` |
| `adapters` | `platform`, `platform/dsmexec`, `rtnl`, `dockerclient`, `dockerclient/enginefake` | how the box is acted on | `primitives` |
| `probes` | `hostfacts`, `hostfacts/models`, `edgeprobe`, `fsprobe`, `kmsg`, `deadman`, `volmarker` | how the box is read | `primitives`, `adapters` |
| `grading` | `census`, `status`, `metrics`, `hostmon` | the fold from readings to one health word | the first four |
| `frame` | `dispatch`, `confirm`, `lifecycle` | the request frame and the lifecycle table | `primitives` |
| `secretstore` | `secretstore` | secrets, by key id | `primitives` |

## Primitives

`fact` is the fact protocol: every observed value carries whether it was answered, when, and why not, so no aggregator can score an unanswered fact as healthy. `journal` is a durable log of CRC-framed records, its torn tail truncated on recovery, and `events` is the append-only event stream, ordered by one sequence number. `statetable` holds a state-by-operation table as data and renders it in the grammar of a TLA+ table literal, so the lifecycle's Go table can be compared with its model byte for byte. `conform` answers whether one declared service's intent is honoured now: health is conformance to declared intent, not uptime.

## Declarations

`fleet` holds the declared service set and the observed container states; the plan, the stop planner and the fold all read it. `ingress` derives the edge from what the apps declare. `chores` holds the bounded fact a periodic job prints and the strict parse of that output.

## Adapters

The adapters are how the probes and the deployment act on the box, a Synology NAS running DSM 7. The module is named `adapters` rather than `platform`; `platform` and `platform/dsmexec` are its DSM packages. `rtnl` performs the five link, address and route operations the macvlan shim needs, and `dockerclient` is a standard-library Docker client over the unix socket, with its HTTP fake, `enginefake`, beside it. At its tag the module imports no other commons module.

## Probes

The probes read the box and change nothing. `hostfacts` reads the host; `fsprobe` asks metadata questions about the declared file plane, never its content; `kmsg` reads new kernel log lines; `volmarker` finds managed roots by a marker file, never by a remembered path; `edgeprobe` checks the edge's reachability. `deadman` runs one outbound HTTPS ping loop, gated on the one health verdict the grading computes.

## Grading

`census` answers what is on the box and needs no state store, no Docker and no resolvable home, so it survives the failures it diagnoses. `status` assembles one document at one timestamp, each fact carrying its answered triple, plus a `blind[]` list of what could not be answered. `hostmon` holds the host invariants as pure functions over a census report, and `metrics` renders the verdicts as Prometheus text. A grade computed here is computed nowhere else.

## Frame

`dispatch` is the API dispatcher's generic core: the dispatch table and the capability judge, `capAllows`. The TLS gate, the listener and the handshake stay in the daemon. `confirm` holds the type-to-confirm tokens a destructive call must carry, each verified and spent before the handler runs.

### The lifecycle table and its admission

The box is always in exactly one of seven places: `shutting-down`, `unfit`, `booting`, `drained`, `draining`, `in-service` or `down`, chosen by one precedence. Up to six marks stand beside it: `owner` (a reboot or shutdown procedure), `release`, `service`, `slot` (the job holding the mutating slot), `episode` (the power conductor on battery) and `restoring`. Sixteen operations name every transition, from a hand drain to the boot.

Two tables decide them (`frame/lifecycle/lifecycletable.go`): Table A, operations by places, 112 cells, and Table B, operations by marks, 96 cells. Each cell holds one of six words:

| word | fires | meaning |
|---|---|---|
| `admit` | yes | the operation runs |
| `adopt` | yes | it joins what stands instead of standing a second |
| `hold` | yes | it runs; the standing procedure's next wait names the drain |
| `own` | owner only | only the standing procedure's own step runs |
| `refuse` | no | the recovery moves the place or clears the mark |
| `none` | no | no method serves it there |

`Admit` is the one evaluator (`frame/lifecycle/lifecycle.go`):

1. Read the place cell; a word that does not fire decides.
2. Read each standing mark the operation reads, in a fixed order; the first cell that does not fire decides, and the verdict names that mark.
3. Otherwise the operation fires, as `adopt` if any cell said so, else as `admit`.

A coordinate outside the tables answers a word that does not fire: what the table does not carry is unknown, and unknown is never a pass. In service, a hand device drain admits and moves the box to `draining`; while draining, a second device drain adopts the first, and a hand apply refuses. The daemon's doors and the deployment service read this one table.

## Secretstore

`secretstore` keeps secrets, keyed by key id, in one sealed document, `secrets.json`, in the daemon's state area. Its key and witness live in the system tree the install's root step owns, so key and ciphertext sit on two volumes and neither yields a value alone. Every read and write goes through `fileproof`'s descriptor proof, and any defect refuses the whole file.

## The walls

The order is a test, not a convention. In the root module's `layout_test.go`, `TestModulesFormNoCycle` refuses a cycle among the modules' requires, a module missing from the order table, and a sibling required without its local `replace`. `TestWallsHoldTheOrder` checks that each module requires no sibling outside its row, and that every package, tests included, imports only the standard library, its own module, a module below it and `api/`. It parses every `.go` file whatever its build constraint, so a Linux-only file is walled on any machine.

`make check` runs `toolchain render fmt vet stdlib dashes hygiene test` over the root and the seven; `stdlib` refuses any module outside `github.com/syrvis/`, and no gate reaches the network. A release train tags every module at one version, bottom up: `v0.1.0`, then `v0.1.1`.

## Provability

Two TLA+ models describe commons code:

- `frame/lifecycle/Lifecycle.tla` (1,088 lines) models one box's place, resolved from six world conditions, and its six marks, with nineteen operation steps guarded by the 208-cell table and twelve world moves, such as the boot ladder, rescue and the battery episode.
- `EventBus.tla`, kept in the daemon's `specs/`, models two producers fanning events out to one full subscriber, and the overflow signal closing once. It describes `primitives/events`.

No other commons module has a TLA+ model; Go tests cover the rest. `Lifecycle.tla` lives here as the source of record, but TLC checks it only in the daemon's repository, where `make verify-spec` reads the vendored copy over the proof case and four broken twins. The proof case covers 1,242 distinct states to depth 15 in under 1.5 seconds. The commons' own gate runs no TLC, and the deployment service vendors the same bytes but assumes the admission instead of checking it.

| property | what it says | twin |
|---|---|---|
| `Quiescence` | no new deploy work fires while the box is draining, drained, shutting down or off | yes |
| `OneDeviceToken` | the box is in exactly one place, even when several conditions hold | yes |
| `OwnerExclusive` | at most one reboot or shutdown procedure stands at a time | yes |
| `OwnerStepDeclares` | a standing reboot, in service, can always declare its own drain | yes |
| `ExclusionHeld` | while a procedure stands or the box is on battery, no new deploy work starts | no |
| `DrainOwnerHeld` | while a procedure stands, an operator cannot release the box's drain | no |
| `HandDeclareOwnerHeld` | while a reboot stands, an operator cannot declare a device drain by hand | no |
| `EmergencyEnabled` | the UPS emergency stop can start unless the box is off | no |

The bus model checks `NoDoubleClose` and `MutualExclusion` over 12 distinct states. The scenarios, in plain words, are under [Scenarios: Commons](../provability/scenarios.md#commons).

The proofs are kept truthful three ways:

- `TestTheGoTablesEqualTheSpecificationsLiteral` compares the rendered Go tables byte for byte, on every `go test`, with the literal between the model's marker lines. Each side was typed separately from the design record, so a cell edited on one side fails the other.
- Four properties have a broken twin that must reach its violation on every fair run: an apply admitted while draining, the precedence removed, a second reboot admitted, the reboot's own drain step refused. The other four rest on hand-run mutation sweeps, or none.
- `primitives/events/model_test.go` explores the bus in Go, and its teeth test shows an unlocked fan-out can close the signal twice. No test ties the model's evaluator to Go's `Admit`: the byte test holds the cells, not their reading.

### What the October 2026 review found

The lifecycle model is sound with gaps: the table is the model's guard, it equals the Go table byte for byte, the invariants that read it are true and mostly non-vacuous, and each twin reaches its violation. Of thirteen findings, one sits at the second-lowest of four severity levels and twelve at the lowest; none shows a code bug the model misses. The bus model is stale, with one finding at the second-lowest level.

The top finding: `DrainOwnerHeld` proves a refusal the product does not make. Releasing a reboot's drain by hand abandons the reboot first, so the guarantee that matters, no reboot left standing over a released drain, is checked nowhere.

| kind | finding |
|---|---|
| gap | The source of record is checked only downstream, when the daemon takes a new tag (second-lowest level). |
| gap | The model lacks three drain releases the code performs: the boot ladder's, a reboot's restore step, the power conductor's. |
| gap | `Quiescence` is scoped by place, so deploy work at `booting` or `unfit` under a drain meets no property. |
| gap | Four table rules have no property, such as an apply during a device restore. |
| gap | Four properties have no twin, and `EmergencyEnabled` is safety labelled as liveness. |
| gap | The evaluator exists twice, in the model and in `Admit`, held equal only by review. |
| gap | `EmergencyEnabled` proves the stop is admitted, not that its drain lands when writes are blocked. |
| gap | The model makes each operation one atomic step without saying so; the code checks twice. |
| excess | `OneDeviceToken` checks the model's own definition, which cannot fail. |
| excess | Seven of nineteen operation steps reach no new state. |
| excess | Nothing keeps the daemon's spec path a link, and the deployment model cites this one by line. |
| excess | The module's header, counts and paths name homes the code has left. |
| excess | `EventBus.tla` models moved code and repeats the Go explorer, nothing holding the two equal (second-lowest level). |

The findings are being filed as fixups in the commons' and the daemon's lists of work, each where its part lives. The method behind these proofs is on [Provability](../provability/index.md).
