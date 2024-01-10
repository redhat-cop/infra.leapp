======================================
Ansible Leapp Collection Release Notes
======================================

.. contents:: Topics


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
