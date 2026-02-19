# Common role

The `common` role is used to manage log file found on the system that can help with debugging playbooks that include the `analysis` or `upgrade` roles.

This role also implements a mutex locking mechanism that protects against accidentally running simultaneous playbook jobs on the same host.

Additionally this role can be used to set common variables used by both `analysis` and `upgrade`.

This is a common role included by the `analysis` and `upgrade` roles. It does not need to be explicitly included in your playbook.

## Requirements

Define job_name in the import as seen below.

## Role variables

### Role variables used with parse_leapp_report.yml

**NOTE:** `leapp_result_filename` is **REQUIRED**.  The other leapp_result_filename* parameters will be derived from it if not explicitly given.

| Name                         | Type    | Default value                                 | Description |
|------------------------------|---------|-----------------------------------------------|-------------|
| leapp_result_filename        | String  | "/var/log/leapp/leapp-report.txt"             | REQUIRED - Path of the Leapp pre-upgrade report file. |
| leapp_result_filename_prefix | String  | "/var/log/leapp/leapp-report"                 | The path used and the prefix name setting for the Leapp report. |
| leapp_result_filename_json   | String  | "{{ leapp_result_filename_prefix }}.json"     | JSON filename using the selected "leapp_result_filename_prefix". |
| leapp_result_fact_cacheable  | Boolean | false                                         | Allow the results from parsing the LEAPP report be cacheable (primarily for AAP). |
| leapp_high_sev_as_inhibitors | Boolean | false                                         | Treat all high severity findings as inhibitors. |

### Variables exported by parse_leapp_report.yml

`register` means it is the result of a `command` written to a `register` variable and so has `rc`, `stdout`, etc.

| Name               | Type     | Description |
|--------------------|----------|-------------|
| leapp_report_txt   | List     | List of lines from the text report. |
| leapp_report_json  | Dict     | The JSON report returned as a dict object. |
| leapp_inhibitors   | List     | Raw list of inhibitors. |
| results_inhibitors | Register | Result of parsing out inhibitors from leapp_result_filename. |
| results_errors     | Register | Result of parsing out high errors from leapp_result_filename. |
| upgrade_inhibited  | Boolean  | true if there are inhibitors blocking upgrade. |

### How to use parse_leapp_report.yml

```yml
- name: MYTASKNAME | Run parse_leapp_report for some reason
  ansible.builtin.include_role:
    name: infra.leapp.common
    tasks_from: parse_leapp_report.yml
  vars:
    leapp_result_filename: /path/to/something   # if not already defined previously
    leapp_result_fact_cacheable: true  # if not already defined previously

- name: MYTASKNAME | Display inhibitors
  ansible.builtin.debug:
    var: results_inhibitors.stdout_lines
  when: results_inhibitors.stdout_lines | length > 0
```

## Logging

Logs will accumulate in the directory referenced by `leapp_log_file`, with a suffixed datestamp upon completion.

If a log file exists during execution of this role (without suffixed datestamp), execution will terminate as there is an analysis job running already.

Logs will not survive a rollback. They need to be removed off the system prior to a snapshot revert.

## Authors

Bob Mader, Scott Vick, Mike Savage, Jeffrey Cutter, David Danielsson

## License

MIT
