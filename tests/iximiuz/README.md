# Manual LDAP JIT test with Iximiuz Labs

This optional test starts an isolated Samba AD domain and the SubSignature
application in an Iximiuz Docker playground. Docker runs only in the remote
playground; Docker Desktop is not required locally. Each tester uses their own
Iximiuz account. The script does not read or publish account tokens or account
names. Playground IDs and random test passwords stay in the local process and
terminal output, not in the repository. LDAP and the PHP development server
listen only on the playground loopback interface.

## Requirements

- A free Iximiuz Labs account and the `labctl` CLI.
- `labctl auth login` completed on your machine.
- Windows PowerShell and the OpenSSH client.
- Free local ports 8100 and 1636 for SSH forwarding.
- Network access to clone the public personal fork's `custom/release` branch.

## Start the environment

From the repository root, run:

```powershell
pwsh -NoProfile -File .\tests\iximiuz\start-samba.ps1
```

The script starts a free-tier playground, pulls the Samba AD image by immutable
digest, provisions the `teste.local` domain and test users, installs PHP and
the required extensions, checks out the personal fork's `custom/release`
branch, and starts the app at `127.0.0.1:8100`. It maps
`dc1.teste.local` to loopback **inside the playground**, keeps TLS certificate
verification enabled, and stores the Samba CA in the playground. It does not
change the Windows hosts file. Temporary passwords and the playground ID are
printed only to the local terminal.

A successfully initialized playground is left running for testing. Setup
failures destroy it automatically.

## Connect and test

In one terminal, run the printed `labctl ssh-proxy` command. In another
terminal, run the printed `ssh -N -L` command. It forwards both the app and
loopback-only LDAPS port to your machine. The SSH host key is recorded in a
playground-specific file under `%TEMP%`, not in your normal `known_hosts`.

Open `http://127.0.0.1:8100/install.php`, create the first administrator, and
configure **Admin → LDAP Import** with:

- Host `dc1.teste.local`, port `1636`, LDAPS, certificate verification enabled.
- The CA path printed by the script (`/home/laborant/samba-ad-ca.pem` on the
  playground).
- Base DN `DC=teste,DC=local`.
- The Active Directory preset, JIT enabled, and the printed service bind DN and
  password.

Then:

1. Use **Test connection** to confirm the service bind and directory search.
2. Sign in with `jit-active` and its printed password. The first successful
   login should provision an active LDAP user and signature.
3. Sign in with `jit-disabled` and its printed password. The active-account
   filter should reject it without provisioning a user.

## Cleanup

Stop both SSH processes with Ctrl+C, destroy the playground using the command
printed by the script, and remove its local temporary SSH host-key directory
using the printed command. The free tier is time-limited and playground storage
is ephemeral; this is a manual test environment, not a shared or always-on
service.
