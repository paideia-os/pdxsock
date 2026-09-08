# Changelog

All notable changes to `pdxsock` are recorded here. Format: keep-a-
changelog-style, semver-ordered, newest first.

## [Unreleased]

### Added
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
