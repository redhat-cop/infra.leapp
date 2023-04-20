# Upgrade

The `upgrade` role is used to kick off the Leapp OS upgrade on the target host. During the execution of this task, the host will be rebooted more than once. After the Leapp OS upgrade is finished, the role will perform some basic validation tests to determine if the OS was upgraded successfully.

## Role variables

| Name                    | Default value         | Description                                         |
|-------------------------|-----------------------|-----------------------------------------------------|
| leapp_upgrade_type      | "disconnected"        | Set to "connected" for hosts registered with Red Hat Subscription Manager and Red Hat CDN package repos. |
| leapp_upgrade_opts      |                       | Optional string to define command line options to be passed to the `leapp` command when running the upgrade. |
| selinux_mode            | same as before upgrade | Define this variable to the desired SELinux mode to be set after the OS upgrade, i.e., enforcing, permissive, or disabled. By default, the SELinux mode will be set to what was found during the pre-upgrade analysis. |
| set_crypto_policies     | true                  | Boolean to define if system-wide cryptographic policies should be set after the OS upgrade |
| crypto_policy           | "DEFAULT"             | System-wide cryptographic to set, e.g., "FUTURE", "DEFAULT:SHA1", etc. Refer to the crypto-policies (7) man page for more information. |

## Example playbook

See [`upgrade.yml`](../../playbooks/upgrade.yml).

## License

MIT
