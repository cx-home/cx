# Owner decision 2026-09-29 — Letter 110: DBLANE-1's servers run in containers from a runtime devbox ships

**Status: RULED (owner, 2026-09-29 ~21:5xZ, in session, "110 b'", after reopening the letter the
integrator had taken as delegated at 21:3xZ — "can we set it up so its part of devbox and other devs
get the container runtime with that?" — on the reopened letter posted on
[#1591](https://github.com/cx-home/cx-private/issues/1591) at 21:4xZ with its options and
consequences). DBLANE-1, DBNUL-1, CXF-1, RS-36, D17a, RUN-5.**

## The owner's words, verbatim

"can we set it up so its part of devbox and other devs get the container runtime with that?" — "110 b'"

## DBSRV-1 — the container runtime comes from devbox; the step runs the vendors' images (L110 = (b′))

DBLANE-1 rules a real-server step "postgres and mysql in containers, on the shared slot and on a
runner", and dev2 — the box of the shared slot and of cx-platform-db's self-hosted runner — had no
container runtime (docker, podman, colima and nerdctl all absent, measured 2026-09-29 21:4xZ), while
devbox's package index carries `colima`, `docker-client`, `podman` and `lima` for the box. Ruled:
the runtime ships with `devbox.json` — `colima` and `docker-client` pinned there in cx-private and in
cx-platform-db, a devbox script that starts colima's Linux VM when it is not running, `DOCKER_HOST`
carried by devbox's environment, by the post-merge loop's launchd plist and by the self-hosted
runner — so every developer and every runner gets the same runtime on `devbox shell` with no system
install; the step's driver is a cx program that starts the VM if needed, runs the official
`postgres` and `mysql` images at pinned tags on ephemeral ports and removes the containers on every
exit path. This is the one mechanism for every external-system step the platform will need (redis,
IMAP/SMTP, sftp/ftp, an SSO provider), the vendors' own images at the versions the release notes
name. Rejected: (a) servers from devbox's `postgresql` / `mysql` packages with no VM — the simplest
lane, but every later external-system lane hand-packaged one nix package at a time, some absent or
unlike the shipped product (the integrator's earlier taking, superseded by the owner's word); (c) a
GitHub-hosted `services:` job with no local step — the shared slot and the union would never grade
the two engines. The cost stated with the choice: a Linux VM per box (2–4 GB of memory, a first boot
of 30–60 s, kept running), and no nested virtualisation on a GitHub-hosted macOS runner — ours are
self-hosted.
