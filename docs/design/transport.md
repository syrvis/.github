---
title: Transport
parent: Design
nav_order: 4
---

# Transport

`syrvis-mtls` is the mutual-TLS transport the daemon and its clients share. A client trusts exactly one key, the daemon's, named by its pin: the hex SHA-256 of the leaf certificate's SubjectPublicKeyInfo. There is no certificate authority, no hostname check and no trust on first use, and each refusal names the layer it came from, so the client can print the step that clears it. The library is the Go standard library only, holds no state, and ships as `v0.1.0`, which the daemon and the client each pin and vendor.

This page reads `syrvis-mtls` at commit `41eb00b`, the daemon at `1069e15b` and the client at `e616a46`.

## What the library holds

| package | what it decides |
|---|---|
| `pin` | the pin's one derivation, the trust decision, the daemon's named certificate, the two protocol names, the TLS 1.3 floor |
| `seat` | a roster row and its grades, the paste-line grammar, the ceiling on one grant, a credential's life |
| `dial` | the one pinned dial, the reading of the daemon's bare close, the reach probe, a gate's address |
| `vector` | fixed test seeds and their pins, for tests on both sides |
| `mtls`, the root | `Refusal` (a layer, a kind and the facts) and `Recovery`, through which each host gives its own words |

The library states facts and judges them. Each host keeps the roster store, the key's custody, the sweep, the alarms and every word of recovery. No verdict in the library reads a clock: a host reads its own once per verdict and passes the instant in.

## The pin

`pin.Of` is the only derivation: the lowercase hex of SHA-256 over the leaf's DER SubjectPublicKeyInfo, 64 characters (`pin/pin.go`). It hashes the key, not the certificate, so a certificate signed again over the same key keeps its pin. The box prints the daemon's pin at its root step, a context records it, and the roster stores each client's.

The trust decision, `pin.Verify`, runs inside the TLS handshake through `VerifyPeerCertificate`, before the handshake completes (`pin/verify.go`). Stock certificate verification is off, because the pin asks a stricter question in its place: is this exactly the key the context recorded? A mismatch refuses with the facts. Its line opens `SERVER KEY MISMATCH`, gives the first 16 hex characters of the key the daemon presented and of the key the context pins, names the two causes (the daemon rotated its key, or something is answering in its place), and ends `refusing to speak`.

The daemon's certificate has one fixed form (`pin/named.go`): one DNS name, `syrvisd.invalid`, serial 2, valid from 2026-01-01 to 9999-12-31 UTC, signed with Ed25519, and nothing else. An Ed25519 signature has no random part, so the certificate is a function of the key alone. The `.invalid` top-level domain is reserved and resolves nowhere, so the name reaches no box. A verifier that needs a name, such as a reverse proxy in front of a gate, takes the block `syrvis context certificate` prints as its only root, sets that name as its server name, and dials by address.

The wire bound is four things: the protocol names (`srpc/1` for the API door, `http/1.1` for a gate), the TLS 1.3 floor, the pin's derivation and the named form. They change only with a new protocol name, so any two library tags under one name interoperate.

## Seats and their life

A seat is one roster row: a name, the client's pin, a grade, an expiry, a source address (`from`), a label and the enrolment instant (`seat/row.go`). Every field is required. An omitted `from` read as any address would silently drop the source check, so an absent field refuses the whole file.

The client mints its key on its own machine, and the private half never leaves it. `syrvis api enroll-request` prints one paste-line in this grammar (`seat/parse.go`):

```text
name=<label>,spki=<64 hex>,from=<ip-literal|cidr>[,grade=read-only|operator][,expires=<rfc3339>]
```

Grades rank `read-only`, `operator` and `admin`. No paste-line can spell `admin`: only the attended door at the box grants it. The grade `full` is refused at parse, since the ceiling grade exists only locally. The edge proxy's and a worker's rows carry labels with a space, which no paste-line can spell.

A credential's life has four terms, each stated once as a constant and returned together by `seat.Default()`:

| term | length | what it bounds |
|---|---|---|
| default term | 180 days | a grant whose line names no `expires` |
| ceiling | 365 days | the furthest one grant may reach |
| life | 730 days after enrolment | the end that no renewal passes |
| tail | 30 days | read-only admission past the end, for a row granted up to it |

A row renews any number of times inside its life; a row that lapsed before its end earns no tail. Nothing new is stored: the end is computed from `enrolled_at`, cut to the whole second. The life refuses to renew a row whose instants do not parse, because unknown is never a pass. The daemon publishes the four terms on `Meta.Methods`, a daemon test holds them equal to `seat.Default()`, and the daemon opens a renewal chore 21 days before a row expires.

Revocation is by name: the daemon tombstones the row, and a revoked key never comes back as a live row. Planned: when a second daemon holds a seat, the client revokes it by name at each daemon, complete only when every declared daemon answered that it took.

## The dial ladder and its refusals

`dial.Dial` is the module's only dial, and `TestOnlyDialGoDials` fails if any other file names a dial primitive. A host hands its RPC client a dialer from `DialerFor`, so no host writes a dial of its own. Every refusal is a `*mtls.Refusal` carrying its layer and kind. `Refusal.Recovery()` is never empty: when the host bound no words, it says so instead of reading as advice.

Under TLS 1.3 the client's side of the handshake finishes before the daemon judges the client's key. So the daemon's refusal arrives as a bare close at the first read, and `dial.FirstRead` names it the client-auth layer's refusal. The wire cannot say why; the box's events can.

The client's `syrvis context test <name>` walks the layers in order and stops at the first failure:

| layer | what refuses | kinds | the client's recovery |
|---|---|---|---|
| context | no pin recorded; the key files do not load | `unpinned`, `identity_unusable` | the `syrvis context pin` line; `syrvis api enroll-request` again |
| tcp | a filtered port times out; a closed one resets | `timeout`, `unreachable` | check the address, the network path and the daemon's bound port |
| tls | no certificate, an unparseable one, another key, or a port that answers and is not the daemon | `no_certificate`, `unparseable_certificate`, `server_key_mismatch`, `port_taken` | re-pin from the fingerprint the box printed, or find out what answers in the daemon's place |
| client-auth | a bare close: unenrolled, expired, revoked, or from an address the row does not pin | `refused` | enroll, renew or fix the source address, then test again |
| instance | the box answering is not the one the context pinned | checked by the client | re-pin deliberately: the box was rebuilt, or the context aims at another |
| seat | a paste-line that breaks the grammar or asks past the ceiling | 23 grammar kinds, `over_ceiling` | the refusal states the rule it broke; the host adds its fix |

## The door, planned

Today each daemon holds its own door: the listener, the handshake and the accept verdict over its roster. Planned: when a second daemon serves the API, the door's handshake and verdicts (the row verdict, the source check, the expiry test and the accept judge over a host's store) move into this library, so every daemon judges a key by one computation.

## Provability

No TLA+ model covers this library, and none is planned for it. Its proof is Go: 29 test functions in 7 files, run under the race detector by `GOWORK=off make check`, every key minted at test time from fixed seeds, no key file in git.

| evidence | what it holds |
|---|---|
| `TestTheLadder` | one row per refusal across the layers, the TCP rows in `dial/dial_test.go`; it fails on an empty or unbound recovery and on any `Kind` constant without a row |
| `TestTheLifeUnderASteppedClock` | one row through enrolment, its end, its tail and its close |
| the structural tests | `TestNoInitAndNoPackageVar`, `TestOnlyDialGoDials` and `TestModuleIsPinnedAndStandardLibraryOnly`: stateless, one dial, no dependency |
| the clock scans | `TestSeatReadsNoClock` and `TestIsNamedReadsNoClock` parse the source for clock reads, and each must catch a planted bad body |
| mutation runs | each test row added after the first release went red on every named one-line mutant of its code before it merged, seven mutants of `pin/named.go` among them |
| the seam vector | the daemon's `TestTransportSeamVector` checks seven items over a real listener, the four life terms equal to `seat.Default()` among them |

**Would a model pay?** Not here. Each function maps inputs to a verdict, with no state and no interleaving, so a table of cases covers it and a model would restate the table. The state that pays for a model sits in the daemon: the roster, the accept, the per-call re-judge, the 30-second sweep and revocation. The daemon's `SeamCred` model covers that credential plane, fed by this library's pin and row type; see the [daemon's provability section](daemon.md#provability). Planned with the door's move: no model of its own, `SeamCred` kept whole in each daemon with its accept naming the library's judge, and a replay of the model's accept traces through that judge.

**Scenarios.** The credential scenarios `SeamCred` checks, in plain words, are under [Daemon on the scenarios page](../provability/scenarios.md#daemon).

**Keeping it honest.** `SeamCred` has five broken twins, each a copy with one guard removed or one bad action added, and each must fail, so no property is green because nothing could break it. No trace test ties `SeamCred` to the Go yet; its properties have named Go twins that dial the real listener. The library's tests keep the same rule in Go: the ladder fails on an untested kind, and a scan that sees nothing does not pass.

**What the October 2026 review found.** The library has no model of its own, so the findings here are `SeamCred`'s, rated sound with gaps:

| finding | what it says |
|---|---|
| proven well | no call runs outside the grade stamped on its connection, and no destructive call runs over the network; each broken twin fails as it should |
| gap | deleting the per-call re-judge leaves every property green, where a real bug once lived: a seat re-pinned narrower kept serving until the next sweep, since fixed |
| gap | the boot merge never runs in the checked states, so "a revoked key never returns" holds there because nothing tries |
| gap | the no-forged-grade property holds by construction: only the broken twin's added action sets its flag |
| gap | the 30-second bound on a quiet stream-holder is checked for revocation only, not demotion or expiry |
| excess | the model treats the sweep as instant, stronger than the code, which serves a quiet holder up to 30 seconds after its row stops backing it |

The gaps are being filed as fixups in the daemon's list of work. The library's own open test gaps are already filed in its own: the life's refusal is checked only to the whole day, so a 12-hour mutant passes, and the clock scan misses an aliased import.

Back to [Provability](../provability/index.md).
