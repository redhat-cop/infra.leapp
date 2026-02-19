# Upgrade

The `upgrade` role is used to kick off the Leapp OS upgrade on the target host. During the execution of this task, the host will be rebooted more than once. After the Leapp OS upgrade is finished, the role will perform some basic validation tests to determine if the OS was upgraded successfully.

Additionally a list of any non-Red Hat RPM packages that were installed on the server prior to the upgrade but were removed during the upgrade will be saved as a set of local facts in `/etc/ansible/facts.d`

## Role variables

| Name                                          | Type    | Default value                  | Description |
|-----------------------------------------------|---------|--------------------------------|-------------|
| leapp_upgrade_type                            | String  | "cdn"                          | Set to "cdn" for hosts registered with Red Hat CDN, "rhui" for hosts using rhui repos, "satellite" for hosts registered to Satellite, and "custom" for custom repos. |
| leapp_upgrade_opts                            | String  | ""                             | Optional string to define command line options to be passed to the `leapp` command when running the upgrade. |
| leapp_repos_enabled                           | List    | []                             | Optional list of repos to limit for use in the upgrade process. |
| leapp_selinux_mode                            | String  | same as before upgrade         | Define this variable to the desired SELinux mode to be set after the OS upgrade, i.e., enforcing, permissive, or disabled. By default, the SELinux mode will be set to what was found during the pre-upgrade analysis. |
| leapp_set_crypto_policies                     | Boolean | true                           | Boolean to define if system-wide cryptographic policies should be set after the OS upgrade. |
| leapp_crypto_policy                           | String  | "DEFAULT"                      | System-wide cryptographic to set, e.g., "FUTURE", "DEFAULT:SHA1", etc. Refer to the crypto-policies (7) man page for more information. |
| leapp_reboot_timeout                          | Int     | 7200                           | Integer for maximum seconds to wait for reboot to complete. |
| leapp_upgrade_timeout                         | Int     | 14400                          | Integer for maximum seconds to wait for reboot to complete during upgrade reboot. |
| leapp_post_reboot_delay                       | Int     | 120                            | Integer to pass to the reboot post_reboot_delay option. |
| leapp_resume_retries                          | Int     | 360                            | Integer for maximum retries to wait for leapp_resume service no longer exists. |
| leapp_resume_delay                            | Int     | 10                             | Integer for seconds between each attempt to check leapp_resume service no longer exists. |
| leapp_update_grub_to_grub_2                   | Boolean | false                          | Boolean to control whether grub gets upgraded to grub 2 in post RHEL 6 to 7 upgrade. |
| leapp_os_path                                 | String  | $PATH                          | Variable used to override the default $PATH environmental variable on the target node. |
| leapp_async_timeout_maximum                   | Int     | 7200                           | Variable used to set the asynchronous task timeout value (in seconds). |
| leapp_async_poll_interval                     | Int     | 60                             | Variable used to set the asynchronous task polling internal value (in seconds). |
| leapp_check_analysis_results                  | Boolean | true                           | Allows for running remediation and going straight to upgrade without re-running analysis. |
| leapp_pre_upgrade_update                      | Boolean | true                           | Boolean to decide if an update and reboot on the running pre-upgrade operating system will run. |
| leapp_post_upgrade_update                     | Boolean | true                           | Boolean to decide if after the upgrade is performed a dnf update will run. |
| leapp_post_upgrade_unset_release              | Boolean | true                           | Boolean used to control whether Leapp's RHSM release lock is unset. |
| leapp_post_upgrade_release                    | String  | ""                             | Optional string used to set a specific RHSM release lock after the Leapp upgrade, but before the final update pass. |
| leapp_kernel_modules_to_unload_before_upgrade | List    | []                             | A list of kernel modules to be unloaded prior to running leapp. |
| leapp_post_upgrade_python_interpreter         | String  | "/usr/libexec/platform-python" | Set interpreter used by Ansible after the upgrade to execute post-upgrade tasks. Usually you do not need to change this variable because the default value is the system-level python interpreter that is always present. |
| leapp_system_roles_collection                 | String  | "fedora.linux_system_roles" | Set which Ansible Collection to use for System Roles. For community/upstream, use "fedora.linux_system_roles". For the RHEL, AAP, use "redhat.rhel_system_roles". |
| leapp_remove_old_rhel_packages                | Boolean | true                           | Boolean to control whether the previous version RHEL packages should be removed. Change to false to maintain behavior of infra.leapp prior to release 1.6.0. |
| leapp_grub_boot_device                        | String  | null                           | Optional device path (e.g., /dev/sda) for grub2-install. If not defined, will be auto-detected from /boot or / mount point. |
| leapp_workdir_controller                      | String  | {{ playbook_dir }}             | Directory on the control node to store reports from managed-nodes generated by this role and by leapp. |
| leapp_copy_reports                            | Boolean | true                           | Copy leapp report files (JSON and text) from managed nodes to the controller. Reports are stored in the directory defined by the `leapp_workdir_controller` variable in a timestamped directory |


## Satellite variables

Activation keys provide a method to identify content views available from Red Hat Satellite. To do in-place upgrades using Satellite, both the current RHEL version and the next RHEL version repositories must be available. These variables are optional - if `leapp_satellite_organization` and `leapp_satellite_activation_key` are left empty (the default), the satellite registration step is skipped and the system is expected to already be registered to the correct content view for the upgrade. If both variables are provided, the collection will register the system using the specified activation key. In case the system should be registered to a different activation key after the upgrade, one can specify the `leapp_satellite_activation_key_post_upgrade` in order to register to it after the upgrade concludes. If not specified, the system will remain registered to the `leapp_satellite_activation_key` used during the upgrade. The post-upgrade registration is also skipped if the organization or post-upgrade activation key is empty.

| Name                                        | Type   | Default value                  | Description |
|---------------------------------------------|--------|--------------------------------|-------------|
| leapp_satellite_organization                | String | ""                             | Organization used in Satellite definition. |
| leapp_satellite_activation_key              | String | ""                             | Activation key for the content view including both the current RHEL version and the next version. |
| leapp_satellite_activation_key_post_upgrade | String | leapp_satellite_activation_key | Activation key for the content view with the next RHEL version to register to after the upgrade. |
| leapp_repos_enabled                         | List   | []                             | Satellite repo for the satellite client RPM install. |

## Custom repos variables

See comments in defaults/main.yml for additional details.

| Name                                  | Type          | Default value | Description |
|---------------------------------------|---------------|---------------|-------------|
| leapp_local_repos_pre                 | List of dicts | []            | Used to configure repos for yum update before running leapp upgrade (current version). |
| leapp_local_repos                     | List of dicts | []            | Used to configure next version repos in /etc/leapp/files/leapp_upgrade_repositories.repo. |
| leapp_local_repos_post_upgrade        | List of dicts | []            | Used to configure next version repos post upgrade (can be set to leapp_local_repos if the same). |
| leapp_repo_files_to_remove_at_upgrade | List          | []            | Simpler way to remove /etc/yum.repos.d files before leapp upgrade is run. |
| leapp_env_vars                        | Dict          | {}            | Environment variables to use when running `leapp` command. See defaults/main.yml for example. |

## Example playbook

See [`upgrade.yml`](https://github.com/redhat-cop/infra.leapp/tree/main/playbooks/upgrade.yml).

## Authors

Bob Mader, Mike Savage, Jeffrey Cutter, David Danielsson, Scott Vick

## License

MIT
