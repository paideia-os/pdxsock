# Changelog

All notable changes to `pdxsock` are recorded here. Format: keep-a-
changelog-style, semver-ordered, newest first.

<!--
Version discipline:
  v1.0.x -- reserved for the original M5 dual-signed 1.0-shape plan
             (superseded by v1.1.0 -- see the [1.1.0] stanza below).
             No v1.0.0 tag was ever cut.
  v1.1.0 -- unsigned source-tag release (2026-09-08). Real socket
             bodies + semantic-pipe emit wire.
  v1.2.0 -- M5-001 dual-signed release-source landing (this stanza).
             Release scaffolding only; no source change from v1.1.0.
-->


## [Unreleased]

### Added
- **`--dry-run` first-runnable (pdxsock#3, M1-003).** When passed
  as the leading `argv[1]`, `--dry-run` classifies the mode +
  target that the tool WOULD use and prints a single-line preview
  on fd 1, then `sys_exit(0)` -- no socket is opened, no
  `SockSessionRecord@0.1` is emitted, and the 4 KiB `pdxsock_buf`
  scratch page is left at its .bss zero state (the "we did not
  run" claim is observable at the memory level).

  Wire format of the preview line:
  ```
  pdxsock dry-run mode=<M> target=<H>:<P>\n
  ```
  where `<M>` is one of `tcp-client`, `tcp-server`, `udp-client`,
  `udp-server` (each exactly 10 bytes), `<H>` is either the argv
  host string (client modes) or the literal `0.0.0.0` (server
  modes -- honest INADDR_ANY placeholder for the port pdxsock
  would bind), and `<P>` is the raw argv port string (dry-run
  intentionally does not re-parse the port -- re-parsing adds a
  failure surface the real run would already exhibit; the point
  is a shape preview, not a validation pass).

  Argv grammar accepted at M1-003 (leading-position `--dry-run`
  only; a positional-flexibility landing that accepts the flag
  mixed in with `-l`/`-u` at any argv index is deferred, and may
  be subsumed by the M1-002 argv scanner move -- pdxsock#2):
  ```
  pdxsock --dry-run <host> <port>       -> tcp-client
  pdxsock --dry-run -l <port>           -> tcp-server
  pdxsock --dry-run -u <host> <port>    -> udp-client
  pdxsock --dry-run -l -u <port>        -> udp-server
  ```
  Any other shape (missing args, unknown flag combinations, a
  bare positional third argv) falls through to the existing
  `pdxsock_usage` path (exit 2), matching the real-run classifier
  refusal shape byte-for-byte.

  Implementation is inline label code under `_start`
  (`pdxsock_dry_run_entry`, `pdxsock_dry_argc3`, `pdxsock_dry_
  argc4`, `pdxsock_dry_argc4_u`, `pdxsock_dry_argc4_l`,
  `pdxsock_dry_tcp_client`, `pdxsock_dry_print`, `pdxsock_dry_
  write_mode`, `pdxsock_dry_host_strlen`, `pdxsock_dry_host_
  write`, `pdxsock_dry_host_any`, `pdxsock_dry_after_host`,
  `pdxsock_dry_port_strlen`, `pdxsock_dry_port_write`) mirroring
  the existing socket-side classifier tree; no new `pub let`
  function is introduced (the file remains single-function
  under `Main`). Preview line composition uses a 7-sys_write
  chain (prefix / mode / target-kw / host-or-any / colon / port
  / newline) rather than a compose-into-scratch pass -- avoids
  a `pdxsock_buf` touch and needs no new .bss.

  Mode encoding on `r14` for the dry-run flow: `0=tcp-client`,
  `1=tcp-server`, `2=udp-client`, `3=udp-server`. Distinct from
  the socket-side `r14` usage (which only ever holds 0 or 1) --
  the two encodings never coexist in one invocation because the
  dry-run flow never falls through into a socket body.

  Added `.rodata` message constants: `pdxsock_msg_dry_prefix`
  ("pdxsock dry-run mode="), `pdxsock_msg_mode_tcp_client`,
  `pdxsock_msg_mode_tcp_server`, `pdxsock_msg_mode_udp_client`,
  `pdxsock_msg_mode_udp_server`, `pdxsock_msg_target_kw`
  (" target="), `pdxsock_msg_addr_any` ("0.0.0.0"),
  `pdxsock_msg_colon`, `pdxsock_msg_newline` plus matching `_len`
  siblings. No new .bss.

  Closes pdxsock#3.

### Deferred (documented at M1-003)
- **`--dry-run` in non-leading argv position** (e.g.
  `pdxsock -l --dry-run <port>`). M1-003 accepts the flag only
  at `argv[1]`. Positional-flexibility is either a follow-on
  M1 issue or subsumed by the M1-002 argv scanner move
  (pdxsock#2), whichever lands first.
- **Dry-run round-trip smoke** (fixture that pipes `pdxsock
  --dry-run <shape>` through `bash tools/run-smoke.sh` and diffs
  the preview line against a golden). Held for M4 alongside the
  existing TCP echo / UDP echo / large-transfer smokes
  (pdxsock#7..#10); the file exit path was audited by hand at
  this landing and every branch classifies to a fixed preview
  string with no floating state. No `tests/` subdirectory is
  seeded at this landing -- the `manifest.pdxproj` `tests: []`
  invariant is preserved until M4 lands the full smoke shape.

### Changed
- **`STATUS.md`** -- M1-003 checklist entry flipped from `[ ]`
  to `[x]` with a per-argv-grammar note.

## [1.2.0] - 2026-09-09

M5-001 dual-signed release-source landing. Release-scaffolding-only
minor bump over v1.1.0 -- no source file was added, removed, or
edited between the two tags. The delta is release documentation +
release-manifest source form + `.pdxdoc` source form + the CHANGELOG
+ manifest.pdxproj + STATUS.md metadata bumps every earlier
satellite tool cut at its own first dual-signed release. Closes
pdxsock#13 (M5-001). Blocks pdxsock#14 (M5-002 mirror push) only on
`pkgs.paideia-os` endpoint availability (see
`release/RELEASE-1.2.0.md` §3 S5).

### Added
- **`release/manifest.pdxsig.txt`** -- dual-sign release manifest
  source form, mkfs.pdxfs / umount.pdxfs template shape. Format
  `paideia-manifest-pdxsig@1`, hash discipline BLAKE3-256 (upper
  32 bytes, hex-rendered), signature scheme
  `hybrid-ed25519+ml-dsa-65 (paideia-pq-hybrid-v1)`. Every
  `<BLAKE3-*>` / `<...-KID-*>` / `<...-SIG-*>` slot is a documented
  placeholder the release tool
  (`paideia-release fill-manifest` + `paideia-release sign`)
  recomputes / fills in at tag time; no hash and no signature is
  materialised at this milestone (release-line seed key material
  lives outside every repo per `design/02-development-environment.md`
  §1164 -- hardware-backed TPM 2.0 / cloud KMS custody). Every
  `[artifacts.source]` row enumerates exactly the two files pdxsock
  v1.2.0 ships (`caps.decl` + `src/main.pdx`); `[depends-on]` is
  empty (no cross-repo library link at v1.2.0);
  `[not-linked]` records `libpdx-net` / `libpdx-audit` /
  `libpdx-semantic-pipe` as adjacent-in-plan-only rather than
  hard-dep for the record.
- **`release/RELEASE-1.2.0.md`** -- release note + operator runbook
  for cutting the signed release and pushing it to the
  `https://pkgs.paideia-os/main/pdxsock/1.2.0/` mirror. Sections:
  1 (what v1.2.0 ships), 2 (what v1.2.0 does NOT ship -- itemised
  deferral list with per-issue trace), 3 (substrate readiness S1..S5
  blocking the actual signed release), 4 (cut-a-release procedure --
  pre-flight, tag, build, fill-manifest, dual-sign, mirror push,
  index update, GitHub release), 5 (distribution -- expected mirror
  layout with the `/pkgs/pdxsock-1.2.0/{bin,doc,caps.decl,manifest.
  pdxsig}` + `/bin/pdxsock` symlink shape), 6 (verification --
  consumer-side `pkg install --verify-only`), 7 (what lands at
  M5-001 vs. what does not).
- **`doc/pdxsock.pdxdoc`** -- source-form user-facing documentation,
  `pdxdoc-source v0.1` shape. Sections: NAME, SYNOPSIS, DESCRIPTION,
  OPTIONS (`-l` + `-u`), EXIT-CODES, RECORD (full
  `SockSessionRecord@0.1` layout table + field-shape notes),
  LIMITATIONS (12 items covering UDP stubs, no full-duplex, no DNS,
  no IPv6, no TLS, TSC-tick timestamps, zero server-mode peer_ip,
  no audit_id, no `--dry-run`, no long-form argv, un-closed listen
  fd), SEE ALSO (R100 wave sibling cross-refs). Compiled via `doc
  compile` at doc.M2 (not yet landed); consumers render the source
  form verbatim until then.

### Changed
- **`manifest.pdxproj`** -- `version` bumped `1.1.0 -> 1.2.0`;
  `release.signer_author` changed `unsigned -> paideia-release-line`
  (with the placeholder-until-sign discipline documented in-file);
  `release.mirror_target` changed `(deferred) -> pkgs.paideia-os/
  main/pdxsock/1.2.0/`. The `docs:` list, previously empty at v1.1.0
  with the "M5-001 alongside the dual-signed release manifest" hold,
  now enumerates the new `doc/pdxsock.pdxdoc` source.
- **`STATUS.md`** -- overall-status header flipped from *v1.1.0
  released* to *v1.2.0 release-source landed*; M5-001 checklist
  entry flipped from `[ ]` to `[x]` with per-artifact notes.

### Deferred (documented at v1.2.0)
- **Mirror push to `pkgs.paideia-os/main/pdxsock/1.2.0/`** --
  pdxsock#14 (M5-002). Endpoint does not exist as of this
  milestone; `release/RELEASE-1.2.0.md` §5 documents the layout
  a future operator pushes.
- **Actual dual-sign pass** -- release-line seed keys are
  hardware-backed / KMS-custody per
  `design/02-development-environment.md` §1164 and never
  repo-resident. `release/manifest.pdxsig.txt`'s `[signatures]`
  block carries `SIGNATURE_PLACEHOLDER_PENDING_LIVE_SIGN` in
  every slot the real dual-sign pass would fill.
- **Compiled `.pdxdoc`** -- `doc compile` (doc.M2) is not landed
  in paideia-os yet. Source form at `doc/pdxsock.pdxdoc` is
  renderable verbatim until then.

## [1.1.0] - 2026-09-08

First tagged release. Closes pdxsock#1 (M1-001 scaffold + caps.decl),
pdxsock#15 (v1.1-A: real TCP client + server bodies), pdxsock#16
(v1.1-B: `SockSessionRecord@0.1` semantic-pipe emit wire) and
pdxsock#17 (v1.1-C: this release closer). The signed v1.0-shape
release path originally planned at M5 is superseded by v1.1.0 -- v1.1-A
landed real socket bodies and v1.1-B landed the semantic-pipe emission,
both of which the original 1.0 plan treated as post-1.0 milestones;
the tag jumps to 1.1.0 rather than regressing 1.1-shape code under a
1.0 tag. The dual-signed release-manifest ship path (paideia-os
design/release-manifest.md + design/mirror-push.md) lands at M5-001
(pdxsock#11) as a v1.2.0-signed follow-on rather than a re-sign of
v1.1.0.

### Added
- **v1.1-C (issue #17) -- release closer.** `manifest.pdxproj` at
  version 1.1.0 (single-source `src/main.pdx`, no deps, no tests,
  no docs, unsigned release-policy stanza documenting the v1.2.0
  signed-follow-on plan); CHANGELOG.md `[1.1.0] - 2026-09-08`
  section (this entry) promoting the [Unreleased] v1.1-A + v1.1-B
  entries; STATUS.md v1.1-C landed + overall status "v1.1.0
  released". Release tag `v1.1.0` cut from this commit.

- **v1.1-B (issue #16) -- semantic-pipe emission wire.** Every
  completed TCP connection (both `pdxsock <host> <port>` client and
  `pdxsock -l <port>` server paths) now emits a 40-byte
  `SockSessionRecord@0.1` via `sys_semantic_send` (SC+ ID 115,
  paideia-os handler landed at R107-M0-001 #2350) at recv-loop exit,
  right before `sys_shutdown` + `sys_exit(0)`:
  - `bytes_in`  (u64): sum of successful `sys_recv` returns.
  - `bytes_out` (u64): sum of successful `sys_send` returns
    (always 0 in server mode -- the server body writes stdout only).
  - `peer_ip | port | mode` (packed u64): peer IPv4 in low 32 bits
    (server = 0 -- `sys_accept` does not thread an out-address at
    v1.1-A), peer port in bits 32..47, mode (0=client, 1=server) in
    bits 48..55.
  - `session_start_ns` (u64): rdtsc snapshot post-`sys_connect` /
    post-`sys_accept`. **Raw TSC ticks, not nanoseconds** until
    `sys_clock_now` lands -- schema-shape name preserved for a
    field-additive future re-land.
  - `session_end_ns`   (u64): rdtsc snapshot at recv-loop exit.
  Schema tag: `0x536F636B53657301` (ASCII-mnemonic "SockSes\x01").
  Storage: `pdxsock_record_buf` (40B, `@align(8)`, .bss) +
  `pdxsock_session_start_ns` (u64, .bss). Register plan:
  `r12 = bytes_in`, `r13 = bytes_out`, `rbp = peer_ip` (post-parse
  phase, replacing argv-time roles of `r12`/`r13`). Failure paths
  before the recv loop (socket / connect / bind / listen / accept
  refusals; usage / bad-port / bad-ip) emit **no** record -- there
  is no session to describe. `sys_semantic_send`'s return code is
  discarded at the callsite (marshalling-bug surface, not per-run).

- **v1.1-A (issue #15) -- retire M1-001 STUB body.** `src/main.pdx`
  now wires the real SC+ socket-syscall path over sysnos 87..94
  (socket / bind / listen / accept / connect / send / recv /
  shutdown) plus 0 / 1 / 60 (read / write / exit). Two real
  dispatch paths land:
  - **TCP client** (`pdxsock <host> <port>`): sys_socket ->
    sys_connect -> one 4 KiB sys_read from stdin -> sys_send ->
    sys_recv loop -> sys_write to stdout -> sys_shutdown ->
    sys_exit(0).
  - **TCP server** (`pdxsock -l <port>`): sys_socket -> sys_bind ->
    sys_listen(backlog=8) -> sys_accept -> sys_recv loop ->
    sys_write to stdout -> sys_shutdown -> sys_exit(0).
- Real IPv4 dotted-quad parser (`a.b.c.d`) inlined in `_start`,
  packed into the u32 word order sys_connect expects (bits
  [31:24]=a, [23:16]=b, [15:8]=c, [7:0]=d per
  `src/kernel/core/syscall/handlers/sys_connect.pdx`).
- Real u16 port parser (0..65535 range gate + reject empty +
  reject non-digit) inlined in `_start`.
- `caps.decl` per R90-XREPO.013.M1-001 line-oriented grammar --
  `!KIND_USER 0x001` + `!KIND_TCP_SOCKET 0x00B` (mandatory);
  ` KIND_UDP_SOCKET 0x00B` + ` KIND_IPC_ENDPOINT 0x001`
  (optional, held for M3-001 + v1.1-B respectively).
- `link.ld` + `tools/build.sh` (`paideia-as >= 0.36.0`) matching
  the `tools/user/mkfs.pdxfs/` template. Build output goes to
  `build-out/pdxsock.elf` + `build-out/pdxsock.bin`.
- `STATUS.md` -- honest v1.1-A scope statement + full 18-issue
  milestone-checklist mirror.

### Deferred (documented STUB or refusal at v1.1-A)
- `-u <host> <port>` (UDP client): emits "pdxsock: udp stub" on
  fd 2 and exits 3. Held for pdxsock#6 (M3-001); sysnos 96/97
  (sendto/recvfrom) landed at R93.M2-004 (#2052), so the kernel
  side is unblocked -- the hold is on libpdx-net's wrapper
  surface stabilising, not on the kernel.
- `-l -u <port>` (UDP server): out of scope per
  `design/networking/r100-user-tools-plan.md` §7.2 (needs
  recvfrom peer-address out-params which the caller-side ABI at
  this round does not thread through libpdx-net yet).
- Full-duplex stdin/socket forwarding (real netcat contract):
  needs sysno 102 poll (landed R95.M3-001 #2080) plus a select-
  loop design. Escalated to a follow-on issue rather than crammed
  into #15.
- `--dry-run`: held for pdxsock#3 (M1-003).
- Full `-l` / `-u` / `--dry-run` argv grammar: held for pdxsock#2
  (M1-002); v1.1-A accepts only `pdxsock <host> <port>` and
  `pdxsock -l <port>` plus the two UDP-refusal shapes.
