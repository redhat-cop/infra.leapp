# Analysis

The `analysis` role is used to create the Leapp pre-upgrade report on the target hosts. It also saves a copy of the current ansible facts under the `/etc/ansible/facts.d` directory for validation after upgrade.

The role is considered minimally invasive and hopefully will fly under the radar of your enterprise change management policy. That said, it does install the RHEL rpm packages that provide the Leapp framework if they are not already present. While application impact is very low, it may require a change ticket depending on how pedantic your policies are.

## Requirements

For non-CDN environments including Satellite, package metadata files needs to be provided. These files can be put on the host under the `/etc/leapp/files` directory before running the role. Alternatively, the `leapp_metadata_url` can be defined to tell the role where it can access the metadata tarball. For more information, refer to the knowledge article [Leapp utility metadata in-place upgrades of RHEL for disconnected upgrades (including Satellite)](https://access.redhat.com/articles/3664871).

## Role variables

| Name                    | Default value         | Description                                         |
|-------------------------|-----------------------|-----------------------------------------------------|
| leapp_upgrade_type      | "satellite"           | Set to "cdn" for hosts registered with Red Hat CDN and "rhui" for hosts using rhui repos. |
| leapp_metadata_url      |                       | See Requirements section above.                     |
| leapp_answerfile        |                       | Optional multi-line string. If defined, this will be used as the contents of `/var/log/leapp/answerfile`. |
| leapp_preupg_opts       |                       | Optional string to define command line options to be passed to the `leapp` command when running the pre-upgrade. |
| post_reboot_delay       | 120                   | Optional integer to pass to the reboot post_reboot_delay option. |

## Example playbook

See [`analysis.yml`](../../playbooks/analysis.yml).

## License

MIT

