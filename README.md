# nt-hs-os

Public post-install payload for HyScaler OS.

A HyScaler OS machine fetches this repo's `payload.enc` on first boot, verifies
it against `payload.hmac` using a secret that ships only on the ISO, decrypts it,
and runs it. That is how a freshly installed minimal Ubuntu becomes a HyScaler
machine: Chrome, Docker, authd, branding, the SSH root key, and Remote Login.

This repo is safe to be public:
- `payload.enc` is AES-256-CBC + PBKDF2, opaque without the ISO secret.
- `payload.hmac` lets the ISO reject any tampered payload before it runs.
- `assets/` holds only already-public keys and packages.
- The decryption secret and any plaintext payload live in the build repo, never here.

## Contents

- `payload.enc`, `payload.hmac` - the encrypted provisioner and its MAC.
- `assets/` - branding debs, Docker and Chrome apt keys, the Remote Login helper.
- `setup.sh` - run the payload by hand on an already-installed HyScaler machine:
  `git clone https://github.com/nettantra/nt-hs-os && sudo ./nt-hs-os/setup.sh`.

Regenerate everything with `make payload` in the build repo, then force-push here.
