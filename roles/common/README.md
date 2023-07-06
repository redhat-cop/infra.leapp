# Common role

The `common` role is used to manage local log files that may help with debugging playbooks that include the `analysis` or `upgrade` roles.

This role also implements a mutex locking mechanism that protects against accidentally running simultaneous playbook jobs on the same host.  

Additionally this role provides common variables used by both `analysis` and `upgrade`.

# Requirements 

Define job_name in the import as seen below

# Role variables
| Name                  | Type | Optional? | Default value | Description                                         |
|-----------------------|--------|-----------|---------------|-------------------------------------------------|
| job_name | String | No | The string describes the job run |
| log_directory | DirPath | Yes | "/var/log/ripu" | Directory under which local log files will be written. This directory will be created is it is not already present. |
| log_file | FilePath | Yes | "{{ log_directory }}/ripu.log" | Local log filename. When a playbook job finishes, a timestamp suffix is appended to the end of the specified filename. |

 # Logging 

Logs will accumulate in the directory referenced by logfile, with a suffixed datestamp upon completion.

If a log file exists during execution of this role (without suffixed datestamp), execution will terminate.

Logs will not survive a rollback. They need to be removed off the system prior to a snapshot revert.

# Example invocation
```
- name: Initialize lock, logging, and common vars
  ansible.builtin.import_role:
    name: infra.leapp.common
  vars:
    job_name: 'RIPU in-place OS upgrade'
```

This is a common role included by the `analysis` and `upgrade` roles. It does not need to be explicitly included in your playbook.

# Authors
Bob Mader, Scott Vick, Mike Savage, Jeffrey Cutter, David Danielsson

# License

MIT

**TODO**: The logging capability of this role currently deals only with writing local log files, but could be later extended to support logging to an aggregator like Logstash or Splunk in support rollbacks and dashboard initiatives.