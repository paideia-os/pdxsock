# pdxsock

General TCP/UDP client + server (`netcat`-adjacent). `-l` listen mode, `-u` UDP mode, `-m` mirror (echo-back) mode, stdin→socket/socket→stdout. TCP client, TCP server (single-connection-at-a-time), TCP mirror server (`-l -m <port>`, echoes every received byte back to the sender), and connected-UDP client (`-u <host> <port>`) are all real as of v1.3.0. The TCP client/server pump also does a non-blocking `sys_poll` drain of the socket before each stdin read (pdxsock#21) -- true concurrent full-duplex remains blocked on a kernel-side gap (`sys_poll` cannot observe non-socket fds like stdin; see `src/main.pdx`'s v1.3.0 header note). Deliberately omits `-e` exec-on-connect (a known netcat foot-gun); UDP server mode (`-l -u`, a bound-not-connected listener) is still out of scope (needs `recvfrom` with peer-address out-params wired into the generic listen path).

## Spec

Full design lives in the paideia-os monorepo at
[`design/networking/r100-user-tools-plan.md`](https://github.com/paideia-os/paideia-os/blob/main/design/networking/r100-user-tools-plan.md)
(softarch's R100 user-tools plan). Section references in issues point into that document.

This repository is one of seven satellite repos that together deliver the
R100 wave: `libpdx-net`, `libpdx-url`, `pdxcurl`, `pdxping`, `pdxdig`,
`pdxsock`, `pdxtrust`.

## License

MIT.