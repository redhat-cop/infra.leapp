# Analysis

The `analysis` role is used to create the Leapp pre-upgrade report on the target hosts. It also saves a copy of the current ansible facts under the `/etc/ansible/facts.d` directory for validation after upgrade.

The role is considered minimally invasive and hopefully will fly under the radar of your enterprise change management policy. That said, it does install the RHEL rpm packages that provide the Leapp framework if they are not already present. While application impact is very low, it may require a change ticket depending on how pedantic your policies are.

This role will not fail if there are inhibitors found, it will throw a warning. However, there is a fact available `upgrade_inhibited` which indicates whether the upgrade will be inhibited or not and you can choose to fail your own playbook using this variable.

## Role variables

| Name                  | Type | Default value           | Description                                     |
|-----------------------|------|-------------------------|-------------------------------------------------|
| leapp_upgrade_type    | String  | "satellite" | Set to "cdn" for hosts registered with Red Hat CDN and "rhui" for hosts using rhui repos. |

## Satellite variables

Activation keys provide a method to identify content views available from Red Hat Satellite. To do in-place upgrades using Satellite, a content view including both the current RHEL version and the next version must be created. Use these variables to specify the activation keys for the required content views.

| Name                  | Type | Default value           | Description                                     |
|-----------------------|------|-------------------------|-------------------------------------------------|
| satellite_organization  | String   |  | Organization used in Satellite definition |
| satellite_activation_key_pre_leapp | String |  | Activation key for the current RHEL version content view |
| satellite_activation_key_leapp     | String |  | Activation key for the content view including both the current RHEL version and the next version |
| leapp_repos_enabled    | List | [] | Satellite repo for the satellite client RPM install |

## Optional variables

| Name                  | Type | Default value           | Description                                     |
|-----------------------|------|-------------------------|-------------------------------------------------|
| leapp_answerfile | Multi-line String |  | If defined, this is written to `/var/log/leapp/answerfile` before generating the pre-upgrade report. |
| leapp_reposfile | Multi-line String |  | If defined, this is written to `/etc/leapp/files/leapp_upgrade_repositories.repo` before generating the pre-upgrade report. |
| leapp_preupg_opts | String | | Optional string to define command line options to be passed to the `leapp` command when running the pre-upgrade. |
| post_reboot_delay | Int | 120 | Optional integer to pass to the reboot post_reboot_delay option. |
| os_path | String | $PATH | Option string to override the $PATH variable used on the target node |
| async_timeout_maximum   | Int | 7200                  | Variable used to set the asynchronous task timeout value (in seconds)
| async_poll_interval     | Int | 60                    | Variable used to set the asynchronous task polling internal value (in seconds)
## Example playbook

See [`analysis.yml`](../../playbooks/analysis.yml)

## Authors

Bob Mader, Mike Savage, Jeffrey Cutter, David Danielsson, Scott Vick

## License

MIT
