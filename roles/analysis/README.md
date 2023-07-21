# Analysis

The `analysis` role is used to create the Leapp pre-upgrade report on the target hosts.

This is used in IPU planning to identify unhandled cases, that would result in process failure.

This role also saves a copy of the current ansible facts under the `/etc/ansible/facts.d` directory for validation after upgrade.

## Satellite activation keys

Satellite activation keys provide content for dnf/yum to solve dependencies.
During analysis, the both current and final packages needs to be visible.  
The current key is retained and reapplied after analysis is complete.

- `satellite_activation_key_pre_leapp` is used to hold the key for the starting content view
- `satellite_activation_key_leapp` provides both starting and final OS version content.

## Requirements

## Commonly modified variables

| Name                  | Type | Default value           | Description                                     |
|-----------------------|------|-------------------------|-------------------------------------------------|
| leapp_upgrade_type    | String  | "satellite" | Set to "cdn" for hosts registered with Red Hat CDN and "rhui" for hosts using rhui repos. |
| leapp_preupg_opt  | String | | Optional string to define command line options to be passed to the `leapp` command when running the pre-upgrade.|

## Variables for Satellite based upgrades
| Name                  | Type | Default value           | Description                                     |
|-----------------------|------|-------------------------|-------------------------------------------------|
| satellite_organization  | String   |  | Organization used in Satellite definition |
| satellite_activation_key_leapp     | String |  | Satellite activation key used during analysis |
| satellite_activation_key_pre_leapp | String |  | Satellite key for use after analysis |
| leapp_repos_enabled    | List | [] | Satellite repo for the satellite client RPM install |

## Optional variables

| Name                  | Type | Default value           | Description                                     |
|-----------------------|------|-------------------------|-------------------------------------------------|
| leapp_answerfile | Multi-line String |  | If defined, this writen to `/var/log/leapp/answerfile` before generating the pre-upgrade report. |
| leapp_preupg_opts | String | | Optional string to define command line options to be passed to the `leapp` command when running the pre-upgrade. |
| post_reboot_delay | Int | 120 | Optional integer to pass to the reboot post_reboot_delay option. |

## Example playbook

See [`analysis.yml`](../../playbooks/analysis.yml)

## Authors
author: Bob Mader, Mike Savage, Jeffrey Cutter, David Danielsson, Scott Vick

## License

MIT

