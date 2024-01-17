# Remediations

The `remediation` role is to assist in the remediation of a system. This role contains multiple playbooks that can be used to remediate a system for a specific inhibitors that are found during the pre-upgrade analysis.

## Role variables

| Name                    | Default value         | Description                                         |
|-------------------------|-----------------------|-----------------------------------------------------|
| leapp_report_location   | /var/log/leapp/leapp-report.json | Location of the leapp report file.       |
| remediation_playbooks   | see [Remediation playbooks](#remediation-playbooks) | List of available remediation playbooks.|
| remediation_todo        | []                    | List of remediation playbooks to run.               |

`remediation_todo` is a list of remediation playbooks to run. The list is empty by default. The list can be populated by the titles from [Remediation playbooks](#remediation-playbooks) section. For example:

```yaml
remediation_todo:
  - LEAPP_CIFS_DETECTED
  - LEAPP_CORRUPTED_GRUBENV_FILE
```

## Remediation playbooks

The list of available remediation playbooks with their corresponding inhibitors titles:

- `LEAPP_CIFS_DETECTED`
  - **Solves:** Use of CIFS detected. Upgrade can't proceed.  CIFS is currently not supported by the inplace upgrade.
- `LEAPP_CORRUPTED_GRUBENV_FILE`
  - **Solves:** Detected a corrupted grubenv file.
- `LEAPP_CUSTOM_NETWORK_SCRIPTS_DETECTED`
  - **Solves:** custom network-scripts detected. RHEL 9 does not support the legacy network-scripts package that was deprecated in RHEL 8.
- `LEAPP_DEPRECATED_SSHD_DIRECTIVE`
  - **Solves:** A deprecated directive in the sshd configuration.
- `LEAPP_FIREWALLD_ALLOWZONEDRIFTING`:
  - **Solves:** Firewalld Configuration AllowZoneDrifting Is Unsupported.
- `LEAPP_FIREWALLD_UNSUPPORTED_TFTP_CLIENT`
  - **Solves:** Firewalld Service tftp-client Is Unsupported.
- `LEAPP_LOADED_REMOVED_KERNEL_DRIVERS`
  - **Solves:** Leapp detected loaded kernel drivers which have been removed in RHEL 8. Upgrade cannot proceed.
- `LEAPP_MISSING_EFIBOOTMGR`
  - **Solves:** efibootmgr package is required on EFI systems.
- `LEAPP_MISSING_PKG`
  - **Solves:** Leapp detected missing packages.
- `LEAPP_MISSING_YUM_PLUGINS`
  - **Solves:** Required DNF plugins are not being loaded.
- `LEAPP_MULTIPLE_KERNELS`
  - **Solves:** Multiple kernels installed.
- `LEAPP_NEWEST_KERNEL_NOT_IN_USE`
  - **Solves:** Newest installed kernel not in use.
- `LEAPP_NFS_DETECTED`
  - **Solves:** Use of NFS detected. Upgrade can't proceed.
- `LEAPP_NON_PERSISTENT_PARTITIONS`
  - **Solves:** Detected partitions mounted in a non-persistent fashion, preventing a successful in-place upgrade.
- `LEAPP_NON_STANDARD_OPENSSL_CONFIG`
  - **Solves:** Non-standard configuration of openssl.cnf.
- `LEAPP_OLD_POSTGRESQL_DATA`
  - **Solves:** Old PostgreSQL data found in `/var/lib/pgsql/data`.
- `LEAPP_PARTITIONS_WITH_NOEXEC`
  - **Solves:** Detected partitions mounted with the `noexec` option, preventing a successful in-place upgrade.
- `LEAPP_RELATIVE_SYMLINKS`
  - **Solves:** Upgrade requires links in root directory to be relative
- `LEAPP_RPMS_WITH_RSA_SHA1_DETECTED`
  - **Solves:** Detected RPMs with RSA/SHA1 signature.
- `LEAPP_UNAVAILABLE_KDE`
  - **Solves:** The installed KDE environment is unavailable on RHEL 8.
- `LEAPP_VDO_CHECK_NEEDED`
  - **Solves:** Cannot perform the VDO check of block devices.

## Example playbook

See [`remediate.yml`](../../playbooks/remediate.yml).

## Authors

Peter Zdravecký

## License

MIT
