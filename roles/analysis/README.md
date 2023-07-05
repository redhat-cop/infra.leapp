# Analysis

The `analysis` role is used to create the Leapp pre-upgrade report on the target hosts. This is used for IPU planning, as well as during execution of the IPU `upgrade` role.
This role also saves a copy of the current ansible facts under the `/etc/ansible/facts.d` directory for validation after upgrade.

The role is considered minimally invasive and as such should not complicate compliance with enterprise change management policy.  Installation of the software is isolated to dedicated RPMS.

This could simplify use of a blanket change control for installation and execution. Running this role does install specific packages for the Leapp framework, if not already present.

Leapp typically requires the following RPMs:  ( where X is current and Y is X+1 RHEL version )
 - leapp
 - leapp-deps
 - leapp-upgrade-elXtoelY
 - leapp-upgrade-elXtoelY-deps
 - python3-leapp

These RPMs do not overlap with typical system function, which reduces impact during their install.

## Requirements

Metadata is required for leap preupgrade analysis to run.  When a system uses CDN, this is provided automatically.  For systems not on CDN, package metadata files needs to be provided by URL in leapp_metadata_url. Once obtained during IPU, file is unpacked on IPU host under `/etc/leapp/files` directory.

For more information, refer to the knowledge article [Leapp utility metadata in-place upgrades of RHEL for disconnected upgrades (including Satellite)](https://access.redhat.com/articles/3664871).

## Role variables

| Name                  | Type | Default value         | Description                                         |
|-----------------------|------|-------------------------|-------------------------------------------------|
| analysis_packages_el6 | List | leapp-upgrade             | RPMS that need to be installed for IPU to RHEL7 |
| analysis_repos_el6    | List | rhel-7-server-extras-rpms | Repo to be enabled for IPU to RHEL7             |
| analysis_packages_el7 | List | leapp-upgrade             | RPMS that need to be installed for IPU to RHEL7 |
| analysis_repos_el7    | List | rhel-7-server-extras-rpms | Repo to be enabled for IPU to RHEL7 |
| analysis_packages_el8 | List | leapp-upgrade | RPMS that need to be installed for IPU to RHEL8 |
| analysis_repos_el8 | List | rhel-7-server-extras-rpms | Repo to be enabled for IPU to RHEL7             |
| leapp_upgrade_type    | String  | satellite | satellite, cdn or rhui |
| leapp_preupg_opt | String | --no-rhsm when leapp_upgrade_type is connected | Upstream repository usage - whether to use RHSM |
| leapp_metadata_url      | String |  | URL to the leapp metadata, usually over https   |
| leapp_enable_repos_args | String |  | --enablerepo (leapp_repos_enabled) or blank |
| leapp_repos_enabled    | List | [] | Satellite repo for the satellite client RPM install |
| result_filename | String |  | Path to file for the output of leapp (preupg) |
| satellite_organization  | String | Example | Organization used in Satellite definition |
| satellite_activation_key_leapp | String |  | Key used to identify activation key |
| satellite_activation_key_pre_leapp | String |  | initial state of subscriptions and svc level |
| satellite_activation_key_leapp     | String |  | Post-IPU state of subscriptions and svc level |
| leapp_upgrade_type      | String | "disconnected"| Set to "connected" for hosts registered with Red Hat Subscription Manager and Red Hat CDN package repos. |
| leapp_metadata_url | URL | | See Requirements section above. |
| leapp_answerfile | TXT file | /var/log/leapp/answerfile | Optional - Source for Alternate AnswerFile needed during leapp process while upgrading  |
| leapp_preupg_opts | String | | Optional string to define command line options to be passed to the `leapp` command when running the pre-upgrade. |

## Example playbook

See [`analysis.yml`](../../playbooks/analysis.yml)
```
- name: Include task for leapp preupgrade analysis
  ansible.builtin.include_tasks: analysis-leapp.yml
  when: ansible_distribution_major_version|int >= 7
```

## Authors
author: Bob Mader, Mike Savage, Jeffrey Cutter, David Danielsson

## License

MIT
