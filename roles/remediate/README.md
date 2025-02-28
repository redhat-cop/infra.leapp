# Remediations

**IMPORTANT:** This role is only supported for RHEL 7 and 8 systems. Not all remediations are applicable to both, and are noted in the remediation playbooks list below.

The `remediation` role is to assist in the remediation of a system. This role contains multiple playbooks that can be used to remediate a system for a specific inhibitors that are found during the pre-upgrade analysis.

## Role variables

| Name                    | Default value         | Description                                         |
|-------------------------|-----------------------|-----------------------------------------------------|
| leapp_report_location   | /var/log/leapp/leapp-report.json | Location of the leapp report file.       |
| remediation_playbooks   | see [Remediation playbooks](#remediation-playbooks) | List of available remediation playbooks.|
| remediation_todo        | []                    | List of remediation playbooks to run.               |
| reboot_timeout          | 7200                  | Integer for maximum seconds to wait for reboot to complete.     |
| post_reboot_delay       | 120                   | Integer to pass to the reboot post_reboot_delay option. |

`remediation_todo` is a list of remediation playbooks to run. The list is empty by default. The list can be populated by the titles from [Remediation playbooks](#remediation-playbooks) section. For example:

```yaml
remediation_todo:
  - leapp_cifs_detected
  - leapp_corrupted_grubenv_file
```

## Remediation playbooks

The list of available remediation playbooks with their corresponding inhibitors titles:

- `leapp_cifs_detected`
  - **Solves:** Use of CIFS detected. Upgrade can't proceed.  CIFS is currently not supported by the inplace upgrade.
- `leapp_corrupted_grubenv_file`
  - **Solves:** Detected a corrupted grubenv file.
- `leapp_custom_network_scripts_detected`
  - RHEL 8 Only
  - **Solves:** custom network-scripts detected. RHEL 9 does not support the legacy network-scripts package that was deprecated in RHEL 8.
- `leapp_deprecated_sshd_directive`
  - RHEL 8 Only
  - **Solves:** A deprecated directive in the sshd configuration.
- `leapp_firewalld_allowzonedrifting`
  - RHEL 8 Only
  - **Solves:** Firewalld Configuration AllowZoneDrifting Is Unsupported.
- `leapp_firewalld_unsupported_tftp_client`
  - RHEL 8 Only
  - **Solves:** Firewalld Service tftp-client Is Unsupported.
- `leapp_loaded_removed_kernel_drivers`
  - **Solves:** Leapp detected loaded kernel drivers which have been removed in RHEL 8. Upgrade cannot proceed.
- `leapp_missing_efibootmgr`
  - **Solves:** efibootmgr package is required on EFI systems.
- `leapp_missing_pkg`
  - **Solves:** Leapp detected missing packages.
- `leapp_missing_yum_plugins`
  - **Solves:** Required DNF plugins are not being loaded.
- `leapp_multiple_kernels`
  - **Solves:** Multiple kernels installed. **Requires reboot.**
- `leapp_newest_kernel_not_in_use`
  - **Solves:** Newest installed kernel not in use. **Requires reboot.**
- `leapp_nfs_detected`
  - **Solves:** Use of NFS detected. Upgrade can't proceed.
- `leapp_non_persistent_partitions`
  - **Solves:** Detected partitions mounted in a non-persistent fashion, preventing a successful in-place upgrade.
- `leapp_non_standard_openssl_config`
  - RHEL 8 Only
  - **Solves:** Non-standard configuration of openssl.cnf.
- `leapp_old_postgresql_data`
  - **Solves:** Old PostgreSQL data found in `/var/lib/pgsql/data`.
- `leapp_pam_tally2`
  - RHEL 7 Only
  - **Solves:** The pam_tally2 pam module(s) no longer available
- `leapp_partitions_with_noexec`
  - **Solves:** Detected partitions mounted with the `noexec` option, preventing a successful in-place upgrade.
- `leapp_relative_symlinks`
  - **Solves:** Upgrade requires links in root directory to be relative
- `leapp_remote_using_root`
  - RHEL 7 Only
  - **Solves:** Possible problems with remote login using root account
- `leapp_rpms_with_rsa_sha1_detected`
  - RHEL 8 Only
  - **Solves:** Detected RPMs with RSA/SHA1 signature.
- `leapp_unavailable_kde`
  - **Solves:** The installed KDE environment is unavailable on RHEL 8.
- `leapp_vdo_check_needed`
  - RHEL 8 Only
  - **Solves:** Cannot perform the VDO check of block devices.

## Example playbook

See [`remediate.yml`](../../playbooks/remediate.yml).

## Authors

Peter Zdravecký, Ryan Bontreger

## License

MIT
