# nt-hs-os

Public provisioning payload for HyScaler OS.

Install a machine by booting a stock Ubuntu ISO and pointing it at this repo's
`autoinstall/` over nocloud-net. That does a minimal install and injects a
first-boot hook. On first boot the operator types the provisioning passphrase;
the machine fetches `payload.enc` from here, verifies it against `payload.hmac`
with that passphrase, decrypts it, and runs it: Chrome, Docker, authd, branding,
the SSH root key, Remote Login.

This repo is safe to be public:
- `payload.enc` is AES-256-CBC + PBKDF2, opaque without the passphrase.
- `payload.hmac` lets a machine reject any tampered payload before it runs.
- `assets/` holds only already-public keys and packages.
- The passphrase and the plaintext provisioner live in the build repo, never here.

## Contents

- `autoinstall/user-data`, `autoinstall/meta-data` - the remote autoinstall.
- `payload.enc`, `payload.hmac` - the encrypted provisioner and its MAC.
- `assets/` - branding debs, Docker and Chrome apt keys, the Remote Login helper.
- `setup.sh` - run the payload by hand on an already-installed machine (prompts
  for the passphrase): `git clone https://github.com/nettantra/nt-hs-os && sudo ./nt-hs-os/setup.sh`.

Regenerate everything with `make payload` in the build repo, then force-push here.
