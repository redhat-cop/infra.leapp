# Ansible Leapp Collection

[![CI](https://github.com/redhat-cop/infra.leapp/workflows/CI/badge.svg?event=push)](https://github.com/redhat-cop/infra.leapp/actions) [![Lint](https://github.com/redhat-cop/infra.leapp/workflows/Yaml%20and%20Ansible%20Lint/badge.svg?event=push)](https://github.com/redhat-cop/infra.leapp/actions) [![OpenSSF Best Practices](https://bestpractices.coreinfrastructure.org/projects/7438/badge)](https://bestpractices.coreinfrastructure.org/projects/7438)

<!-- [![Codecov](https://img.shields.io/codecov/c/github/redhat-cop/infra.leapp)](https://codecov.io/gh/redhat-cop/infra.leapp) -->

## Overview

This collection provides Ansible roles you can use to perform RHEL in-place upgrades using the Leapp framework. Successfully executing upgrades at scale across a large RHEL estate demands a customized end-to-end automation approach tailored to meet the requirements of your enterprise environment. Use these roles as the foundation of your RHEL in-place upgrade automation solution.

## Roles

These are the roles included in the collection. Follow the links below to see the detailed documentation and example playbooks for each role.

- [`analysis`](./roles/analysis/) - executes the Leapp pre-upgrade phase
- [`common`](./roles/common/) - used for local logging, mutex locking, and common vars
- [`parse_leapp_report`](./roles/parse_leapp_report/) - reads pre-upgrade results and checks for inhibitors
- [`upgrade`](./roles/upgrade/) - executes the Leapp OS upgrade

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

Please open a [new issue](https://github.com/redhat-cop/infra.leapp/issues/new/choose) for any bugs or security vulnerabilities you may encounter. We also invite you to open an issue if you have ideas on how we can improve the solution or want to make a suggestion for enhancment.

## More information

This Ansible collection is just one building block of our larger initiative to make RHEL in-place upgrade automation that works at enterprise scale. Learn more about our end-to-end approach for automating RHEL in-place upgrades at this [blog post](https://red.ht/bobblog).

## Release notes

See the [changelog](https://github.com/redhat-cop/infra.leapp/tree/main/CHANGELOG.rst).

## Licensing

MIT

See [LICENSE](LICENSE) to see the full text.
