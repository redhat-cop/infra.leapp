# Analysis

The `analysis` role is used to create the Leapp pre-upgrade report on the target hosts.

This is used in IPU planning to identify unhandled cases, that would result in process failure.


This role also saves a copy of the current ansible facts under the `/etc/ansible/facts.d` directory for validation after upgrade.

## Requirements

## Commonly modified variables

| Name                  | Type | Default value           | Description                                     |
|-----------------------|------|-------------------------|-------------------------------------------------|
| leapp_upgrade_type    | String  | "satellite" | Set to "cdn" for hosts registered with Red Hat CDN and "rhui" for hosts using rhui repos. |
| leapp_preupg_opt | String |  | Optional string to define command line options to be passed to the `leapp` command when running the pre-upgrade. |


## Variables for Satellite based upgrades
| Name                  | Type | Default value           | Description                                     |
|-----------------------|------|-------------------------|-------------------------------------------------|
| satellite_organization  | String |  | Organization used in Satellite definition |
| satellite_activation_key_leapp | String |  | Key used to identify activation key |
| satellite_activation_key_pre_leapp | String |  | initial state of subscriptions and svc level |
| satellite_activation_key_leapp     | String |  | Post-IPU state of subscriptions and svc level |
| leapp_repos_enabled    | List | [] | Satellite repo for the satellite client RPM install |

## Optional variables

| Name                  | Type | Default value           | Description                                     |
|-----------------------|------|-------------------------|-------------------------------------------------|
| result_filename | String |  | Path to file for the output of leapp |
| analysis_packages_el6 | List | redhat-upgrade-tool | RPMS that need to be installed for IPU to RHEL7 |
| analysis_repos_el6    | List | rhel-6-server-extras-rpms rhel-6-server-optional-rpms | Repo to be enabled for IPU to RHEL7  |
| analysis_packages_el7 | List | leapp-upgrade             | RPMS that need to be installed for IPU to RHEL7 |
| analysis_repos_el7    | List | rhel-7-server-extras-rpms | Repo to be enabled for IPU to RHEL7 |
| analysis_packages_el8 | List | leapp-upgrade | RPMS that need to be installed for IPU to RHEL8 |
| analysis_repos_el8 | List | rhel-7-server-extras-rpms | Repo to be enabled for IPU to RHEL7 |
| leapp_answerfile | TXT file | /var/log/leapp/answerfile | Optional - Source for Alternate AnswerFile needed during leapp process while upgrading  |
| leapp_preupg_opts | String | | Optional string to define command line options to be passed to the `leapp` command when running the pre-upgrade. |

## Role variables

| Name                    | Default value         | Description                                         |
|-------------------------|-----------------------|-----------------------------------------------------|
| leapp_upgrade_type      | "satellite"           | Set to "cdn" for hosts registered with Red Hat CDN and "rhui" for hosts using rhui repos. |
| leapp_answerfile        |                       | Optional multi-line string. If defined, this will be used as the contents of `/var/log/leapp/answerfile`. |
| leapp_preupg_opts       |                       | Optional string to define command line options to be passed to the `leapp` command when running the pre-upgrade. |
| post_reboot_delay       | 120                   | Optional integer to pass to the reboot post_reboot_delay option. |


## Example playbook

See [`analysis.yml`](../../playbooks/analysis.yml)

## Authors
author: Bob Mader, Mike Savage, Jeffrey Cutter, David Danielsson, Scott Vick

## License

MIT

