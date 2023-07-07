# Upgrade

The `upgrade` role is used to kick off the Leapp OS upgrade on the target host. During the execution of this task, the host will be rebooted more than once. After the Leapp OS upgrade is finished, the role will perform some basic validation tests to determine if the OS was upgraded successfully.

Additionally a list of any non-Red Hat RPM packages that were installed on the server prior to the upgrade but were removed during the upgrade will be saved as a set of local facts in `/etc/ansible/facts.d`

## Role variables

| Name                    | Default value         | Description                                         |
|-------------------------|-----------------------|-----------------------------------------------------|
| leapp_upgrade_type      | "satellite"           | Set to "cdn" for hosts registered with Red Hat CDN and "rhui" for hosts using rhui repos. |
| leapp_upgrade_opts      |                       | Optional string to define command line options to be passed to the `leapp` command when running the upgrade. |
| leapp_repos_enabled     |                       | Optional list of repos to limit for use in the upgrade process. |
| selinux_mode            | same as before upgrade | Define this variable to the desired SELinux mode to be set after the OS upgrade, i.e., enforcing, permissive, or disabled. By default, the SELinux mode will be set to what was found during the pre-upgrade analysis. |
| set_crypto_policies     | true                  | Boolean to define if system-wide cryptographic policies should be set after the OS upgrade |
| crypto_policy           | "DEFAULT"             | System-wide cryptographic to set, e.g., "FUTURE", "DEFAULT:SHA1", etc. Refer to the crypto-policies (7) man page for more information. |
| post_reboot_delay       | 120                   | Optional integer to pass to the reboot post_reboot_delay option. |
| update_grub_to_grub_2   | false                 | Boolean to control whether grub gets upgraded to grub 2 in post RHEL 6 to 7 upgrade. |

## Example playbook

See [`upgrade.yml`](../../playbooks/upgrade.yml).

```ansible
- name: Perform OS upgrade
  ansible.builtin.import_role:
    name: infra.leapp.upgrade
```

## Authors:
Bob Mader, Mike Savage, Jeffrey Cutter, David Danielsson, Scott Vick

## License

MIT
