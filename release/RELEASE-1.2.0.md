# pdxsock v1.2.0 -- release note + mirror-push workflow (M5-001)

**Repo:** github.com/paideia-os/pdxsock
**Wave:** R100 user-space networking tools
(`design/networking/r100-user-tools-plan.md` §7 + §13.6, in the
paideia-os monorepo).
**Version at this release:** 1.2.0 (dual-signed follow-on to the
unsigned v1.1.0 source tag, 2026-09-08).
**Upstream policy:** `design/tooling/plan.md` §6.3 (paideia-os) --
package repository layout; `design/02-development-environment.md`
§1140 + §1164 -- hybrid Ed25519 + ML-DSA-65 signing, release-line
key custody; `design/networking/r100-user-tools-plan.md` §13.6 --
pdxsock M5-001 scope (dual-signed manifest + `.pdxdoc` + CHANGELOG
close).

This document is both the **release note** for what v1.2.0 ships and
the operator runbook for cutting the signed release and pushing it to
the paideia-os package mirror at
`https://pkgs.paideia-os/main/pdxsock/1.2.0/`. The workflow mirrors
`mkfs.pdxfs`'s and `umount.pdxfs`'s own `release/RELEASE-1.*.md`
runbooks (this org's earlier satellite tools first through M5) --
see either for the worked template this one follows.

The actual `git tag v1.2.0` + `git push` is a **manual step main
performs separately from this milestone** -- see §6. This document
describes exactly what that tag would contain so a future operator
can cut it without re-deriving scope from STATUS.md and five
milestones of design-doc flags.

---

## 1. What v1.2.0 ships

v1.2.0 is a **release-scaffolding-only** minor bump over v1.1.0. No
source file was added, removed, or edited between the two tags. The
delta is:

- **`release/manifest.pdxsig.txt`** (this repo, new) -- dual-sign
  source form, mkfs.pdxfs-template shape. Every `<BLAKE3-*>` /
  `<...-KID-*>` / `<...-SIG-*>` slot is a documented placeholder the
  release tool fills in at tag time (see §3).
- **`release/RELEASE-1.2.0.md`** (this repo, new) -- this document.
- **`doc/pdxsock.pdxdoc`** (this repo, new) -- source-form user
  documentation, `pdxdoc-source v0.1` shape. Compiled into
  `doc/pdxsock.pdxdoc` at `doc` M2 (not landed as of this
  milestone; source form is renderable verbatim until then).
- **`CHANGELOG.md`** -- new `[1.2.0]` stanza documenting M5-001,
  demoting the `[1.1.0]` release-policy plaintext ("v1.2.0-signed
  follow-on lands at M5-001") from *plan* to *history*.
- **`manifest.pdxproj`** -- `version` bump `1.1.0 -> 1.2.0`,
  `release.signer_author` set to `paideia-release-line` (with the
  placeholder-until-sign discipline documented in-file),
  `release.mirror_target` set to
  `pkgs.paideia-os/main/pdxsock/1.2.0/`.
- **`STATUS.md`** -- M5-001 flipped to landed, overall-status header
  bumped from *v1.1.0 released* to *v1.2.0 release-source landed*.

What v1.2.0 does NOT change: `src/main.pdx`, `caps.decl`, `link.ld`,
`tools/build.sh`, `LICENSE`, `README.md`. Every syscall path (sysnos
0/1/60/87..94/115) is byte-for-byte the v1.1.0 body. The compiled
`build-out/pdxsock.elf` a v1.2.0 tree produces is bit-identical to
the v1.1.0 one -- the release-tool's manifest recomputation over the
v1.2.0 tag will observe the SAME BLAKE3 hashes for `src/main.pdx` +
`caps.decl` + `link.ld` + `tools/build.sh` as an
otherwise-hypothetical v1.1.0-signed manifest would have.

## 2. What v1.2.0 explicitly does NOT ship (deferred)

Consumers relying on this tool at v1.2.0 must know these gaps are
real and by design, not oversights. Every gap traces to an open
`pdxsock` milestone (M1-002/M1-003/M3-*/M4-*, see `STATUS.md`) or
to a substrate that is not yet reachable in the paideia-os kernel:

- **Argv surface polish (`-l`, `-u`, `<host> <port>` | `<port>` full
  grammar + long-form `--dry-run`)** -- pdxsock#2 (M1-002). v1.2.0
  accepts only the minimal grammar `pdxsock <host> <port>` and
  `pdxsock -l <port>`, plus the two documented UDP-refusal shapes.
- **`--dry-run` mode preview** -- pdxsock#3 (M1-003). Not wired at
  this release.
- **Full-duplex TCP forwarding** (real netcat contract via
  `sys_poll`, sysno 102 landed R95.M3-001 #2080) -- escalated to a
  post-M2 follow-on issue rather than crammed into v1.1-A. v1.2.0's
  client body does one 4 KiB `sys_read` from stdin, one `sys_send`,
  then loops `sys_recv -> sys_write(stdout)` until EOF; the server
  body is receive-only.
- **UDP client (`-u <host> <port>`)** -- pdxsock#6 (M3-001).
  Documented STUB at v1.2.0: emits `pdxsock: udp stub` on fd 2 and
  exits 3. Kernel side is unblocked (sysnos 96/97 landed at
  R93.M2-004 #2052); the hold is on `libpdx-net`'s wrapper surface
  stabilising.
- **UDP server (`-lu <port>`)** -- explicitly out of scope per
  `design/networking/r100-user-tools-plan.md` §7.2 (needs
  `recvfrom`-with-peer-address-out-params ABI which the caller-side
  wrappers do not thread through libpdx-net yet).
- **`libpdx-audit` integration** -- pdxsock#8 (M3-002). The
  `audit_id` field additive-lands into `SockSessionRecord@0.1` at
  that milestone; v1.2.0's record carries no audit trail.
- **`SockSessionRecord@0.1` timestamp semantics** --
  `session_start_ns` / `session_end_ns` are **raw TSC ticks**, not
  nanoseconds; user-facing `sys_clock_now` has not landed and the
  kernel does not publish a per-host TSC frequency. Schema-shape
  name is preserved so a re-land is field-additive rather than
  field-renaming. Same "monotonic-lookalike (rdtsc sample)"
  precedent as `src/kernel/core/fs/pdxfs_lite/write.pdx`
  (R25-M2-005 #919).
- **`SockSessionRecord@0.1` server-mode peer_ip / peer_port** --
  always 0 at v1.2.0. `sys_accept` does not thread an out-address
  (there is no `accept4` / `getpeername` shape in the kernel yet);
  the record encodes this honestly (mode == 1 + peer_ip == 0 is
  the documented "server-mode, peer address not observed" state).
- **QEMU-substrate smokes** -- pdxsock#7..#10 (M4-001..M4-004). No
  `tests/` directory ships at v1.2.0; the tool is exercised
  end-to-end at paideia-os smoke time via the `/bin` seeding
  pipeline (paideia-os issues #1976/#1977).
- **Dual-signed `manifest.pdxsig` binary** -- see §3/§4 below; this
  milestone (M5-001) lands the *source form* of the manifest but
  does not execute the sign pass.
- **Mirror push to `pkgs.paideia-os/main/pdxsock/1.2.0/`** --
  pdxsock#14 (M5-002). Endpoint does not exist as of this
  milestone; §5 below documents the layout a future operator
  pushes.

## 3. Substrate readiness (blocking the actual signed release)

**S1 -- paideia-as toolchain >= 0.36.0 reachable.** The build path
(`tools/build.sh`) already asserts this floor and refuses fast on
any older toolchain. `paideia-as build src/main.pdx --emit elf64`
produces the same `.o` on every 0.36.x point release; no v0.36.x
change touches the sysno-87..94 / sysno-115 emit paths pdxsock
depends on.

**S2 -- `paideia-pq-sign::sign_release_artifact` reachable.** The
release-time dual-sign entrypoint (`crates/paideia-pq-sign/src/
release.rs` in the paideia-os toolchain tree, per
`design/paideia-as/v0.20-issue-1025-pq-signing.md`) is what
`paideia-release sign` invokes twice per manifest. Reachable in
every toolchain checkout that has the pq-sign crate compiled;
the release runner must have both `libpaideia_pq_sign.rlib` and
its two secret-key inputs (S3 below) on hand.

**S3 -- live release-line seed keys.** Two seed keys, both
release-line custody (hardware-backed TPM 2.0 / cloud KMS per
`design/02-development-environment.md` §1164), never repo-resident:
one Ed25519 seed (32 bytes), one ML-DSA-65 seed (32 bytes). The
`[signatures]` block of `release/manifest.pdxsig.txt` carries the
`SIGNATURE_PLACEHOLDER_PENDING_LIVE_SIGN` sentinel in every slot
precisely because that key material is out-of-repo. Same discipline
`src/format.pdx`'s `mkfs_sign_seed_zero` placeholder documents one
tool over.

**S4 -- `doc` M2 reachable.** The compiled `.pdxdoc` at
`/pkgs/pdxsock-1.2.0/doc/pdxsock.pdxdoc` is produced by the
`doc compile` subcommand of the `doc` tool at doc.M2 (not landed as
of this milestone). The source form at `doc/pdxsock.pdxdoc` in this
repo is the input; consumers render it verbatim until then.

**S5 -- `pkgs.paideia-os` mirror endpoint reachable.** Same mirror,
same non-existent-as-of-R100-close status every earlier satellite's
own runbook documents. Until it stands, the release is "cut but not
mirrored" -- the signed `manifest.pdxsig` still lands in the GitHub
release attachment set for out-of-band consumers.

---

## 4. Cut-a-release procedure

Identical shape to `mkfs.pdxfs`'s and `umount.pdxfs`'s own runbooks
(same tooling, same release-line key custody). Reproduced here with
this repo's own artifact names.

**Pre-flight.**

    git fetch origin
    git switch main
    git pull --ff-only
    git status                    # MUST be clean
    gh issue list --milestone M5 --state open --repo paideia-os/pdxsock
                                  # MUST be empty (or #14 M5-002 only)

**Step 1 -- Version bump + CHANGELOG close.** Already done at M5-001
(this milestone) -- `CHANGELOG.md`'s `## 1.2.0` entry is the one a
future tag points at, `manifest.pdxproj`'s `version = 1.2.0` is set.

**Step 2 -- Tag.** (Manual, main-performed -- see §6; NOT run as
part of this milestone.)

    git tag -a v1.2.0 -m "pdxsock v1.2.0 -- R100 M5-001 dual-signed"
    git push origin v1.2.0

**Step 3 -- Build the compiled artifact set.**

    bash tools/build.sh
    # emits build-out/pdxsock.elf + build-out/pdxsock.bin

    doc compile doc/pdxsock.pdxdoc -o build-out/pdxsock.pdxdoc

**Step 4 -- Recompute the manifest.**

    paideia-release fill-manifest \
        --source release/manifest.pdxsig.txt \
        --tree   . \
        --tag    v1.2.0 \
        --output build-out/manifest.pdxsig.filled.txt

**Step 5 -- Dual-sign.**

    paideia-release sign \
        --manifest build-out/manifest.pdxsig.filled.txt \
        --key-ed25519  release-line-ed25519.sk \
        --key-ml-dsa65 release-line-ml-dsa-65.sk \
        --output   build-out/manifest.pdxsig

**Step 6 -- Mirror push.** This is the part pdxsock#14 (M5-002)
scopes; §5 documents the layout, out of scope at THIS milestone.

    paideia-release mirror-push \
        --repo   https://pkgs.paideia-os/main/ \
        --pkg    pdxsock \
        --version 1.2.0 \
        --files  build-out/pdxsock.elf \
                 build-out/pdxsock.pdxdoc \
                 caps.decl \
                 build-out/manifest.pdxsig

**Step 7 -- Update `index.pdxsig`.** Atomic as part of Step 6, per
earlier satellites' runbooks.

**Step 8 -- GitHub release.**

    gh release create v1.2.0 \
        --title "pdxsock v1.2.0" \
        --notes-file CHANGELOG.md \
        build-out/manifest.pdxsig \
        build-out/pdxsock.elf \
        build-out/pdxsock.pdxdoc \
        caps.decl

---

## 5. Distribution -- what would be pushed to `pkgs.paideia-os` (#14)

**Scope note:** this section documents the mirror-push target layout
and contents for a future operator to execute against a real
`pkgs.paideia-os` endpoint (S5 above -- does not exist yet). Per
pdxsock#14's own scope, **no actual push happens as part of THIS
milestone (M5-001), and no `pkgs.paideia-os` artifacts are created
by this landing** -- main handles the real push at M5-002 once
S1..S5 above are green.

Expected mirror layout after a real Step 6 push:

    /pkgs/pdxsock-1.2.0/
        bin/pdxsock                # the linked, runnable ELF (Step 3)
        doc/pdxsock.pdxdoc         # compiled .pdxdoc (Step 3)
        caps.decl                  # this repo's capability declaration
        manifest.pdxsig            # dual-signed binary manifest (Step 5)
    /bin/pdxsock -> /pkgs/pdxsock-1.2.0/bin/pdxsock
                                    # the package tool's own symlink
                                    # convention for a runnable CLI
                                    # package's PATH entry -- shape
                                    # identical to mkfs.pdxfs / mount.
                                    # pdxfs / umount.pdxfs at their own
                                    # M5-002 mirror-push targets.

`[depends-on]` in `manifest.pdxsig.txt` (§ above) is intentionally
empty -- pdxsock at v1.2.0 links no cross-repo library. The
consumer-side `pkg install pdxsock` tool therefore performs only the
substrate-check (SC+ syscall floor + KIND_TCP_SOCKET mandatory,
KIND_UDP_SOCKET + KIND_IPC_ENDPOINT optional) before accepting this
package, per `design/tooling/plan.md` §6.3's dependency-resolution
contract. The `[not-linked]` section documents, for the record, that
`libpdx-net` / `libpdx-audit` / `libpdx-semantic-pipe` are named
adjacent (in caps.decl comments or in future-milestone plans) but
never actually called by any function in this repo at v1.2.0 -- a
consumer-side installer must NOT treat any of them as a hard
dependency.

## 6. Verification (consumer side)

    pkg install pdxsock --verify-only     # dry run, no install
    pkg keys show paideia-release-line     # inspect the signer

AND-semantics per the hybrid scheme: both Ed25519 and ML-DSA-65 MUST
verify; either failure REJECTS the package. Not runnable until the
placeholder signature block in `manifest.pdxsig` is replaced by a
real dual-sign pass per §3/§4 above.

---

## 7. What lands at M5-001 (this milestone)

Repo-side, M5-001 lands the source form of the release:

- `CHANGELOG.md` -- `[1.2.0]` entry summarising the M5-001 delta
  and demoting the v1.1.0 stanza's release-policy plaintext from
  plan to history.
- `doc/pdxsock.pdxdoc` -- source-form `.pdxdoc` for `doc pdxsock`.
- `release/manifest.pdxsig.txt` -- release manifest source form,
  every hash and every signature slot a documented placeholder.
- `release/RELEASE-1.2.0.md` -- this document, including the
  distribution section (#14) documenting the future mirror-push
  target without performing it.
- `manifest.pdxproj` -- `version = 1.2.0`, `release.signer_author
  = paideia-release-line` (with placeholder-until-sign note),
  `release.mirror_target = pkgs.paideia-os/main/pdxsock/1.2.0/`.
- `STATUS.md` -- M5-001 flipped to landed, overall-status header
  bumped from *v1.1.0 released* to *v1.2.0 release-source landed*.

**Not performed at this milestone:** the git tag itself (main's
manual step, once this landing is reviewed), the actual `bash
tools/build.sh` + `doc compile` pass, the dual-sign pass (no live
seed keys in this repo -- see §3 S3 above), and the mirror push
(pdxsock#14, mirror endpoint does not exist yet -- S5 above, and
out of scope per that issue regardless).

Closes pdxsock#13.
