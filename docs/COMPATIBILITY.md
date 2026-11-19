# Fork compatibility matrix

This matrix distinguishes project requirements inherited from upstream from
combinations independently exercised for the fork. An upstream requirement is
not, by itself, a claim that every combination has been tested by this fork.

| Area | Declared requirement or behavior | Verified for this fork |
|---|---|---|
| PHP | PHP 8.0 or newer | PHP 8.3.6 CLI on Ubuntu 24.04 ran the web app and manual LDAP test. PHP 8.4.27 CLI on Windows ran the LDAP provisioning test. |
| Required PHP extensions | `sqlite3`, `mbstring`, `fileinfo`, `zip`, and `openssl` or `sodium` | The Iximiuz runtime loaded these extensions and passed the app installation check. |
| LDAP | Optional `ldap` extension for LDAP import/login | PHP LDAP extension and Samba Active Directory were exercised with verified LDAPS. |
| Database | SQLite; no external database server | The LDAP JIT test uses an in-memory SQLite database. The Iximiuz app test used a fresh disposable SQLite database. Upgrade of a production database was not tested. |
| Web server | Apache 2.4 with `mod_rewrite` and `mod_headers`; Nginx with equivalent rules | The built-in PHP development server was used only for the disposable Iximiuz test. Production Apache/Nginx configurations were not independently tested by this fork. |
| Server OS | Any OS supported by the required PHP runtime and web server | Ubuntu 24.04 was used for the end-to-end Iximiuz test. Windows was used for CLI checks, not a production web-server deployment. |
| LDAP directory | LDAP/Active Directory supported by the configured schema and attributes | Samba AD in an isolated Iximiuz Docker playground; TLS certificate verification remained enabled. |
| Desktop clients | Windows/Linux agent; Outlook classic and Thunderbird as described by upstream | Not part of the LDAP JIT baseline validation. |
| Local container runtime | Not required for the Iximiuz test | Docker Desktop was unavailable; the test ran Docker remotely in Iximiuz Labs. |

## LDAP JIT verification scope

The tested flow covered:

1. A verified LDAPS service bind and directory search.
2. First login provisioning an active LDAP-backed application user and one
   LDAP-sourced signature.
3. Rejection of a disabled directory user without provisioning an account.
4. Preservation of the existing security rules covered by
   `tests/LdapJitProvisionerTest.php`.

## Support policy

The PHP 8.0+ and web-server requirements above are inherited project
requirements. Before a custom production release, run the regression suite on
the exact deployment runtime and record any additional combinations here.
