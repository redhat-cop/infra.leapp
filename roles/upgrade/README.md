# Upgrade

The `upgrade` role is used to kick off the Leapp OS upgrade on the target host. During the execution of this task, the host will be rebooted more than once. After the Leapp OS upgrade is finished, the role will perform some basic validation tests to determine if the OS was upgraded successfully.

Additionally a list of any non-Red Hat RPM packages that were installed on the server prior to the upgrade but were removed during the upgrade will be saved as a set of local facts in `/etc/ansible/facts.d`

## Role variables

| Name                    | Default value         | Description                                         |
|-------------------------|-----------------------|-----------------------------------------------------|
| leapp_upgrade_type      | "satellite"           | Set to "cdn" for hosts registered with Red Hat CDN, "rhui" for hosts using rhui repos, and "custom" for custom repos. |
| leapp_upgrade_opts      |                       | Optional string to define command line options to be passed to the `leapp` command when running the upgrade. |
| leapp_repos_enabled     |                       | Optional list of repos to limit for use in the upgrade process. |
| selinux_mode            | same as before upgrade | Define this variable to the desired SELinux mode to be set after the OS upgrade, i.e., enforcing, permissive, or disabled. By default, the SELinux mode will be set to what was found during the pre-upgrade analysis. |
| set_crypto_policies     | true                  | Boolean to define if system-wide cryptographic policies should be set after the OS upgrade |
| crypto_policy           | "DEFAULT"             | System-wide cryptographic to set, e.g., "FUTURE", "DEFAULT:SHA1", etc. Refer to the crypto-policies (7) man page for more information. |
| reboot_timeout          | 7200                  | Integer for maximum seconds to wait for reboot to complete.     |
| upgrade_timeout         | 14400                 | Integer for maximum seconds to wait for reboot to complete during upgrade reboot.     |
| post_reboot_delay       | 120                   | Integer to pass to the reboot post_reboot_delay option. |
| leapp_resume_retries    | 360                   | Integer for maximum retries to wait for leapp_resume service no longer exists. |
| leapp_resume_delay      | 10                    | Integer for seconds between each attempt to check leapp_resume service no longer exists. |
| update_grub_to_grub_2   | false                 | Boolean to control whether grub gets upgraded to grub 2 in post RHEL 6 to 7 upgrade. |
| os_path                 | $PATH                 | Variable used to override the default $PATH environmental variable on the target node
| async_timeout_maximum   | 7200                  | Variable used to set the asynchronous task timeout value (in seconds)
| async_poll_interval     | 60                    | Variable used to set the asynchronous task polling internal value (in seconds)
| check_leapp_analysis_results| true              | Allows for running remediation and going straight to upgrade without re-running analysis. |
| pre_upgrade_update      | true                  | Boolean to decide if an update and reboot on the running pre-upgrade operating system will run. |
| post_upgrade_update     | true                   | Boolean to decide if after the upgrade is performed a dnf update will run|
| post_upgrade_unset_release| true                | Boolean used to control whether Leapp's RHSM release lock is unset.
| post_upgrade_release    |                       | Optional string used to set a specific RHSM release lock after the Leapp upgrade, but before the final update pass.
| kernel_modules_to_unload_before_upgrade | []    | A list of kernel modules to be unloaded prior to running leapp. |
| post_7_to_8_python_interpreter | /usr/libexec/platform-python | For RHEL 7 to 8 upgrades, /usr/bin/python is discovered but not available post upgrade. For 7 to 8 upgrades, ansible_python_interpreter is set to this value post upgrade reboot prior to reconnecting. |
| infra_leapp_upgrade_system_roles_collection | fedora.linux_system_roles | Can be one of:<br>- 'fedora.linux_system_roles'<br>- 'redhat.rhel_system_roles' |


## Satellite variables

Activation keys provide a method to identify content views available from Red Hat Satellite. To do in-place upgrades using Satellite, a content view including both the current RHEL version and the next version must be created. Use these variables to specify the activation keys for the required content views.

| Name                  | Type | Default value           | Description                                     |
|-----------------------|------|-------------------------|-------------------------------------------------|
| satellite_organization  | String   |  | Organization used in Satellite definition |
| satellite_activation_key_leapp     | String |  | Activation key for the content view including both the current RHEL version and the next version |
| satellite_activation_key_post_leapp     | String |  | Activation key for the content view for the next version post leapp |
| leapp_repos_enabled    | List | [] | Satellite repo for the satellite client RPM install |

## Custom repos variables

See comments in defaults/main.yml for additional details.

| Name                  | Type | Default value           | Description                                     |
|-----------------------|------|-------------------------|-------------------------------------------------|
| local_repos_pre_leapp  | List of dicts   | [] | Used to configure repos for yum update before running leapp upgrade (current version).|
| local_repos_leapp  | List of dicts   | [] | Used to configure next version repos in /etc/leapp/files/leapp_upgrade_repositories.repo.
| local_repos_post_upgrade  | List of dicts   | [] | Used to configure next version repos post upgrade (can be set to local_repos_leapp if the same)
| repo_files_to_remove_at_upgrade  | List   | [] | Simpler way to remove /etc/yum.repos.d files before leapp upgrade is run.
+| leapp_env_vars | Dict | {} | Environment variables to use when running `leapp` command. See defaults/main.yml for example. |

## Example playbook

See [`upgrade.yml`](../../playbooks/upgrade.yml).

## Authors:
Bob Mader, Mike Savage, Jeffrey Cutter, David Danielsson, Scott Vick

## License

MIT
