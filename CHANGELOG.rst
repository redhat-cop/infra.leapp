======================================
Ansible Leapp Collection Release Notes
======================================

.. contents:: Topics

v1.2.0
======

Major Changes
-------------

- Add capturing of high (error) findings in analysis and upgrade.
- Add remediation role to remediate the system based on available remediation playbooks.
- Add support for using custom repositories for Leapp upgrades (leapp_upgrade_type == "custom").
- Improve reporting of inhibitors and high (error) findings
- added a boolean to allow users to skip RHSM unlock after leapp upgrade
- added a boolean to allow users to skip the dnf update after the upgrade has completed
- added a string to allow users to lock RHSM to a specified release after leapp upgrade

Minor Changes
-------------

- Add option to unload kernel modules prior to running leapp upgrade (kernel_modules_to_unload_before_upgrade).
- Add variable check_leapp_analysis_results which if set to false (true by default) allows to not check previous leapp analysis json results for inhibitors.
- Add variable for setting ansible_python_interpretor for RHEL 7 to 8 upgrades post upgrade post_7_to_8_python_interpreter.
- Capture leapp_inhibitors via set_stats for job artifacts.
- Fix analysis handler for Satellite registration (add conditional for if pre_leapp key is defined).
- For RHEL 6 upgrades, similarly capture inhibitor and high errors for not enough space for display in output and inclusion into set_stats for leapp_inhibitors.
- Variabilize reboot_timeout and upgrade_timeout.

Bugfixes
--------

- Remove obsolete versions from CI workflow and add newer ones

v1.1.4
======

Bugfixes
--------

- switched template to jinja vars for version upgrade verification

v1.1.3
======

Minor Changes
-------------

- Add the default variables async_timeout_maximum and async_poll_interval which configure the timeout and polling values respectively for asynchronous task execution. - Setting async/poll values as default vars will allow override timer values based on the end user's particular needs.
- Set the default to "disabled" in the selinux_mode default variable - This resolves an issue with a missing Ansible fact for servers where selinux is disabled

Bugfixes
--------

- Fixed common role to resolve incorrect timestamps in log files
- Fixed os_path is undefined error in upgrade role

v1.1.2
======

Bugfixes
--------

- Fixed shell tasks to use the correct variable "os_path"

v1.1.1
======

Minor Changes
-------------

- Added os_path variable
