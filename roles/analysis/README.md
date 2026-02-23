# Analysis

The `analysis` role is used to create the Leapp pre-upgrade report on the target hosts. It also saves a copy of the current ansible facts under the `/etc/ansible/facts.d` directory for validation after upgrade.

The role is considered minimally invasive and hopefully will fly under the radar of your enterprise change management policy. That said, it does install the RHEL rpm packages that provide the Leapp framework if they are not already present. While application impact is very low, it may require a change ticket depending on how pedantic your policies are.

This role will not fail if there are inhibitors found, it will throw a warning. However, there is a fact available `upgrade_inhibited` which indicates whether the upgrade will be inhibited or not and you can choose to fail your own playbook using this variable.

## Generated remediations

Analysis role generates hostvars files for each node that runs pre-upgrade.
It reads pre-upgrade reports and matches found inhibitors to available remediations provided by the `remediation` role.

`analysis` role creates the directory `host_vars` in the `{{ leapp_workdir_controller }}` directory.
It generates variable files that set the `leapp_remediation_todo` variable with available remediations for existing inhibitors, based on each node's pre-upgrade report.

The role also generates a `remediate.yml` playbook that you can use to run remediation for all nodes.

## Role variables

| Name               | Type   | Default value | Description |
|--------------------|--------|---------------|-------------|
| leapp_upgrade_type | String | "cdn"         | Set to "cdn" for hosts registered with Red Hat CDN, "rhui" for hosts using rhui repos, "satellite" for hosts registered to Satellite, and "custom" for custom repos. |

## Satellite variables

Activation keys provide a method to identify content views available from Red Hat Satellite. To do in-place upgrades using Satellite, both the current RHEL version and the next RHEL version repositories must be available. These variables are **optional** — if `leapp_satellite_organization` and `leapp_satellite_activation_key` are left empty (the default), the satellite registration is skipped and the system is expected to already be registered to the correct content view for the upgrade. If both variables are provided, the collection will register the system using the specified activation key. In case the system uses a different content view than the one used for the upgrade, one can specify the `leapp_satellite_activation_key_post_analysis` in order to register to it after the analysis concludes, leaving the system in its original state. If not specified, the system will remain registered to the `leapp_satellite_activation_key` used during the analysis. The post-analysis registration is also skipped if the organization or post-analysis activation key is empty.

| Name                                         | Type   | Default value                  | Description |
|----------------------------------------------|--------|--------------------------------|-------------|
| leapp_satellite_organization                 | String | ""                             | Organization used in Satellite definition. |
| leapp_satellite_activation_key               | String | ""                             | Activation key for the content view including both the current RHEL version and the next version. |
| leapp_satellite_activation_key_post_analysis | String | leapp_satellite_activation_key | Activation key for the current RHEL version content view to register to after analysis. |
| leapp_repos_enabled                          | List   | []                             | Satellite repo for the satellite client RPM install. |

## Custom repos variables

See comments in defaults/main.yml for additional details.

| Name                            | Type          | Default value | Description |
|---------------------------------|---------------|---------------|-------------|
| leapp_local_repos_pre           | List of dicts | []            | Used to configure repos before running leapp analysis / installing leapp packages. |
| leapp_local_repos               | List of dicts | []            | Used to configure next version repos in /etc/leapp/files/leapp_upgrade_repositories.repo. |
| leapp_local_repos_post_analysis | List of dicts | []            | Used to return repos to previous state after leapp analysis if necessary. |

## Optional variables

| Name                                        | Type              | Default value               | Description |
|---------------------------------------------|-------------------|-----------------------------|-------------|
| leapp_answerfile                            | Multi-line String | ""                          | If defined, this is written to `/var/log/leapp/answerfile` before generating the pre-upgrade report. |
| leapp_preupg_opts                           | String            | ""                          | Optional string to define command line options to be passed to the `leapp` command when running the pre-upgrade. |
| leapp_high_sev_as_inhibitors                | Boolean           | false                       | Treat all high severity findings as inhibitors. |
| leapp_known_inhibitors                      | List              | []                          | List of keys of known inhibitors ignored when setting upgrade_inhibited and leapp_inhibitors. |
| leapp_env_vars                              | Dict              | {}                          | Environment variables to use when running `leapp` command. See defaults/main.yml for example. |
| leapp_os_path                               | String            | $PATH                       | Option string to override the $PATH variable used on the target node. |
| leapp_async_timeout_maximum                 | Int               | 7200                        | Variable used to set the asynchronous task timeout value (in seconds). |
| leapp_async_poll_interval                   | Int               | 60                          | Variable used to set the asynchronous task polling internal value (in seconds). |
| leapp_bypass_fs_checks                      | Boolean           | false                       | Set to `true` to bypass filesystem capacity checks. |
| leapp_system_roles_collection               | String            | "fedora.linux_system_roles" | Set which Ansible Collection to use for System Roles. For community/upstream, use 'fedora.linux_system_roles'. For the RHEL, AAP, use 'redhat.rhel_system_roles'. |
| leapp_workdir_controller                    | String            | {{ playbook_dir }}          | Directory on the control node to store reports from managed-nodes generated by this role and by leapp, hostvars with pre-defined remediations, and remediation.yml playbook. |
| leapp_copy_reports                          | Boolean           | true                        | Copy leapp report files (JSON and text) from managed nodes to the controller. Reports are stored in the directory defined by the `leapp_workdir_controller` variable in a timestamped directory |
| leapp_create_remediation_hostvars           | Boolean           | true                        | Create host_vars files and a remediation playbook on the controller in a directory defined by the `leapp_workdir_controller` variable. Each host gets its own host_vars file with `leapp_remediation_todo` variable. A `remediate.yml` playbook is created that uses these host variables. |

## Example playbook

See [`analysis.yml`](https://github.com/redhat-cop/infra.leapp/tree/main/playbooks/analysis.yml)

## Authors

Bob Mader, Mike Savage, Jeffrey Cutter, David Danielsson, Scott Vick

## License

MIT
