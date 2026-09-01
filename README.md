# pdxsock

General TCP/UDP client + server (`netcat`-adjacent). `-l` listen mode, `-u` UDP mode, stdin→socket/socket→stdout. TCP client + TCP server (single-connection-at-a-time) fully buildable today; connected-UDP client blocked on R100-PREP-002. Deliberately omits `-e` exec-on-connect (a known netcat foot-gun); UDP server mode is out of scope for v1 (needs `recvfrom` with peer-address out-params).

## Spec

Full design lives in the paideia-os monorepo at
[`design/networking/r100-user-tools-plan.md`](https://github.com/paideia-os/paideia-os/blob/main/design/networking/r100-user-tools-plan.md)
(softarch's R100 user-tools plan). Section references in issues point into that document.

This repository is one of seven satellite repos that together deliver the
R100 wave: `libpdx-net`, `libpdx-url`, `pdxcurl`, `pdxping`, `pdxdig`,
`pdxsock`, `pdxtrust`.

## License

MIT.