# pdxsock -- status

**Wave:** R100 (user-space networking tools -- paideia-os
`design/networking/r100-user-tools-plan.md` §7).
**Current milestone:** v1.1-B (semantic-pipe emission wire:
SockSessionRecord@0.1 via sys_semantic_send SC+ ID 115) -- **landed**.
Previous: v1.1-A (real-body extraction; real socket-syscall path) --
landed.
**Version:** 0.1.0-dev (pre-tag; a signed 1.0.0 release closes at M5).

See `design/networking/r100-user-tools-plan.md` §13.6 in the
[paideia-os](https://github.com/paideia-os/paideia-os) repo for the
18-issue breakdown this checklist mirrors.

## Milestone checklist

### M1 -- scaffold + argv

- [x] **M1-001** -- scaffold + `caps.decl` (`KIND_USER` +
      `KIND_TCP_SOCKET` mandatory; `KIND_UDP_SOCKET` +
      `KIND_IPC_ENDPOINT` optional). v1.1-A retires the STUB body:
      `src/main.pdx` now wires SC+ IDs 87..94 (socket/bind/listen/
      accept/connect/send/recv/shutdown) plus 0/1/60 (read/write/
      exit) into two real dispatch paths (TCP client, TCP server).
      Two additional argv paths (`-u <host> <port>` and `-l -u
      <port>`) emit a documented "udp stub" diagnostic and exit 3;
      these are held for pdxsock#6 (M3-001) and are honestly out of
      scope per `design/networking/r100-user-tools-plan.md` §7.2 for
      UDP-server respectively.
- [ ] **M1-002** -- argv surface polish: `-l`, `-u`, `<host> <port>`
      | `<port>` full grammar (option combinator + long-form
      `--dry-run`). v1.1-A accepts only the minimal grammar above;
      the argv scanner is inlined in `_start` at this landing and
      moves to `src/argv.pdx` at M1-002.
- [ ] **M1-003** -- first runnable: `--dry-run` prints the mode +
      target it would use.

### M2 -- TCP client + server real bodies

- [~] **M2-001** -- TCP client: connect + stdin-to-socket + socket-
      to-stdout loop. **Partially met** by v1.1-A: connect + one-
      shot stdin sys_read + sys_send + recv-to-stdout loop +
      shutdown + exit all wired. Full-duplex bidirectional forward-
      ing (netcat's real contract, requires sysno 102 poll) held for
      a follow-on v1.1-A' issue rather than crammed into #15.
- [~] **M2-002** -- TCP server: bind+listen+accept, single-
      connection-at-a-time. **Met** by v1.1-A: bind + listen (back-
      log 8) + accept (blocking) + recv-to-stdout loop + shutdown +
      exit. The listen fd is not explicitly sys_closed before exit
      -- `sys_exit(0)` reaps the whole task and releases every cap
      slot, so the un-closed listen fd is not a leak (matches every
      other _start in the paideia-os src/user/ tree).

### M3 -- UDP + audit + semantic-pipe

- [ ] **M3-001** -- UDP client: connected-UDP mode. Held for after
      libpdx-net stabilises the sendto/recvfrom shim surface;
      sysnos 96/97 landed at R93.M2-004 (#2052) so the kernel side
      is unblocked.
- [ ] **M3-002** -- libpdx-audit integration.
- [~] **M3-003** -- semantic-pipe: `SockSessionRecord@0.1` (bytes-
      in/out, peer, duration). **Partially met** by **v1.1-B**
      (pdxsock#16): every completed TCP connection (client and
      server) now emits a 40-byte `SockSessionRecord@0.1` via
      `sys_semantic_send` (SC+ ID 115, paideia-os handler landed at
      R107-M0-001 #2350) at recv-loop exit, carrying `bytes_in`,
      `bytes_out`, packed `peer_ip|port|mode`, and TSC-tick
      `session_start_ns` / `session_end_ns` snapshots (raw rdtsc
      samples; the schema-shape name is `_ns` but the semantics are
      cycle counts until user-facing `sys_clock_now` lands). Schema
      tag `0x536F636B53657301` ("SockSes" + ver01), preserved
      verbatim once paideia-os#2000 (schema registry) lands. What
      remains for full M3-003: (i) ns-accurate timestamps (blocked
      on `sys_clock_now`); (ii) libpdx-audit `audit_id` field
      (blocked on M3-002); (iii) sys_accept out-address (blocked on
      a future accept ABI extension) so server-mode records carry a
      real peer_ip instead of the current honest zero.

### M4 -- smokes

- [ ] **M4-001** -- TCP echo round-trip smoke (client against a
      `pdxsock -l` fixture).
- [ ] **M4-002** -- UDP echo round-trip smoke (once M3-001 lands).
- [ ] **M4-003** -- server-refuses-second-connection behaviour
      smoke + documentation.
- [ ] **M4-004** -- large-transfer smoke (buffer-boundary correctness,
      >64 KiB stream).

### M5 -- release

- [ ] **M5-001** -- dual-signed `manifest.pdxsig` + `CHANGELOG-1.0` +
      `.pdxdoc`.
- [ ] **M5-002** -- mirror push.

## v1.1-A honest-scope statement

v1.1-A retires the M1-001 STUB body over TCP alone. Two features
that a full netcat has that pdxsock at this landing DOES NOT:

1. **Full-duplex forwarding.** Netcat interleaves stdin->socket and
   socket->stdout via `select`/`poll`. pdxsock v1.1-A does one 4 KiB
   stdin sys_read, one sys_send, then loops recv->stdout until EOF.
   This is honest as an "HTTP request" client (send request, read
   response, close) but is not the netcat contract. The full-duplex
   variant needs sysno 102 poll (landed R95.M3-001 #2080) plus a
   select-loop design; escalated to a follow-on issue.
2. **UDP paths.** The `-u` client is a documented STUB; the `-lu`
   server is out of scope per R100 plan §7.2. Both surface a single
   "udp stub" diagnostic + exit 3 at v1.1-A. UDP client re-lands at
   M3-001 once libpdx-net's sendto/recvfrom wrappers stabilise.

Every other honest-scope constraint in R100 plan §11 (fail-closed
elevate, semantic-pipe schema fallback, libpdx-audit forgiveness-
posture) applies here verbatim; those are not v1.1-A concerns.

## v1.1-B honest-scope statement

v1.1-B adds `SockSessionRecord@0.1` emission via `sys_semantic_send`
(SC+ ID 115) at every completed TCP connection. The record shape
(40 bytes, schema tag `0x536F636B53657301`) is stable and matches
the wire-record intent of R100 plan §7.3, but three fields carry
placeholder or degraded semantics at v1.1-B:

1. **`session_start_ns` / `session_end_ns` are raw TSC ticks, not
   nanoseconds.** There is no user-facing `sys_clock_now` yet; the
   schema-shape name is preserved so a re-land is field-additive
   rather than field-renaming. Consumers can compute a per-run
   monotonic duration = `end - start` in TSC ticks; converting to
   wall-time ns needs a per-host TSC frequency the kernel does not
   publish. Same "monotonic-lookalike (rdtsc sample)" precedent as
   `src/kernel/core/fs/pdxfs_lite/write.pdx` (R25-M2-005 #919).
2. **Server-mode `peer_ip` and `peer_port` are always zero.**
   `sys_accept` at v1.1-A does not thread an out-address (there is
   no `accept4` / `getpeername` shape in the kernel yet). The
   record encodes this honestly (mode == 1 + peer_ip == 0 is the
   documented "server-mode, peer address not observed" state
   rather than a presence flag).
3. **No `audit_id` field.** M3-002 (libpdx-audit integration) has
   not landed; the audit trail record is not yet threaded through
   the semantic-pipe record. Field will be added at M3-002 close.

The `sys_semantic_send` return value (0 / `-EFAULT` / `-EINVAL`)
is intentionally discarded at the callsite: the connection is
already over, and any failure at this layer is a marshalling bug
in `src/main.pdx` (the 40-byte record is well within the [1, 240]
byte cap and `pdxsock_record_buf` is a static rip-relative address
that never fails `user_ptr_ok`) rather than a per-run condition
the caller can act on. The sysno-115 handler's overwrite-oldest
ring policy means a downstream backup does not surface as
`PIPE_FULL` at v1 either -- an older record is silently displaced,
which the R107-M0-001 landing calls out explicitly.
