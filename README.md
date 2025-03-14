# Ansible Leapp Collection

[![CI](https://github.com/redhat-cop/infra.leapp/workflows/CI/badge.svg?query=event%3Apush)](https://github.com/redhat-cop/infra.leapp/actions) [![Lint](https://github.com/redhat-cop/infra.leapp/workflows/Yaml%20and%20Ansible%20Lint/badge.svg?query=event%3Apush)](https://github.com/redhat-cop/infra.leapp/actions) [![OpenSSF Best Practices](https://bestpractices.coreinfrastructure.org/projects/7438/badge)](https://bestpractices.coreinfrastructure.org/projects/7438)

<!-- [![Codecov](https://img.shields.io/codecov/c/github/redhat-cop/infra.leapp)](https://codecov.io/gh/redhat-cop/infra.leapp) -->

## Overview

This collection provides Ansible roles you can use to perform RHEL in-place upgrades using the Leapp framework. Successfully executing upgrades at scale across a large RHEL estate demands a customized end-to-end automation approach tailored to meet the requirements of your enterprise environment. Use these roles as the foundation of your RHEL in-place upgrade automation solution.

## Roles

These are the roles included in the collection. Follow the links below to see the detailed documentation and example playbooks for each role.

- [`analysis`](./roles/analysis/) - executes the Leapp pre-upgrade phase
- [`common`](./roles/common/) - used for local logging, mutex locking, and common vars
- [`parse_leapp_report`](./roles/parse_leapp_report/) - reads pre-upgrade results and checks for inhibitors
- [`upgrade`](./roles/upgrade/) - executes the Leapp OS upgrade
- [`remediate`](./roles/remediate/) - assists in the remediation of a system (RHEL 7->8 and 8->9 only)

## Supported RHEL versions

The collection supports RHEL in-place upgrades for the following RHEL versions:

- RHEL 6 to RHEL 7 (RUT)
- RHEL 7 to RHEL 8 (Leapp)
- RHEL 8 to RHEL 9 (Leapp)

The collection may be used for the RHEL upgrade paths and minor versions supported by the indicated upgrade utilities (Leapp or RUT). Refer the to Red Hat knowledge solution article [Supported in-place upgrade paths for Red Hat Enterprise Linux](https://access.redhat.com/articles/4263361) for the latest support details.

The roles in this collection have been successfully used in a number of different environments including on-prem bare metal servers and VMs pulling RHEL packages from Red Hat CDN repos, Satellite content views, or mirrored repos internal to disconnected networks. Upgrading RHEL on Amazon EC2 instances pulling from bring-your-own-subscription CDN repos or pay-as-you-go RHUI repos have also been tested. Upgrading RHEL on other public clouds should be possible as well after setting the documented role variables as required.

> [!IMPORTANT]
> Targeting RHEL 6 nodes requires an Ansible-core version <= 2.12
>
> Targeting RHEL 7 nodes requires an Ansible-core version <= 2.16
>
> See [this knowledgebase article](https://access.redhat.com/articles/6977724) for details

## Not in scope

Third-party products and packages are not upgraded by the `upgrade` role. To achieve a complete end-to-end server upgrade, you may need to implement custom automation beyond the scope of this collection to perform tasks required for the upgrade or removal/reinstall of any impacted third-party tools and agents, for example [Veritas Cluster](https://www.veritas.com/support/en_US/doc/infoscale_wp_upgradewithRedHat), [SAP HANA](https://access.redhat.com/solutions/5154031), etc. Likewise, the role does not upgrade packages installed from non-RHEL repositories such as [Red Hat Software Collections](https://access.redhat.com/support/policy/updates/rhscl), [EPEL](https://docs.fedoraproject.org/en-US/epel/), [RPM Fusion](https://rpmfusion.org/), etc.

Having said that, many application workloads will benefit from [RHEL Application Compatibility](https://access.redhat.com/articles/rhel8-abi-compatibility) support such that they will still function correctly after a RHEL in-place upgrade if simply left untouched. Of course, the only way to know for sure is to run a test upgrade and then assess if there is any unexpected impact to your app. Pro tip: Test in your lower environments before moving on to production.

## Example playbooks

Example playbooks can be found [here](./playbooks/).

## Installing the collection from Ansible Galaxy

Before using this collection, you need to install it with the Ansible Galaxy command-line tool:

```bash
ansible-galaxy collection install infra.leapp
```

You can also include it in a `requirements.yml` file and install it with `ansible-galaxy collection install -r requirements.yml`, using the format:

```yaml
---
collections:
  - name: infra.leapp
  - name: ansible.posix
    version: ">=1.5.1"
  - name: community.general
    version: ">=6.6.0"
  - name: fedora.linux_system_roles # or redhat.rhel_system_roles see upgrade readme for more details
    version: ">=1.21.0"
```

Note that if you install the collection from Ansible Galaxy, it will not be upgraded automatically when you upgrade the `ansible` package. To upgrade the collection to the latest available version, run the following command:

```bash
ansible-galaxy collection install infra.leapp --upgrade
```

You can also install a specific version of the collection, for example, if you need to downgrade when something is broken in the latest version (please report an issue in this repository). Use the following syntax to install version `1.0.0`:

```bash
ansible-galaxy collection install infra.leapp:==1.0.0
```

See [Using Ansible collections](https://docs.ansible.com/ansible/devel/user_guide/collections_using.html) for more details.

## Contributing

We are a fledgling community and welcome any new contributors. Get started by opening an issue or pull request. Refer to our [contribution guide](CONTRIBUTING.md) for more information.

## Reporting issues

Please open a [new issue](https://github.com/redhat-cop/infra.leapp/issues/new/choose) for any bugs or security vulnerabilities you may encounter. We also invite you to open an issue if you have ideas on how we can improve the solution or want to make a suggestion for enhancement.

## More information

This Ansible collection is just one building block of our larger initiative to make RHEL in-place upgrade automation that works at enterprise scale. Learn more about our end-to-end approach for automating RHEL in-place upgrades at this [blog post](https://red.ht/bobblog).

## Release notes

See the [changelog](https://github.com/redhat-cop/infra.leapp/tree/main/CHANGELOG.rst).

## Licensing

MIT

See [LICENSE](LICENSE) to see the full text.
