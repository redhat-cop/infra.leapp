# Ansible Leapp Collection

[![CI](https://github.com/redhat-cop/infra.leapp/workflows/CI/badge.svg?query=event%3Apush)](https://github.com/redhat-cop/infra.leapp/actions) [![Lint](https://github.com/redhat-cop/infra.leapp/workflows/Yaml%20and%20Ansible%20Lint/badge.svg?query=event%3Apush)](https://github.com/redhat-cop/infra.leapp/actions) [![OpenSSF Best Practices](https://bestpractices.coreinfrastructure.org/projects/7438/badge)](https://bestpractices.coreinfrastructure.org/projects/7438)

<!-- [![Codecov](https://img.shields.io/codecov/c/github/redhat-cop/infra.leapp)](https://codecov.io/gh/redhat-cop/infra.leapp) -->

## Description

This collection provides Ansible roles for **RHEL in-place upgrades** using the Leapp framework (and, for older paths, Preupgrade Assistant and Red Hat Upgrade Tool). Running upgrades at scale across a large estate needs automation tailored to your environment; these roles are intended as the **foundation** for that solution.

**Who should use it:** Platform engineers, automation teams, and anyone automating supported RHEL upgrade paths with Ansible.

**What you can do:** Run pre-upgrade analysis, perform upgrades, and assist with remediation using consistent, parameterized roles.

### Roles

These roles are included in the collection. Each has a `README` and examples under its directory.

- `roles/analysis` — Leapp pre-upgrade phase (or Preupgrade Assistant on RHEL 6)
- `roles/remediate` — Help remediate systems after pre-upgrade
- `roles/upgrade` — Leapp OS upgrade (or Red Hat Upgrade Tool on RHEL 6)

### Supported RHEL upgrade paths

The collection supports in-place upgrades for the following paths (using Preupgrade Assistant and Red Hat Upgrade Tool, or Leapp as indicated):

- RHEL 6 to RHEL 7 (Preupgrade Assistant and Red Hat Upgrade Tool)
- RHEL 7 to RHEL 8 (Leapp)
- RHEL 8 to RHEL 9 (Leapp)
- RHEL 9 to RHEL 10 (Leapp)

> [!IMPORTANT]
> Not every path may be supported in the same way by Red Hat product support. See [RHEL In-place upgrade Support Policy](https://access.redhat.com/articles/7102732) and [Supported in-place upgrade paths for Red Hat Enterprise Linux](https://access.redhat.com/articles/4263361) for current guidance.

The roles have been used in varied environments: on-prem bare metal and VMs with packages from Red Hat CDN, Satellite content views, or internal mirrors (including disconnected layouts). RHEL on Amazon EC2 with BYOS CDN or pay-as-you-go RHUI has been tested; other public clouds are generally feasible when you set the documented role variables for your subscription and repos.

Example playbooks live under `playbooks/`.

### Out of scope

The `upgrade` role does **not** upgrade third-party products or non-RHEL package sets. For a full stack upgrade you may need extra automation for agents, clustered storage, databases, and similar (for example Veritas InfoScale clustering or [SAP HANA on RHEL](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux_for_sap_solutions/)). Packages from non-RHEL repos (for example [Red Hat Software Collections](https://access.redhat.com/support/policy/updates/rhscl), [EPEL](https://docs.fedoraproject.org/en-US/epel/), [RPM Fusion](https://rpmfusion.org/)) are not handled by the role as RHEL content.

Many workloads remain compatible after an in-place upgrade under [RHEL application compatibility](https://access.redhat.com/articles/rhel8-abi-compatibility) guidance; validate in non-production before production cutovers.

## Requirements

- **Ansible / ansible-core:** Must satisfy `requires_ansible` in `meta/runtime.yml`. Use an ansible-core and Automation Platform release that meets that constraint and your organization’s support policy.
- **Python:** Use the Python versions supported for your control node or execution environment together with your chosen ansible-core (see [Ansible Automation Platform](https://access.redhat.com/documentation/en-us/red_hat_ansible_automation_platform/) documentation).
- **Collection dependencies:** This collection requires `fedora.linux_system_roles`.

> [!IMPORTANT]
> Managed-node compatibility depends on the Ansible version on the controller. See [Ansible Core compatibility with RHEL 7 and RHEL 6 managed nodes](https://access.redhat.com/articles/6977724) and [Red Hat Ansible Automation Platform life cycle](https://access.redhat.com/support/policy/updates/ansible-automation-platform). Ensure the combination of `meta/runtime.yml`, your Ansible version, and target OS versions is valid for your scenario.

## Installation

Ansible or ansible-core is supplied with Ansible Automation Platform and its execution environments; this section describes **installing the collection** (for example from automation hub or Ansible Galaxy) using the CLI.

Before using this collection, install it with the Ansible Galaxy command-line tool:

```
ansible-galaxy collection install infra.leapp
```

You can also list it in a `requirements.yml` and install with `ansible-galaxy collection install -r requirements.yml`:

```yaml
collections:
  - name: infra.leapp
  - name: fedora.linux_system_roles
```

Use `redhat.rhel_system_roles` where documented in role READMEs if that fits your environment instead of `fedora.linux_system_roles`.

To upgrade the collection to the latest published version:

```
ansible-galaxy collection install infra.leapp --upgrade
```

To install a specific version (example: `1.0.0`):

```
ansible-galaxy collection install infra.leapp:==1.0.0
```

See [Using Ansible collections](https://docs.ansible.com/ansible/devel/user_guide/collections_using.html) for more details.

**After installation:** Configure inventory, credentials, and subscription/repo access for managed nodes as required by the roles you run. Authentication follows your standard Ansible patterns (for example `become`, SSH keys, vault secrets). If you install collections alongside the `ansible` PyPI package, collection versions are not upgraded when you upgrade that package alone—re-run `ansible-galaxy collection install` with `--upgrade` when you want newer collection releases.

## Use cases

1. **Enterprise-wide analysis before upgrades** — Run the `analysis` role across groups of hosts to collect Leapp (or Preupgrade Assistant) reports, feed results into change management, and only promote systems that pass checks to an upgrade wave.

2. **Phased in-place upgrades** — Use the `upgrade` role in rolling batches (maintenance windows, load-balanced sets, or cluster nodes) so you can pause, verify applications, and continue with the same automation across RHEL 7→8, 8→9, or 9→10.

3. **Satellite or disconnected RHEL** — Point role variables at Satellite content views or internal mirrors so upgrades use approved baselines without direct internet access from managed nodes.

4. **Public cloud RHEL** — Automate upgrades on cloud instances (for example EC2 with RHUI or BYOS) by aligning repository and subscription variables with your billing and entitlement model.

5. **Remediation workflows** — Combine `remediate` with analysis output to address inhibitors or configuration drift before re-running analysis or upgrade playbooks.

## Testing

Continuous integration runs on pushes to the repository (workflows linked in the badges at the top of this file), including Ansible/YAML lint checks. Playbook-oriented testing is also driven via [tmt](https://tmt.readthedocs.io/) plans under `plans/`, exercising roles against managed RHEL images where that CI is configured.

**Known constraints:** Match controller Ansible and Python to your targets and to `meta/runtime.yml` (see **Requirements**). Third-party and non-RHEL software may need separate automation (see **Out of scope**). Always validate in your own test tiers before production.

## Contributing

We are a fledgling community and welcome any new contributors. Get started by opening an issue or pull request. Refer to `CONTRIBUTING.md` for more information.

## Support

This collection is **Red Hat Ansible Certified Content**, distributed on **Red Hat Ansible Automation Hub** under the **`redhat`** namespace for use with **Red Hat Ansible Automation Platform**.

**If you have a Red Hat subscription:** use **Red Hat Customer Support** ([access.redhat.com/support](https://access.redhat.com/support/)) for Ansible Automation Platform and subscription assistance. For problems with the **certified** collection build on Automation Hub, use the **Create issue** button at the top right of this collection’s page in the hub so your case is handled under your entitlement.

## Release Notes and Roadmap

- **Release notes / changelog:** `CHANGELOG.rst` and `changelogs/changelog.yaml`.
- **Roadmap:** No separate public roadmap document; follow the changelog and repository activity for upcoming changes.

## Related information

- [Using Ansible collections](https://docs.ansible.com/ansible/devel/user_guide/collections_using.html)
- [RHEL In-place upgrade Support Policy](https://access.redhat.com/articles/7102732)
- [Supported in-place upgrade paths for Red Hat Enterprise Linux](https://access.redhat.com/articles/4263361)
- [Ansible Core compatibility with RHEL 7 and RHEL 6 managed nodes](https://access.redhat.com/articles/6977724)
- Broader context on RHEL in-place upgrade automation at scale: [blog post](https://red.ht/bobblog)

## License Information

This collection is published under the **MIT** license. The full text is in the `LICENSE` file.
