# Ansible Leapp Collection

[![CI](https://github.com/redhat-cop/infra.leapp/workflows/CI/badge.svg?query=event%3Apush)](https://github.com/redhat-cop/infra.leapp/actions) [![Lint](https://github.com/redhat-cop/infra.leapp/workflows/Yaml%20and%20Ansible%20Lint/badge.svg?query=event%3Apush)](https://github.com/redhat-cop/infra.leapp/actions) [![OpenSSF Best Practices](https://bestpractices.coreinfrastructure.org/projects/7438/badge)](https://bestpractices.coreinfrastructure.org/projects/7438)

<!-- [![Codecov](https://img.shields.io/codecov/c/github/redhat-cop/infra.leapp)](https://codecov.io/gh/redhat-cop/infra.leapp) -->

## Description

This collection provides Ansible roles for **RHEL in-place upgrades** using the Leapp framework (and, for older paths, Preupgrade Assistant and Red Hat Upgrade Tool). Running upgrades at scale across a large estate needs automation tailored to your environment; these roles are intended as the **foundation** for that solution.

**Who should use it:** Platform engineers, automation teams, and anyone automating supported RHEL upgrade paths with Ansible.

**What you can do:** Run pre-upgrade analysis, perform upgrades, and assist with remediation using consistent, parameterized roles.

### Roles

These roles are included in the collection. Each has a `README` and examples under its directory.

- [Analysis](roles/analysis) — runs the Leapp pre-upgrade (or Preupgrade Assistant on RHEL 6), which analyzes the target system for upgradability and flags potential issues.
- [Remediate](roles/remediate) — runs available remediations for issues found in the pre-upgrade report.
- [Upgrade](roles/upgrade) — runs the Leapp upgrade (or Red Hat Upgrade Tool on RHEL 6) on the target system and verifies that the upgrade was successful.

### Usage

The typical workflow for an in-place upgrade has three stages:

1. **Analyze** — run the `analysis` role against your hosts. It produces Leapp pre-upgrade reports and, on the controller, generates a `host_vars` directory and a `remediate.yml` playbook with suggested available fixes for inhibitors found on each host.
2. **Remediate** — review the produced pre-upgrade reports and generated `host_vars` files (each host gets a file listing available remediations), then run the generated `remediate.yml` playbook or write your own to resolve the inhibitors. After remediations are applied, run the `analysis` role again to see if all pre-upgrade inhibitors are resolved.
3. **Upgrade** — run the `upgrade` role. It checks for remaining inhibitors, performs the Leapp upgrade, reboots the host, and validates the result.

Example playbooks for each stage are in [`playbooks/`](playbooks/). Detailed documentation for upgrading with this ansible collection is also available in the official documentation for upgrading RHEL:
- [Upgrading from RHEL 8 to RHEL 9](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html-single/upgrading_from_rhel_8_to_rhel_9/index#upgrading-large-deployments-by-using-ansible-roles_upgrading-from-rhel-8-to-rhel-9)
- [Upgrading from RHEL 9 to RHEL 10](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html-single/upgrading_from_rhel_9_to_rhel_10/index#upgrading-large-deployments-by-using-ansible-roles)

[!IMPORTANT]
Not all inhibitors can be remediated by the remediate Ansible role, and either must instead be remediated manually or cannot be remediated.

### Supported RHEL upgrade paths

The collection supports in-place upgrades for the following paths (using Preupgrade Assistant and Red Hat Upgrade Tool, or Leapp as indicated):

- RHEL 6 to RHEL 7 (Preupgrade Assistant and Red Hat Upgrade Tool)
- RHEL 7 to RHEL 8 (Leapp)
- RHEL 8 to RHEL 9 (Leapp)
- RHEL 9 to RHEL 10 (Leapp)

> [!IMPORTANT]
> Not every path may be supported in the same way by Red Hat product support. See [RHEL In-place upgrade Support Policy](https://access.redhat.com/articles/7102732) and [Supported in-place upgrade paths for Red Hat Enterprise Linux](https://access.redhat.com/articles/4263361) for current guidance.

The roles have been used in varied environments: on-prem bare metal and VMs with packages from Red Hat CDN, Satellite content views, or internal mirrors (including disconnected layouts). RHEL on Amazon EC2 with BYOS CDN or pay-as-you-go RHUI has been tested; other public clouds are generally feasible when you set the documented role variables for your subscription and repos.

### Out of scope

The `upgrade` role does **not** upgrade third-party products or non-RHEL package sets. For a full stack upgrade you may need extra automation for agents, clustered storage, databases, and similar (for example Veritas InfoScale clustering or [SAP HANA on RHEL](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux_for_sap_solutions/)). Packages from non-RHEL repos (for example [Red Hat Software Collections](https://access.redhat.com/support/policy/updates/rhscl), [EPEL](https://docs.fedoraproject.org/en-US/epel/), [RPM Fusion](https://rpmfusion.org/)) are not handled by the role as RHEL content.

Many workloads remain compatible after an in-place upgrade under [RHEL application compatibility](https://access.redhat.com/articles/rhel8-abi-compatibility) guidance; validate in non-production before production cutovers.

## Requirements

- **Ansible / ansible-core:** Must satisfy `requires_ansible` in `meta/runtime.yml`. Use an ansible-core and Automation Platform release that meets that constraint and your organization's support policy.
- **Python:** Use the Python versions supported for your control node or execution environment together with your chosen ansible-core (see [Ansible Automation Platform](https://access.redhat.com/documentation/en-us/red_hat_ansible_automation_platform/) documentation).
- **Collection dependencies:** This collection requires `fedora.linux_system_roles` (or `redhat.rhel_system_roles` on RHEL systems).

> [!IMPORTANT]
> Managed-node compatibility depends on the Ansible version on the controller. See [Ansible Core compatibility with RHEL 7 and RHEL 6 managed nodes](https://access.redhat.com/articles/6977724) and [Red Hat Ansible Automation Platform life cycle](https://access.redhat.com/support/policy/updates/ansible-automation-platform). Ensure the combination of `meta/runtime.yml`, your Ansible version, and target OS versions is valid for your scenario.
> It is generally advised, when using control node with RHEL system, to use version of RHEL equal or higher than the target upgrade system of the managed nodes.

## Installation

Ansible or ansible-core is supplied with Ansible Automation Platform and its execution environments; this section describes how to **install the collection** using the CLI.

**Automation Hub** — The collection is published on [Automation Hub](https://console.redhat.com/ansible/automation-hub/collections/published/redhat/leapp/details) as `redhat.leapp`.

**RPM (RHEL 9+)** — The collection is packaged as `ansible-collection-redhat-leapp` in the Appstream repository and is referenced as `redhat.leapp`:

```bash
dnf install ansible-collection-redhat-leapp
```

**Ansible Galaxy:** — The collection is published on Galaxy as `infra.leapp`:

```bash
ansible-galaxy collection install infra.leapp
```

You can also list it in a `requirements.yml` and install with `ansible-galaxy collection install -r requirements.yml`:

```yaml
---
collections:
  - name: infra.leapp
    version: "*"
  - name: fedora.linux_system_roles # or redhat.rhel_system_roles see roles README for more details
    version: "*"
```

Use `redhat.rhel_system_roles` where documented in role READMEs if that fits your environment instead of `fedora.linux_system_roles`.

To upgrade the collection to the latest published version:

```bash
ansible-galaxy collection install infra.leapp --upgrade
```

To install a specific version (example: `1.0.0`):

```bash
ansible-galaxy collection install infra.leapp:==1.0.0
```

See [Using Ansible collections](https://docs.ansible.com/ansible/devel/user_guide/collections_using.html) for more details.

## Contributing

We are a fledgling community and welcome any new contributors. Get started by opening an issue or pull request. Refer to `CONTRIBUTING.md` for more information.

## Support

This collection is **Red Hat Ansible Certified Content**, distributed on **Red Hat Ansible Automation Hub** under the **`redhat`** namespace for use with **Red Hat Ansible Automation Platform**.

**If you have a Red Hat subscription:** use **Red Hat Customer Support** ([access.redhat.com/support](https://access.redhat.com/support/)) for Ansible Automation Platform and subscription assistance. For problems with the **certified** collection build on Automation Hub, use the **Create issue** button at the top right of this collection's page in the hub so your case is handled under your entitlement.

## Release Notes and Roadmap

- **Release notes / changelog:** `CHANGELOG.rst` and `changelogs/changelog.yaml`.
- **Roadmap:** No separate public roadmap document; follow the changelog and repository activity for upcoming changes.

## License Information

This collection is published under the **MIT** license. The full text is in the `LICENSE` file.
