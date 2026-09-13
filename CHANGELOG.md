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
  v1.2.0 -- M5-001 dual-signed release-source landing.
             Release scaffolding only; no source change from v1.1.0.
  v1.2.1 -- Hotfix: TCP server (r14 == 1) inherited pdxsock_pump_loop's
             leading sys_read(fd=0), freezing the server post-accept on
             its own stdin (pdxsock#20).
  v1.2.2 -- Hotfix: --dry-run fabricated a runnable-looking preview
             for the two STUB UDP modes even though the real-run body
             for both exits 3 -- both dry-run classifier arms now
             route to pdxsock_dry_udp_refuse (fd-1 UNIMPLEMENTED
             preview + sys_exit(3)) (pdxsock#18).
-->


## [Unreleased]

### Added
- **Server-refuses-second-connection smoke witness (pdxsock#11,
  M4-003).** Adds `tests/m4_003_server_refuses_second.pdx` (module
  `M4003ServerRefusesSecond`) as a three-role ELF driven by
  `argv[1]` first byte: `s` = server (bind 5555 + `sys_listen(fd,1)`
  + `sys_accept` once + drain one byte + `sys_shutdown(2)` +
  `sys_exit(0)`), `1` = client1 (connect + send one byte 'A' +
  shutdown + exit 0 -- the connection the server accepts), `2` =
  client2 (connect MUST fail after the server has closed the sole
  accepted socket; on the expected `sys_connect < 0` refusal, emits
  `pdxsock refuse ok\n` on fd 2 and `sys_exit(0)`; on unexpected
  success, emits `pdxsock refuse FAIL\n` on fd 2 and `sys_exit(1)`).
  Gates the single-slot-backlog contract of the pdxsock v1.1-A'
  server body (per `sys_listen.pdx`'s backlog cap of 1). Fixture-
  harness pattern matches `tests/tcp_echo_smoke.pdx`: pdxsock has
  no in-tree fork/spawn scaffolding, and `tools/build.sh` emits
  `build-out/tests-m4_003_server_refuses_second.o` only. Runtime
  round-trip witness awaits the paideia-os smoke-runner extension
  that sequences server / client1 / client2. Exit codes: 0 =
  success (any role), 1 = client2 unexpected accept, 2 = usage
  refusal, 5 = setup syscall failure.

- **Large-transfer smoke witness (pdxsock#12, M4-004).** Adds
  `tests/m4_004_large_transfer.pdx` (module `M4004LargeTransfer`)
  as a dual-role ELF (mirrors `tests/tcp_echo_smoke.pdx`) that
  streams 128 KiB (131072 bytes, well past the >64 KiB task-charter
  minimum and past the 64 KiB TCP window default) through the same
  server body pattern, then byte-compares payload vs. received
  buffer. Payload is `.bss @align(8) 131072` filled at start of the
  client role with the deterministic per-byte pattern
  `payload[i] = (i & 0xFF)` -- a length off-by-one anywhere in the
  send/recv chain surfaces as a mismatch at that exact index and
  an all-zero recv buffer cannot false-positive. Fingerprint band
  on fd 2: `pdxsock large ok bytes=131072\n` (30 wire bytes) on
  match, `pdxsock large FAIL\n` (19 wire bytes) on mismatch,
  shared `pdxsock large setup fail\n` (25 wire bytes) on any
  setup-syscall failure. Send/recv loops honestly re-issue on
  partial completion (`add rsi, r14/r12; mov rdx, 131072; sub rdx,
  r14/r12`) so a fragmented delivery at any chunk boundary in the
  128 KiB stream progresses correctly. Exit codes: 0 = success,
  1 = mismatch, 2 = usage refusal, 5 = setup failure.

- **TCP echo round-trip smoke witness (pdxsock#9, M4-001).** Adds
  `tests/tcp_echo_smoke.pdx` (module `TcpEchoSmoke`, single
  `_start` `pub let` entry point) as a dual-role ELF that, driven
  by `argv[1]` first byte, is either the echo server (`server`:
  `sys_socket` + `sys_bind(5555)` + `sys_listen(1)` + `sys_accept`,
  then a recv-loop-until-32-bytes into `tes_recv_buf` followed by
  a send-loop-until-32-bytes back to the peer, then `sys_shutdown`
  + `sys_exit(0)`) or the round-trip client (`client`:
  `sys_socket` + `sys_connect(0x7F000001, 5555)`, then a send-
  loop-until-32-bytes from `tes_payload` and a recv-loop-until-32-
  bytes into `tes_recv_buf`, then a 32-byte inline byte-compare,
  then the fingerprint emit and `sys_shutdown` + `sys_exit`).

  Fixed 32-byte payload:
  `"abcdefghijklmnopqrstuvwxyz012345"` -- deterministic printable
  ASCII so a mismatch is hex-dump readable and no accidental
  all-zero false-positive can match a `.bss`-fresh `tes_recv_buf`
  (26 letters + 6 digits guarantees a byte in every position).

  Fingerprint on match (client mode, fd 2):
  `pdxsock tcp-echo ok bytes=32\n` (29 wire bytes). On mismatch:
  `pdxsock tcp-echo FAIL\n` (22 wire bytes). On any setup-syscall
  failure (either mode): the shared `pdxsock tcp-echo setup fail\n`
  (28 wire bytes) diagnostic on fd 2 followed by `sys_exit(5)`.
  Exit-code taxonomy is intentionally coarser than main.pdx's
  (`0`=success / `1`=echo mismatch / `2`=usage refusal /
  `5`=any setup syscall failure) -- the smoke is pass/fail, not
  diagnostic; a future landing may split `5` into main.pdx's
  4/5/6/7 (socket / connect / bind / listen / accept) codes once
  the harness cares about them.

  Fixture-harness approach: pdxsock has no in-tree fork/spawn
  scaffolding to bring up a server process from within a smoke
  ELF (no `sys_fork` / `sys_execve` on the user surface, and
  `tools/build.sh` under the `tests/*.pdx` glob emits `.o`
  objects only -- not linked executables). Furthermore, pdxsock
  main.pdx's `pdxsock_server_body` + shared `pdxsock_pump_loop`
  is a stdin<->socket / socket<->stdout relay, NOT a
  socket<->socket echo -- pumping received socket bytes back to
  the same socket needs stdout piped into stdin, which no shell
  can do natively. So this witness follows the task-charter
  alternate scaffold: a SINGLE dual-role ELF, argv-picked, that
  compiles today and awaits the paideia-os monorepo smoke wiring
  to sequence the two invocations (start server, wait for the
  accept-blocking spin-up, launch client, diff the client's fd-2
  fingerprint against the golden). The paideia-os smoke-runner
  extension that runs this pair is filed as a follow-up (M4-001
  runtime harness landing).

  Runnability today: the witness COMPILES today under
  `bash tools/build.sh` (which extends the source-glob build over
  `tests/*.pdx` and emits `build-out/tests-tcp_echo_smoke.o`),
  gating the encoder-discipline patterns paideia-as 0.36+
  requires (per user memory `pdx encoder pitfalls`: no
  `test rN, rN`, no 2-op `imul r, imm`, byte loads via
  `xor rN, rN; mov_b rN, [ptr]`, PascalCase basename, `tes_`
  label prefix for reserved-word discipline, SysV alignment).
  Runtime round-trip proof-of-life awaits the paideia-os harness
  landing above; no `manifest.pdxproj` `tests:` list edit at
  this landing (the `.o`-only compile is unchanged from the
  build-script convention `tools/build.sh` already established).

  Added `.rodata` message constants: `tes_payload` (32-byte
  fixed pattern), `tes_msg_usage` (21 bytes), `tes_msg_ok` (29
  bytes), `tes_msg_fail` (22 bytes), `tes_msg_setup` (28 bytes)
  each with a sibling `_len` u64 constant carrying the wire byte
  count. One `.bss` slot: `tes_recv_buf : [u8; 32] @align(8)`.

  Closes #9.

- **`libpdx-audit` integration wire STUB (pdxsock#7, M3-002).** Adds
  `src/audit_wire.pdx` (module `AuditWire`, two `pub let` entry
  points: `pdxsock_audit_session_start(peer_ip, peer_port, mode)`
  and `pdxsock_audit_session_close(bytes_in, bytes_out,
  duration_ns)`) as the callable audit-journal surface for every
  completed pdxsock session. Both entry points ship at STUB status
  (`xor rax, rax; ret` body, returns `AUDIT_OK = 0`) because the
  `paideia-os/libpdx-audit` satellite is not yet in pdxsock's
  `manifest.pdxproj` `deps:` list. Declared effect / capability set
  (`!{mem, sysreg} @{cap, sched}`) matches the future real-body
  requirement (`AuditClient::audit_begin` /
  `audit_record_output` / `audit_commit`) so the swap-to-real
  landing (`pdxsock.M3-002-b`) needs only body-byte changes, not a
  `pub-let` signature edit or a main.pdx call-site edit.

  Two STUB event-kind constants land alongside:
  `PSAW_EVENT_SESSION_START = 200` and `PSAW_EVENT_SESSION_CLOSE =
  201` (chose 200/201 to sit clear of libpdx-audit's own tool-
  lifecycle codes `UEJ_KIND_TOOL_INVOKE = 130`,
  `UEJ_KIND_TOOL_OUTPUT = 132`, `UEJ_KIND_TOOL_EXIT = 133`);
  documentation-only at STUB level. `PSAW_AUDIT_RECORD_LEN = 256`
  documents the byte count the future real body will marshal into
  (matching libpdx-audit's `PdxAuditRecord@0.2` 256-byte fixed
  record). The audit-journal record is DISTINCT from the existing
  48-byte `SockSessionRecord@0.1` -- they travel to distinct
  consumers (audit-journal IPC endpoint vs. semantic-pipe ring +
  fd 3) with distinct schemas. `SockSessionRecord@0.1` at
  `sys_semantic_send` and `sys_write(3, ..)` is NOT displaced by
  this integration; the bytes-in/out counters live once in
  `_start`'s r12/r13 and land in both records via distinct marshal
  blocks.

  `main.pdx` gains three call sites -- post-connect (client-mode
  `SESSION_START` with peer_ip = rbp / peer_port = rbx / mode = 0),
  post-accept (server-mode `SESSION_START` with peer_ip = 0 /
  peer_port = 0 / mode = 1), and pre-close at the head of
  `pdxsock_emit_session_and_exit` (`SESSION_CLOSE` with
  bytes_in = r12 / bytes_out = r13 / duration_ns from the
  freshly-computed rax). Each site follows the SysV alignment
  discipline (`sub rsp, 8` before `call`, `add rsp, 8` after) --
  the first cross-module `call` encoding this codebase exercises
  from within `_start`, retiring the file-header note that flagged
  it as future-work. A new `.bss` slot
  `pdxsock_session_duration_ns : u64 = 0` carries duration across
  the pre-close call (SysV callers must budget for `rax` clobber).

  Follow-up work in `pdxsock.M3-002-b`: add libpdx-audit to
  `manifest.pdxproj` `deps:`, extend `caps.decl` with
  `KIND_IPC_ENDPOINT(write, svc.audit-journal) via svc_lookup`,
  and replace the two `xor rax, rax; ret` STUB bodies in
  `src/audit_wire.pdx` with real `audit_begin` /
  `audit_record_output` / `audit_commit` sequences. No `main.pdx`
  edits will be needed for the swap.

  Closes #7.

### Changed
- **`SockSessionRecord@0.1` re-lay to the R100 §13.6 generic-tool
  contract (pdxsock#8, M3-003).** Retires the v1.1-B 40-byte layout
  (`bytes_in | bytes_out | peer|port|mode packed | session_start_ns
  | session_end_ns`) in favour of a 48-byte layout that leads with
  a self-identifying `PDXKSOCK` magic (8 ASCII bytes, little-endian
  `u64 0x4B434F534B584450`) + `version:u32 = 1` + `flags:u32 = 0`
  header; a consumer that finds a record starting with this magic
  parses the pdxsock shape without an out-of-band schema-tag
  lookup. Body fields: `bytes_in:u64`, `bytes_out:u64`, then a
  packed `peer_ip:u32 | peer_port:u16 | reserved:u16` (mode field
  DROPPED -- server-mode is still distinguishable by `peer_ip == 0`
  as in v1.1-B), then a single `duration_ns:u64` computed as
  `(session_end_ns - session_start_ns)` at emit time. The two v1.1-B
  raw-TSC snapshot fields collapse into this one duration field --
  consumers wanting raw timestamps can no longer recover them from
  the record alone, but duration is the only field any current
  consumer needs. `duration_ns` remains raw TSC ticks (not
  nanoseconds) until user-facing `sys_clock_now` lands; the
  schema-shape name is preserved so the re-land is field-
  preserving. `sys_semantic_send` (SC+ ID 115) ring-emission path
  is unchanged in shape -- only the `record_len` bumps from 40 to
  48 to match the new layout; schema tag (`0x536F636B53657301`)
  survives the re-lay because the tag names the record family, not
  the byte layout.

  Closes #8.

- **Opt-in fd-3 semantic-pipe emission (pdxsock#8, M3-003).**
  Alongside the ring-emission path above, the close tail now
  `sys_write`s the same 48 bytes to file descriptor 3. `pdxsock`
  NEVER opens fd 3 itself; a parent (shell, launcher, smoke
  harness) pre-wires fd 3 to a pipe / socket / regular file
  before execve (Unix `3>&pipe` shell convention). Absence of
  fd 3 is the expected default -- `sys_write` returns `-EBADF`
  and the emit block silently discards (no fd-2 diagnostic; the
  record was already sent to the ring, and pipe absence is not a
  session-completion condition the tool can act on). The write
  is unconditional and un-gated (no `sys_fstat`-first probe --
  that would add a second syscall to every clean-close for a
  rarely-wired feature; the kernel-side fd-table `-EBADF` path
  is O(1)). No argv flag or env parse added -- the v1.1 argv
  grammar is preserved. `caps.decl` is unchanged: `sys_write` on
  a pre-wired fd requires no additional cap slot beyond the
  parent-passed handle.

- **TCP server: bind+listen+accept + shared bidirectional pump
  (pdxsock#5, M2-002).** Retires v1.1-A's recv-only server tail
  (`sys_recv` -> `sys_write` -> break) with the shared
  bidirectional pump the client body gained at v1.1-A'. Setup
  sequence: `sys_socket` -> `sys_bind(fd, port)` (INADDR_ANY
  implicit; the kernel bind ABI is `(fd, local_port)` and the
  local IP is stamped from the interface's `_ipv4_my_ip` on the
  KIND_TCP_SOCKET arm -- the tool documents "INADDR_ANY" and the
  single-interface kernel is what materially delivers it) ->
  `sys_listen(fd, backlog=1)` (single-connection-at-a-time is the
  M2-002 scope, and 1 also matches the kernel's MVP one-slot
  backlog per `sys_listen.pdx` header -- the pre-M2-002 stub value
  of 8 overstated the accept queue) -> `sys_accept(fd)` (blocking
  per R94.M4-001 waiter table). On accept success the server jumps
  directly into `pdxsock_pump_loop` with r15 = accepted fd, r12/
  r13 zeroed, r14 = 1 (mode), rbp = 0 (no peer_ip threaded through
  sys_accept at MVP). Pump exits into `pdxsock_client_close` whose
  prefix write is now mode-picked (r14 branch picks the "tcp-
  client" or "tcp-server" prefix; both are exactly 28 wire bytes
  so the shared `mov rdx, 28; syscall` needs no branch on length).
  Server-mode `bytes_out` is now potentially nonzero -- retires
  the v1.1-B "server always 0" `SockSessionRecord@0.1` note.
  Concurrent-client fan-out is EXPLICITLY out of scope at M2-002:
  a process-per-connection or event-loop design is not warranted
  before M4 smoke traffic drives the requirement, and the kernel's
  single-slot backlog is the honest cap.

  Closes #5.

### Added
- **TCP server fingerprint band (pdxsock#5, M2-002).** Three
  grep-searchable status lines on fd 2 (stderr, NOT stdout --
  stdout is reserved for socket payload just as in the client
  path) that frame every TCP server run:

  1. `pdxsock tcp-server listening ok port=<P>\n` -- emitted
     immediately after `sys_listen` returns success and BEFORE
     `sys_accept` blocks. Confirms the bind + listen wire landed
     and names the port a smoke or shell caller should connect
     to. `<P>` is the parsed u16 port in decimal (1..5 digits;
     no zero pad).
  2. `pdxsock tcp-server accept ok fd=<N>\n` -- emitted
     immediately after `sys_accept` returns success and BEFORE
     the pump enters. Confirms a client actually connected and
     names the resulting connection fd. `<N>` is the accepted-
     fd small integer in decimal.
  3. `pdxsock tcp-server bytes-in=<N> bytes-out=<M>\n` --
     emitted at pump-loop exit (either side EOFs or errors),
     prefix-picked by mode inside the shared
     `pdxsock_client_close` tail. Wire format matches the
     client's byte-accounting fingerprint exactly (mid,
     scratches, digit encoder all reused verbatim).

  Added `.rodata` message constants:
  `pdxsock_msg_srv_listen_pre` (37 wire bytes),
  `pdxsock_msg_srv_accept_pre` (32 wire bytes),
  `pdxsock_msg_close_prefix_srv` (28 wire bytes -- same length
  as `pdxsock_msg_close_prefix` for a shared write count).
  Reuses `pdxsock_msg_newline` for terminal `\n` and
  `pdxsock_dec_scratch_in` for both decimal encodings (each
  emit completes before the next overwrite; safe reuse).

  New labels under `_start`: `pdxsock_srv_port_dec_loop`,
  `pdxsock_srv_port_dec_emit`, `pdxsock_srv_port_dec_done`,
  `pdxsock_srv_fd_dec_loop`, `pdxsock_srv_fd_dec_emit`,
  `pdxsock_srv_fd_dec_done`, `pdxsock_srv_close_prefix_write`.
  The old `pdxsock_server_recv_loop` label is retired (its
  recv+write shape is subsumed by the shared pump loop). All
  new labels carry the `pdxsock_srv_` prefix per reserved-label
  discipline.

- **TCP client: real bidirectional pump + close-fingerprint band
  (pdxsock#4, M2-001).** Retires v1.1-A's HTTP-style client shape
  (one 4 KiB `sys_read(0, …)`, one `sys_send`, then a
  `sys_recv`-to-stdout loop) with a real stdin->socket /
  socket->stdout blocking-alternation pump.

  Loop shape (one iteration):
  1. `sys_read(fd=0, buf, 4096)` -- rax > 0 sends that many bytes
     to the socket; rax == 0 (stdin EOF) drops into a socket-only
     drain tail; rax < 0 (stdin error) exits clean via the emit
     block.
  2. `sys_send(fd=sock, buf, n)` -- rax >= 0 increments `bytes_out`;
     rax < 0 exits via the emit block.
  3. `sys_recv(fd=sock, buf, 4096)` -- rax > 0 writes to stdout
     and increments `bytes_in`; rax <= 0 (socket EOF or error)
     exits via the emit block.
  4. Loop.

  When stdin closes first (`pdxsock host port </dev/null`, or a
  finished pipeline producer), the loop switches to
  `pdxsock_pump_stdin_drain` which reads the socket to
  peer-EOF and forwards to stdout without ever touching stdin
  again -- half-closed connections are honestly drained rather
  than silently truncated.

  Design choice: blocking-alternation over `sys_poll`
  (SC+ ID 102, R95.M3-001). `sys_poll`'s TCP RX wake wire is
  DEFERRED per the R95 retrospective; a blocking poll on a TCP fd
  would not resume when packets arrive, and non-blocking poll
  (timeout_ms=0) degenerates to a spin loop with no
  sched_yield surfaced. The task shape at M2-001 explicitly
  permits blocking-alternation; the honest scope is
  "request-response-shaped" TCP (each stdin blob prompts a
  socket response before the next stdin read), which matches
  every M4-001 echo-smoke witness planned at this milestone.
  True full-duplex re-lands once TCP RX wake or a non-blocking
  `sys_read` on stdin exists.

### Added
- **TCP client fingerprint band (pdxsock#4, M2-001).** Two
  grep-searchable status lines on fd 2 (stderr, NOT stdout --
  stdout is reserved for socket payload) that frame every TCP
  client run:

  1. `pdxsock tcp-client connect ok\n` -- emitted immediately
     after `sys_connect` returns success and BEFORE the pump
     loop enters. Lets a smoke or shell caller observe the
     completed TCP handshake without waiting for the pump
     loop's first EOF (an interactive netcat-shaped run blocked
     on stdin still surfaces the connect-ok line).
  2. `pdxsock tcp-client bytes-in=<N> bytes-out=<M>\n` --
     emitted right after the pump loop exits and BEFORE the
     v1.1-B `SockSessionRecord@0.1` semantic-pipe emit. Wire-
     visible counterpart of the semantic-pipe record's
     `bytes_in` / `bytes_out` fields; decimal digits composed
     by an inline divide-by-10 loop (verbatim
     `xor rdx, rdx; div rcx` shape from `src/user/init.pdx`
     `print_u64_dec` / `src/user/ps.pdx` `print_u64_dec`,
     R17-M2-736 D12) against two 20-byte `.bss` scratches
     (`pdxsock_dec_scratch_in` / `pdxsock_dec_scratch_out`;
     u64::MAX = 20 decimal digits so the stashes never overrun).

  Both fingerprints are client-only; the TCP server body
  continues to jump straight to
  `pdxsock_emit_session_and_exit` (the shared semantic-pipe
  emit + `sys_shutdown` + `sys_exit(0)` tail) without an
  equivalent `pdxsock tcp-server ...` line -- the server-side
  close-fingerprint band lands with M2-002 follow-up work if
  the R100 plan §13.6 calls for it.

  Added `.rodata` message constants: `pdxsock_msg_connect_ok`
  (30 bytes on the wire), `pdxsock_msg_close_prefix`
  (28 bytes: `"pdxsock tcp-client bytes-in="`),
  `pdxsock_msg_close_mid` (11 bytes: `" bytes-out="`).
  Reuses `pdxsock_msg_newline` for the terminal `\n`.

  Added `.bss` scratches: `pdxsock_dec_scratch_in`,
  `pdxsock_dec_scratch_out` (both `[u8; 20] @align(8)`).

  New labels under `_start`: `pdxsock_pump_loop`,
  `pdxsock_pump_stdin_drain`, `pdxsock_client_close`,
  `pdxsock_dec_in_loop`, `pdxsock_dec_in_emit`,
  `pdxsock_dec_in_done`, `pdxsock_dec_out_loop`,
  `pdxsock_dec_out_emit`, `pdxsock_dec_out_done`. The old
  `pdxsock_client_recv_loop` label is retired (its recv+write
  shape is subsumed by the pump loop's step 2 + the drain
  tail).

  Closes #4.

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

## [1.2.2] - 2026-09-12

Hotfix release. Retires the M1-003 `--dry-run` misbehaviour that
fabricated a runnable-looking preview for the two STUB UDP modes
(`udp-client`, `udp-server`) even though the real-run body for both
exits 3 with a `pdxsock: udp stub` diagnostic. No new features; no
source file added or removed; no ABI or record-shape change. Manifest
`version` bumps `1.2.1 -> 1.2.2`, tag `v1.2.2` cut at this landing;
release-source substrate unchanged (unsigned patch bump on the v1.2.0
dual-signed source base, same shape as v1.2.1).

### Fixed
- **`--dry-run` no longer previews a stubbed UDP mode as if it were
  runnable (pdxsock#18).** Root cause: `pdxsock_dry_argc4_u` and
  `pdxsock_dry_argc4_l` in `src/main.pdx` both landed on
  `pdxsock_dry_print` -- the friendly-preview writer that emits
  `pdxsock dry-run mode=<M> target=<H>:<P>\n` on fd 1 and
  `sys_exit(0)`. The corresponding real-run paths (`pdxsock_argv4_u`
  and `pdxsock_argv4_l`) both jump to `pdxsock_udp_stub` which emits
  `pdxsock: udp stub\n` on fd 2 and `sys_exit(3)`. An operator
  scripting off dry-run output therefore had no way to distinguish
  a live mode from a stub -- `--dry-run` promised a working
  invocation the real tool would refuse.

  Fix (in `src/main.pdx`): both dry-run UDP classifier arms now
  jump to a new label `pdxsock_dry_udp_refuse` which composes the
  honest refusal preview
  `pdxsock dry-run mode=udp-<x> UNIMPLEMENTED\n`
  on fd 1 (three-write chain: prefix / mode name / suffix) and
  calls `sys_exit(3)`. The `pdxsock dry-run mode=` prefix is
  preserved verbatim so existing grep anchors watching dry-run
  output keep matching, and the trailing `UNIMPLEMENTED` sentinel
  is a machine-parseable pattern a caller can gate on when it
  wants to detect a stubbed mode explicitly. Exit code 3 matches
  `pdxsock_udp_stub`'s exit exactly so a `--dry-run` invocation
  fails the same way a real invocation would, and target info
  (host, port) is intentionally withheld from the refusal line
  (an UNIMPLEMENTED mode has no real target to preview; printing
  one would recreate the fabrication issue #18 flags).

  New literal at file scope:
  `pdxsock_msg_dry_udp_stub : [u8; 16] = " UNIMPLEMENTED\n\0"`
  (`_len : u64 = 15` for the wire byte count). Every other dry-run
  literal (`pdxsock_msg_dry_prefix`, `pdxsock_msg_mode_udp_client`,
  `pdxsock_msg_mode_udp_server`) is reused verbatim -- the refusal
  path shares the mode-name family with the friendly-preview
  writer, so the two paths render mode names byte-for-byte
  identically.

  Semantics after fix:
  * `pdxsock --dry-run <host> <port>` (tcp-client): unchanged.
  * `pdxsock --dry-run -l <port>` (tcp-server): unchanged.
  * `pdxsock --dry-run -u <host> <port>` (udp-client): now emits
    `pdxsock dry-run mode=udp-client UNIMPLEMENTED\n` on fd 1
    and exits 3 (previously: emitted the friendly preview line
    and exited 0).
  * `pdxsock --dry-run -l -u <port>` (udp-server): now emits
    `pdxsock dry-run mode=udp-server UNIMPLEMENTED\n` on fd 1
    and exits 3 (previously: emitted the friendly preview line
    and exited 0).

  Follow-up work (out of scope at pdxsock#18):
  * **When UDP client lands** (pdxsock#6, blocked on
    `R100-PREP-002` per issue-map), the `pdxsock_dry_argc4_u`
    classifier arm re-points from `pdxsock_dry_udp_refuse` back
    to `pdxsock_dry_print` (the runnable-preview writer). The
    refusal label and its `pdxsock_msg_dry_udp_stub` literal
    remain in place until the last stubbed mode is retired; when
    they are, both are deleted in a single follow-on commit.
  * **`pdxsock_dry_argc4_l` (udp-server) has no lifecycle path**
    -- per `design/networking/r100-user-tools-plan.md` §7.2 the
    UDP-server shape is out of scope for v1 (needs `recvfrom`
    peer-address out-params the caller-side ABI does not thread
    through libpdx-net yet, and a different tool shape than the
    single-connection-at-a-time pdxsock family). So this arm
    stays on `pdxsock_dry_udp_refuse` indefinitely.

  Mirror-of-real-run pattern: the fix follows mount.pdxfs#26's
  dry-run gate-hoist discipline -- the dry-run bit check runs
  BEFORE any mode-specific classify decides whether the tool
  should actually perform the operation, and every dry-run
  terminal path lands on a shape that matches its real-run
  counterpart's exit behaviour (same exit code, same fd for
  diagnostics, same "would/would-not run" honesty).

### Changed
- **`manifest.pdxproj` `version`** bumps `1.2.1 -> 1.2.2`; a note
  in the file-header release-history block records the pdxsock#18
  hotfix scope so a `git blame` of the version line surfaces
  the change reason.
- **`src/main.pdx` file header** grows a v1.2.2 stanza inside the
  `--dry-run` deferred-features block explaining the new
  refusal-path semantics for STUB modes.

### Verification (paideia-os smoke, once M4-001 sequencer lands)
- `pdxsock --dry-run -u 127.0.0.1 5555; echo $?` -- expect
  `pdxsock dry-run mode=udp-client UNIMPLEMENTED\n` on fd 1
  and exit code 3.
- `pdxsock --dry-run -l -u 5555; echo $?` -- expect
  `pdxsock dry-run mode=udp-server UNIMPLEMENTED\n` on fd 1
  and exit code 3.
- `pdxsock --dry-run 127.0.0.1 5555; echo $?` -- expect
  `pdxsock dry-run mode=tcp-client target=127.0.0.1:5555\n` on
  fd 1 and exit code 0 (unchanged pre-existing behaviour).
- `pdxsock --dry-run -l 5555; echo $?` -- expect
  `pdxsock dry-run mode=tcp-server target=0.0.0.0:5555\n` on
  fd 1 and exit code 0 (unchanged pre-existing behaviour).

Closes pdxsock#18.

## [1.2.1] - 2026-09-12

Hotfix release. Retires the M2-002 conflation of client-mode and
server-mode pump entry that let `sys_read(fd=0)` fire before the
server ever touched the accepted socket. No new features; no source
file added or removed; no ABI or record-shape change. Manifest
`version` bumps `1.2.0 -> 1.2.1`, tag `v1.2.1` cut at this landing.

### Fixed
- **TCP server (`-l <port>`) no longer blocks post-accept on its own
  stdin (pdxsock#20).** Root cause: `pdxsock_pump_loop` in
  `src/main.pdx` opened with an unconditional `sys_read(fd=0, buf,
  4096)` (Step 1 of the M2-001 bidirectional pump). The M2-002
  server body (`pdxsock_server_body`) jumps into that pump directly
  after `sys_accept` returns, so the pump's first instruction post-
  accept was a stdin read against the server task's OWN fd 0 --
  which blocks indefinitely unless the caller pipes bytes in. A
  smoke driver that connects a client and expects the server to
  observe the socket without also feeding the server's stdin
  therefore hangs; the accepted-fd fingerprint (`pdxsock tcp-server
  accept ok fd=<N>\n`) emits but no `sys_recv` follows.

  Fix (in-place at `pdxsock_pump_loop`): a Step-0 mode gate --
  `cmp r14, 1; je pdxsock_pump_recv;` -- that branches server-mode
  entries around the stdin-read + `sys_send` arm and lands directly
  on the `sys_recv` step. A new label `pdxsock_pump_recv` marks that
  entry point; the client path falls through to it as before (Step-1
  `sys_read(0)` and `sys_send(fd, n)` execute unchanged), and the
  loop tail (`jmp pdxsock_pump_loop`) is unchanged so both modes
  re-enter the mode gate on every iteration. Cost per iteration: one
  `cmp` + one conditional jump, both predicted-taken from a stable
  callee-save register.

  Semantics after fix:
  * Client mode (`r14 == 0`): bit-for-bit unchanged.
    `stdin -> sys_send -> sys_recv -> sys_write(1) -> loop`,
    identical to the v1.1-A' M2-001 shape.
  * Server mode (`r14 == 1`): recv-only pump.
    `sys_recv(fd) -> sys_write(1) -> loop`; the accepted socket
    drives the tool, and the server task's own stdin is never
    touched. Bytes-in accumulator (`r12`) is still populated; the
    close-tail fingerprint (`pdxsock tcp-server bytes-in=<N>
    bytes-out=<M>\n`) now honestly reports `bytes-out=0` in the
    common recv-only case (server mode still exits into the shared
    `pdxsock_client_close`, which does the mode-picked prefix write
    per the M2-002 landing).

  Follow-up work (out of scope at #20):
  * **True bidirectional server pump** (stdin -> socket AS WELL AS
    socket -> stdout) re-lands when either (a) `sys_poll` (sysno
    102) grows TCP RX wake so the server can select between the
    two fds without spinning, or (b) non-blocking `sys_read` on
    stdin exists so the server can peek stdin without blocking.
    Both are DEFERRED per the file-header note on the client-mode
    blocking-alternation choice; issue #20 acknowledges this in
    the "Fix (design decision needed)" §2/§3 alternatives without
    picking them at this milestone.
  * **Symmetric client-side idle-stdin block** (W39 finding, same
    class): a client that connects to a silent peer and issues
    `sys_read(0)` still blocks on the local stdin, which is honest
    netcat behaviour and NOT a bug -- but the same non-blocking
    stdin surface would let the client fall through when there is
    no stdin data. Filed alongside #20 as a joint retirement
    candidate once the primitives land.

  Witness: `tests/tcp_server_no_stdin_block.pdx` (module
  `TcpServerNoStdinBlock`, single-role ELF; compile-gated at v1.2.1
  same as `tests/tcp_echo_smoke.pdx` -- runtime harness in
  paideia-os smokes lands with the M4-001 sequencer). Body:
  `sys_socket -> sys_bind(port from argv[1]) -> sys_listen(1) ->`
  emit `pdxsock server witness listening ok\n` on fd 2
  `-> sys_accept ->` emit `pdxsock server witness accept ok\n` on
  fd 2 `-> sys_recv(fd, buf, 4096) -> sys_write(1, buf, n) ->`
  emit `pdxsock server witness recv ok bytes=<N>\n` on fd 2
  `-> sys_shutdown(fd, SHUT_RDWR) -> sys_exit(0)`. The witness
  contains **no** `sys_read` opcode anywhere -- a grep
  (`grep -F 'mov rax, 0;' tests/tcp_server_no_stdin_block.pdx`)
  proves the server-side surface is stdin-free by construction.
  Under the paideia-os smoke harness `INJECT_HOLD` budget the
  witness reaches `listening ok\n` immediately (no stdin path) and
  the smoke driver's client connect + one-byte payload send
  reaches `recv ok bytes=1\n` in one round trip; a pre-#20 build
  reached `accept ok\n` and then hung indefinitely on `sys_read(0)`
  inside the shared pump.

  Files touched:
  * `src/main.pdx`: `pdxsock_pump_loop` gains a Step-0 mode-gate
    comment block and a `cmp r14, 1; je pdxsock_pump_recv;` pair
    at the top; the Step-2 sys_recv arm splits off as a new
    `pdxsock_pump_recv:` label (unchanged bytes, new entry point).
    Line delta: +21 comment lines / +2 code lines / +1 label /
    -0 removed. `main.pdx` line count grows by ~28 lines; no
    other function or `.bss` slot moves.
  * `tests/tcp_server_no_stdin_block.pdx`: new file (module
    `TcpServerNoStdinBlock`, ~110 wire lines including the file
    header + one `_start` `pub let` block). Compiles under
    `bash tools/build.sh` to `build-out/tests-tcp_server_no_stdin_
    block.o` and gates only the encoder-discipline patterns.
  * `manifest.pdxproj`: `version` bumps `1.2.0 -> 1.2.1`; no
    `sources:` / `deps:` / `tests:` list edit (tests/ is globbed
    at build time).
  * `CHANGELOG.md`: this stanza.
  * `STATUS.md`: M2-002 checklist entry gains a `pdxsock#20`
    hotfix note.

  Closes #20.

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
