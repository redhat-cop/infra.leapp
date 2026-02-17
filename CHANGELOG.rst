======================================
Ansible Leapp Collection Release Notes
======================================

.. contents:: Topics

v1.7.0
======

Minor Changes
-------------

- Add a remediation for the "Legacy network configuration found" inhibitor on the RHEL 9 to 10 upgrade path.
- Add a remediation for the "cgroups-v1 enabled on the system" inhibitor on the RHEL 9 to 10 upgrade path.
- Add a test for the cifs shares remediation.
- Add remediation role to move /usr directory to root partition when upgrading from RHEL 6 to 7.
- Add support for metalink field in custom repository definitions.
- Add test for unsupported kernel modules remediation.
- Add unit test for the leapp_old_postgresql_data remediation.
- Add warning about limited ongoing technical support for RHEL 6 upgrades.
- Do not output information about included custom repositories to avoid exposing URLs.
- Enable the remediate role for the RHEL 9 to 10 upgrade path.
- Ensure job_name is defined in all tests.
- Fix jinja warnings - use default variables for lists instead of jinja.
- Fix the post-upgrade on-demand update so that it will not execute if there are no post-upgrade repositories specified.
- Get default remediations by reading files from remediation tasks directory.
- Move common variables from analysis and upgrade into common.
- Move parse_leapp_report to common role instead of being a standalone role.
- Refactor code to remove some ansible-lint warnings and errors.
- Refactor kernel modules management into common manage_kernel_modules.yml task.
- Refactor remediations - extract common code into remediation main.yml - use conditionals/blocks instead of fail/rescue for flow control.
- Remove extra collection dependencies from readmes and collection-requirements.yml files.
- Remove leapp-upgrade package before each test to ensure role will install it.
- Remove leapp_inhibitors from vars file - it is a set_fact.
- Remove outdated (pre-upgrade) bootloader kernel entries.
- Remove roles/upgrade/meta/argument_spec.yml because it listed only a single outdated variable.
- Remove roles/upgrade/meta/collection-requirements.yml because meta/collection-requirements.yml should be on the collection root level only.
- Remove the dependency on the community.general.archive module.
- Remove the dependency on the community.general.rhsm_repository module.
- Remove the dependency on the community.general.yum_versionlock module.
- Rename leapp_infra_upgrade_system_roles_collection to a shorter and preciser leapp_system_roles_collection.
- Renamed Satellite activation key variables for clarity. ``leapp_satellite_activation_key_leapp`` is now ``leapp_satellite_activation_key``, ``leapp_satellite_activation_key_pre_leapp`` is now ``leapp_satellite_activation_key_post_analysis``, and ``leapp_satellite_activation_key_post_leapp`` is now ``leapp_satellite_activation_key_post_upgrade``. The old variables are now deprecated.
- Replace ansible.posix.mount module with the storage system role
- Replace ansible.posix.selinux module with the selinux system role
- Replace community.general.redhat_subscription module with the rhc system role.
- Set SR_ANSIBLE_INJECT_FACT_VARS to false by default in the CI.
- Updated remediate role to search for Leapp inhibitors by key first, with a fallback to title search. This improves search reliability when report titles are modified by Leapp.
- Variables for pre-upgrade and post-upgrade Satellite activation keys now default to the upgrade activation key, making them optional but recommended.
- Vendor community.general.modprobe module as infra.leapp.modprobe to remove dependency on community.general collection.
- refactor - handle INJECT_FACTS_AS_VARS=false by using ansible_facts instead
- sshd_remediation - remove when condition from sshd_remediation.yml which prevents the issue where the analysis role flags an inhibitor for sshd_config during a RHEL 8 to RHEL 9 upgrade but the remediation role skips it as it's not RHEL 7
- upgrade - Replaced the post_7_to_8_python_interpreter variable with leapp_post_upgrade_python_interpreter that affects Ansible interpreter used after a leapp upgrade to execute post-upgrade tasks. This change leaves the original variable functional, however, it is considered deprecated.

Deprecated Features
-------------------

- Rename variables of ALL roles in the collection to prefix them with __leapp_ to avoid conflicts with other roles. Older variables names are deprecated and will be removed in a future release.

Bugfixes
--------

- Add leapp_infra_upgrade_system_roles_collection to roles where it's applicable. Both to README and defaults/main.yml.
- Add parameter leapp_remediate_ssh_password_auth with default value true to remediate role.
- By default, this is true, which is the old default.
- Convert pipeline to list and use first to get first element for Ansible 2.9 support
- Ensure that unsupported kernel modules are unloaded before running leapp upgrade.
- Fix configuring local_repos_leapp yum repositories file. Previously, it was hardcoded to __leapp_repo_file regardless of whether file key was provided with one of local_repos_leapp
- Fixed Satellite registration handling.
- Fixed task responsible for removing package version locks that would fail if versionlock sub-command for dnf/yum was not available.
- Fixing CI workflow to rebuild collection for Automation Hub using redhat.rhel_system_roles collection as dependency.
- The default leapp_remediate_ssh_password_auth true might lock out your Ansible session and the play will
- The leapp_inhibitors variable is sometimes not defined
- The reboot module does use the `timeout` keyword.  Do not worry about 2.9 support.
- This parameter is used to determine whether to remediate SSH password authentication by setting PasswordAuthentication to no
- Use the split string method instead of the filter for 2.9 support.
- and PermitRootLogin to prohibit-password.
- fail if you are using Ansible with ssh and password authentication.
- fixed missing leapp package when upgrade role is run without running the analysis role first
- version locking dependencies for community.general to be less than 12"

v1.6.1
======

Minor Changes
-------------

- Introduce support for upgrading from RHEL 9 to 10.

Bugfixes
--------

- Adding required collections as dependencies to galaxy.yml file now that is working better
- Also adding all community.general modules to ansible-lint config to mock them so they do not error at import time

v1.6.0
======

Major Changes
-------------

- Add check for /boot/loader/entries for old RHEL version kernels to post upgrade to RHEL 8+ based upon current RHEL 8 to 9 upgrade documentation.
- Add removal of previous version RHEL packages as the default based upon current RHEL 8 to 9 upgrade documentation.
- Add update of rescue kernel if an old one is present based upon current RHEL 7 to 8 and 8 to 9 upgrade documentation.
- Implement post-upgrade release version set/unset for 'RHUI' upgrade type. By default, RHUI repositories are no longer version-locked after an upgrade and will be updated to the latest available content.

Minor Changes
-------------

- fixing readme's links so they work outside of github.

Bugfixes
--------

- fixed typo 'community.generalbuiltin.modprobe' to 'community.general.modprobe'

v1.5.1
======

Minor Changes
-------------

- Update release workflow to build changelog first

v1.5.0
======

Major Changes
-------------

- Added support for RHEL 7 -> 8 in the infra.leapp.remediate role
- Rewrote the remediate playbooks to use conditional logic and skip tasks that do not need to run

Minor Changes
-------------

- Added pam_tally2 remediation for RHEL 7
- Updated documentation in support of the extended remediate role
- Use community.general.modprobe in leapp_loaded_removed_kernel_drivers.yml remediation

v1.4.1
======

Minor Changes
-------------

- Add leapp_env_vars optional variable for defining leapp environment variables
- Add option to skip the initial update and reboot of the pre-upgraded server
- Add optional parameter for allowing caching of facts within AAP
- Consolidate analysis and upgrade custom-local-repos.yml task files to infra.leapp.common custom_local_repos.yml.
- Ensure leapp_upgrade_repositories.repo only has content from the current run of local_repos_leapp variable.
- Fix minor documentation typo for /etc/yum.repos.d
- Support optional gpgkey and repo_gpgcheck yum repository attributes
- Update example playbooks and variables from 8.8 to 8.10.
- Use infra.leapp.common custom_local_repos.yml to generate all repository files.

v1.4.0
======

Major Changes
-------------

- Change Leapp report schema from default (1.0.0) to new 1.2.0 for analysis and upgrade.

Minor Changes
-------------

- Added variables to the leapp_resume task to control task retries and delays.

Bugfixes
--------

- Run leapp with increased per-process file descriptor limit

v1.3.1
======

Minor Changes
-------------

- Allow treating all high severity findings as inhibitors
- Do not try to read analysis report when check_leapp_analysis_results is false.
- Fix check-inodes.sh script introduced error.
- Move fact capture from analysis to ensure that facts are representative of the system immediately before upgrade.

Bugfixes
--------

- Correct /var/log/leapp mode to 0700
- Fix regressions impacting upgrade role

v1.3.0
======

Major Changes
-------------

- Move collection dependencies from galaxy.yml to requirements.yml

Minor Changes
-------------

- Add infra_leapp_upgrade_system_roles_collection variable for specifying fedora.linux_system_roles or redhat.rhel_system_roles
- Allow listing known inhibitors for which remediations are available

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
