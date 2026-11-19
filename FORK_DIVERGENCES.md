# Personal fork divergences

This repository is the `rodolphobrock/SubSignature` distribution fork. The
`main` branch tracks the upstream project; `custom/release` is the accumulated
branch for complete, tested fork-specific changes.

## Baseline

- Upstream base: `husisusi/SubSignature` `main` at `d60005a`.
- Fork baseline: `custom/release`, initially published at `4659d30`.
- The baseline includes the LDAP JIT login feature from
  `feature/ldap-jit-login`.

## Fork-specific functionality

### LDAP JIT account provisioning

On an administrator's explicit opt-in, a successful LDAP login can create a
local SubSignature account and an LDAP-sourced signature.

- LDAP login is disabled by default.
- Verified LDAPS or STARTTLS and a service bind account are required.
- Local accounts are not implicitly linked to directory identities.
- Existing LDAP users keep their role and activation state.
- Disabled directory users are excluded by the Active Directory filter.
- Provisioning and signature synchronization run transactionally.

The feature was checked by its PHP provisioning test and an Iximiuz Samba AD
test using verified LDAPS. The manual test provisioned an active user and
rejected a disabled user. See [the compatibility matrix](docs/COMPATIBILITY.md)
and [the Iximiuz test guide](tests/iximiuz/README.md).

## Branch and release policy

- `main` remains a clean upstream reference.
- `custom/release` is the only accumulated branch intended to contain a complete
  custom distribution.
- `feature/*` and `sync/*` branches are temporary work branches, not releases.
- A custom release is tagged separately from upstream releases.
- Upstream synchronization must be reviewed and tested before merging into
  `custom/release`.

## Planned, not yet implemented

Configurable profile avatars and Gravatar integration are not part of the
current baseline. They require a separate issue and must preserve the opt-in,
privacy-first and offline-compatible behavior discussed for this fork.
