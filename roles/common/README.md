# Logging

The `common` role is used to manage local log files that may help with debugging playbooks that include the `analysis` or `upgrade` roles. This role also implements a mutex locking mechanism that protects against accidentally running simultaneous playbook jobs on the same host.  Additionally this role provides common variables used by both `analysis` and `upgrade`.

> **TODO**: The logging capability of this role currently deals only with writing local log files, but could be later extended to support logging to an aggregator like Logstash or Splunk.

## Role variables

| Name                    | Default value         | Description                                         |
|-------------------------|-----------------------|-----------------------------------------------------|
| job_name                |                       | String to describe the job run.                     |
| log_directory           | "/var/log/ripu"       | Directory under which local log files will be written. This directory will be created is it is not already present. |
| log_file                | "{{ log_directory }}/ripu.log" | Local log filename. When a playbook job finishes, a timestamp suffix is appended to the end of the filename. |

## Example playbook

This is a common role included by the `analysis` and `upgrade` roles. It does not need to be explicitly included in your playbook.

## License

MIT
