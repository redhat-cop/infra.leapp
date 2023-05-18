# Ansible Leapp Collection

[![CI](https://github.com/oamg/ansible-leapp/workflows/CI/badge.svg?event=push)](https://github.com/oamg/ansible-leapp/actions) [![Lint](https://github.com/oamg/ansible-leapp/workflows/Yaml%20and%20Ansible%20Lint/badge.svg?event=push)](https://github.com/oamg/ansible-leapp/actions)

<!-- [![Codecov](https://img.shields.io/codecov/c/github/oamg/ansible-leapp)](https://codecov.io/gh/oamg/ansible-leapp) -->

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

## Contributing

We are a fledgling community and welcome any new contributors. Get started by opening an issue or pull request. Refer to our [contribution guide](CONTRIBUTING.md) for more information.

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

## Release notes

See the [changelog](https://github.com/oamg/ansible-leapp/tree/main/CHANGELOG.rst).

## Roadmap

This Ansible collection is just one building block of our larger initiative to make RHEL in-place upgrade automation that works at enterprise scale. You can review our backlog at issues.redhat.com [here](https://issues.redhat.com/secure/RapidBoard.jspa?rapidView=16989&projectKey=RIPU&view=planning&issueLimit=100).

## More information

To learn more, contact Bob Mader <[bob@redhat.com](mailto:bob@redhat.com)>.

I'm [presenting](https://red.ht/bobtalk) at Red Hat Summit 2023, May 23-25 in Boston. Let's connect there!

## Licensing

MIT

See [LICENSE](LICENSE) to see the full text.
