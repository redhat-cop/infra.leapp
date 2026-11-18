#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright (c) 2026, Red Hat, Inc.
# GNU General Public License v3.0+ (see https://www.gnu.org/licenses/gpl-3.0.txt)
# SPDX-License-Identifier: GPL-3.0-or-later

from __future__ import absolute_import, division, print_function

__metaclass__ = type

DOCUMENTATION = r"""
module: leapp_consolidated_report
short_description: Consolidate the leapp reports of several hosts into one JSON and HTML report
version_added: 1.8.0
author:
  - Donat Szabo (@dszabo)
description:
  - "WARNING: Do not use this plugin directly! It is only for role internal use."
  - Reads the per-host C(leapp-report.json) files that the analysis role fetches to the
    controller and writes a single JSON and a single HTML report describing which hosts are
    affected by which leapp finding.
  - Findings are grouped by severity and then by report entry. Entries flagged as inhibitors are
    promoted to the C(inhibitor) severity regardless of the severity recorded by leapp.
  - Reports that cannot be parsed are skipped rather than aborting the run. The run is then
    marked incomplete, both in the module result and in the generated reports, so that an
    incomplete report is never mistaken for an absence of findings.
  - Each host is identified by its inventory hostname (the directory name under I(src)). When a
    report's own C(hostname) field differs from the inventory hostname, both are shown as
    C(inventory_hostname (report_hostname)), since operators act on the inventory name but the
    report's own hostname is what support cases and leapp logs reference.
  - This module runs on the controller and is normally used with C(delegate_to) and C(run_once).
  - Conceptually similar to the independent command-line tool
    U(https://github.com/oamg/leapp-report-analyzer), which inspired this feature. This module is
    an independent implementation, written for native Ansible integration (module return values,
    check mode, idempotent writes).
extends_documentation_fragment:
  - infra.leapp.attributes
attributes:
  check_mode:
    support: full
  diff_mode:
    support: none
options:
  src:
    description:
      - Directory holding the fetched reports, in the C(<hostname>/leapp-report.json) layout that
        M(ansible.builtin.fetch) produces.
    type: path
    required: true
  dest_json:
    description:
      - Path of the consolidated JSON report to write.
      - No file is written when no report is found under I(src).
    type: path
    required: true
  dest_html:
    description:
      - Path of the consolidated HTML report to write.
      - No file is written when no report is found under I(src).
    type: path
    required: true
  report_filename:
    description:
      - Name of the per-host report file to look for inside each directory under I(src).
    type: str
    default: leapp-report.json
"""

EXAMPLES = r"""
- name: Consolidate the fetched leapp reports
  infra.leapp.leapp_consolidated_report:
    src: /home/user/playbooks/ansible_leapp_analysis_logs_2026-11-11_09-00-00
    dest_json: /home/user/playbooks/ansible_leapp_analysis_logs_2026-11-11_09-00-00/consolidated-analysis.json
    dest_html: /home/user/playbooks/ansible_leapp_analysis_logs_2026-11-11_09-00-00/consolidated-analysis.html
  delegate_to: localhost
  become: false
  run_once: true
  register: leapp_consolidated

- name: Fail when any host is inhibited from upgrading
  ansible.builtin.assert:
    that: leapp_consolidated.severity_counts.inhibitor | default(0) == 0
"""

RETURN = r"""
complete:
  description:
    - Whether every report found under I(src) was parsed successfully.
    - When V(false), the generated reports do not cover all analyzed hosts and must not be read
      as a complete picture of the estate.
  returned: always
  type: bool
  sample: true
reports_found:
  description: Number of per-host reports found under I(src).
  returned: always
  type: int
  sample: 3
analyzed:
  description: Paths of the per-host reports that were parsed successfully.
  returned: always
  type: list
  elements: str
  sample: ["/tmp/reports/host01.example.com/leapp-report.json"]
skipped_reports:
  description:
    - The reports that could not be parsed, with the reason for each.
    - Named C(skipped_reports) rather than C(skipped) because Ansible reserves C(skipped) to
      mark a task as skipped.
  returned: always
  type: list
  elements: dict
  sample: [{"path": "/tmp/reports/host02.example.com/leapp-report.json", "error": "Expecting value: line 1 column 1"}]
hosts:
  description:
    - Sorted hostnames covered by the consolidated report.
    - Each entry is the inventory hostname, or C(inventory_hostname (report_hostname)) when the
      report's own hostname differs from it.
  returned: always
  type: list
  elements: str
  sample: ["host01", "host02 (host02.prod.example.com)"]
severity_counts:
  description: Number of distinct findings per severity.
  returned: always
  type: dict
  sample: {"inhibitor": 2, "info": 5}
dest_json:
  description: Path of the JSON report, or null when nothing was written.
  returned: always
  type: str
  sample: /tmp/reports/consolidated-analysis.json
dest_html:
  description: Path of the HTML report, or null when nothing was written.
  returned: always
  type: str
  sample: /tmp/reports/consolidated-analysis.html
"""

import json
import os

from ansible.module_utils.basic import AnsibleModule

# Severities ordered from most to least urgent. "inhibitor" is not a leapp severity, it is
# synthesised from the inhibitor flag because an inhibitor is what actually blocks an upgrade.
SEVERITY_ORDER = ("inhibitor", "high", "medium", "low", "info")

SEVERITY_LEGEND = (
    ("inhibitor", "#ff6666", "Blocks the upgrade. Leapp refuses to proceed until it is resolved."),
    ("high", "#ffcc66", "Very likely to leave the system in a deteriorated state after the upgrade."),
    ("medium", "#ffff66", "May affect both the system and the applications running on it."),
    ("low", "#ccff66", "Unlikely to affect the system, may affect applications running on it."),
    ("info", "#66ff66", "Informational, no expected impact on the system or its applications."),
)

# Minimal HTML escaping, equivalent to html.escape(text, quote=True). Implemented here rather
# than imported so that the module does not depend on the html module, which does not exist on
# the oldest Python versions ansible-core still accepts for modules. Ampersand must be first.
_HTML_REPLACEMENTS = (
    ("&", "&amp;"),
    ("<", "&lt;"),
    (">", "&gt;"),
    ('"', "&quot;"),
    ("'", "&#x27;"),
)


def escape_html(value):
    """Escape a value for safe inclusion in HTML text or a quoted attribute."""
    text = value if isinstance(value, str) else str(value)
    for char, replacement in _HTML_REPLACEMENTS:
        text = text.replace(char, replacement)
    return text


def find_reports(src, report_filename):
    """Return the sorted per-host report paths under src.

    The layout is the one ansible.builtin.fetch produces: one directory per inventory host,
    each holding the fetched report.
    """
    reports = []
    for entry in sorted(os.listdir(src)):
        candidate = os.path.join(src, entry, report_filename)
        if os.path.isfile(candidate):
            reports.append(candidate)
    return reports


def combine_hostname(inventory_hostname, report_hostname):
    """Combine the inventory hostname with the report's own hostname for display.

    inventory_hostname is the directory name chosen by ansible.builtin.fetch, i.e. the
    inventory_hostname of the Ansible play. report_hostname is whatever the leapp report itself
    recorded, which can be a short name, an FQDN, or missing entirely.

    Operators act on the inventory hostname, but the report's own hostname is what leapp logs and
    support cases reference, so both are shown whenever they differ.
    """
    if not report_hostname or report_hostname == inventory_hostname:
        return inventory_hostname
    return "{0} ({1})".format(inventory_hostname, report_hostname)


def parse_report(report_data, inventory_hostname):
    """Turn one leapp report into {severity: {key: entry}}.

    inventory_hostname is the directory name chosen by ansible.builtin.fetch. It is combined with
    each entry's own hostname field via combine_hostname().
    """
    findings = {}

    for entry in report_data["entries"]:
        title = entry["title"]
        severity = entry.get("severity", "info")
        hostname = combine_hostname(inventory_hostname, entry.get("hostname"))
        # Reports from leapp 1.0 carry "flags", newer ones carry "groups".
        flags = entry.get("flags", entry.get("groups", []))
        remediations = entry.get("detail", {}).get("remediations", [])
        # Older reports have no stable key, fall back to the title.
        key = entry.get("key", title)

        if "inhibitor" in flags:
            severity = "inhibitor"

        finding = findings.setdefault(severity, {}).setdefault(
            key, {"title": title, "hostnames": [], "remediations": []}
        )
        finding["title"] = title
        _add_unique(finding["hostnames"], [hostname])
        # Remediations are not guaranteed to be identical across hosts for the same key, so
        # collect the union instead of letting the last report parsed win.
        _add_unique(finding["remediations"], remediations)

    return findings


def _add_unique(target, items):
    """Append items that are not already present, preserving order.

    Remediations are dicts and therefore unhashable, so a set cannot be used.
    """
    for item in items:
        if item not in target:
            target.append(item)


def merge_findings(findings_list):
    """Merge the per-report findings of several hosts into one structure."""
    merged = {}
    for findings in findings_list:
        for severity, entries in findings.items():
            for key, entry in entries.items():
                target = merged.setdefault(severity, {}).setdefault(
                    key, {"title": entry["title"], "hostnames": [], "remediations": []}
                )
                target["title"] = entry["title"]
                _add_unique(target["hostnames"], entry["hostnames"])
                _add_unique(target["remediations"], entry["remediations"])
    return merged


def order_findings(merged):
    """Order severities by urgency, entries by title and hostnames alphabetically."""
    ordered = {}
    for severity in SEVERITY_ORDER:
        if severity not in merged:
            continue
        entries = merged[severity]
        ordered[severity] = dict(
            sorted(
                (
                    (
                        key,
                        {
                            "title": entry["title"],
                            "hostnames": sorted(entry["hostnames"]),
                            "remediations": entry["remediations"],
                        },
                    )
                    for key, entry in entries.items()
                ),
                key=lambda item: (item[1]["title"], item[0]),
            )
        )
    return ordered


def collect_hosts(ordered):
    """Return every hostname mentioned by the consolidated findings, sorted."""
    hosts = set()
    for entries in ordered.values():
        for entry in entries.values():
            hosts.update(entry["hostnames"])
    return sorted(hosts)


def build_payload(ordered, analyzed, skipped, hosts):
    """Build the JSON document.

    The coverage metadata travels with the artifact on purpose: the report outlives the run
    output, so a reader opening it later must be able to see that it is incomplete.
    """
    return {
        "metadata": {
            "complete": not skipped,
            "reports_analyzed": len(analyzed),
            "reports_skipped": len(skipped),
            "skipped_reports": skipped,
            "hosts": hosts,
        },
        "findings": ordered,
    }


def render_remediation(remediation):
    """Render one remediation as an HTML fragment, or None if it is not renderable."""
    remediation_type = remediation.get("type")
    context = remediation.get("context", "")

    if remediation_type == "hint":
        return escape_html(context)
    if remediation_type == "playbook":
        return "Ansible playbook: <code>{0}</code>".format(escape_html(context))
    if remediation_type == "command":
        if isinstance(context, (list, tuple)):
            context = " ".join(str(part) for part in context)
        return "Command: <code>{0}</code>".format(escape_html(context))
    return None


def render_html(payload):
    """Render the consolidated findings as a standalone HTML document.

    Every value taken from a report is escaped: hostnames, titles and remediations all
    originate on the managed nodes and are not trusted.
    """
    metadata = payload["metadata"]
    parts = [
        "<!DOCTYPE html>",
        "<html lang='en'>",
        "<head>",
        "<meta charset='UTF-8'>",
        "<title>Leapp consolidated analysis report</title>",
        "<style>",
        "body {font-family: sans-serif;}",
        "table {border-collapse: collapse; margin-bottom: 1.5em;}",
        "th, td {border: 1px solid black; padding: 5px; text-align: left; vertical-align: top;}",
        ".incomplete {border: 2px solid #cc0000; background-color: #ffe6e6; padding: 1em; margin-bottom: 1.5em;}",
        "</style>",
        "</head>",
        "<body>",
        "<h1>Leapp consolidated analysis report</h1>",
    ]

    if metadata["complete"]:
        parts.append(
            "<p>Covering {0} host(s) from {1} leapp report(s).</p>".format(
                len(metadata["hosts"]), metadata["reports_analyzed"]
            )
        )
    else:
        parts.append("<div class='incomplete'>")
        parts.append(
            "<strong>This report is incomplete.</strong> {0} of {1} leapp report(s) could not be"
            " parsed, so the hosts below are not the full estate. Do not read this report as"
            " &quot;no findings&quot;.".format(
                metadata["reports_skipped"],
                metadata["reports_skipped"] + metadata["reports_analyzed"],
            )
        )
        parts.append("<ul>")
        for skipped in metadata["skipped_reports"]:
            parts.append(
                "<li><code>{0}</code>: {1}</li>".format(
                    escape_html(skipped["path"]), escape_html(skipped["error"])
                )
            )
        parts.append("</ul>")
        parts.append("</div>")

    parts.append("<h2>Severity levels</h2>")
    parts.append("<table>")
    parts.append("<tr><th>Severity</th><th>Meaning</th></tr>")
    for severity, color, description in SEVERITY_LEGEND:
        parts.append(
            "<tr style='background-color: {0}'><td>{1}</td><td>{2}</td></tr>".format(
                color, severity.capitalize(), escape_html(description)
            )
        )
    parts.append("</table>")

    if not payload["findings"]:
        parts.append("<p>No findings were reported by the analyzed hosts.</p>")

    for severity, entries in payload["findings"].items():
        parts.append("<h2>{0}</h2>".format(escape_html(severity.capitalize())))
        parts.append("<table>")
        parts.append("<tr><th>Finding</th><th>Affected hosts</th><th>Remediations</th></tr>")
        for entry in entries.values():
            hostnames = ", ".join(escape_html(hostname) for hostname in entry["hostnames"])
            remediations = [render_remediation(item) for item in entry["remediations"]]
            parts.append(
                "<tr><td>{0}</td><td>{1}</td><td>{2}</td></tr>".format(
                    escape_html(entry["title"]),
                    hostnames,
                    "<br>".join(item for item in remediations if item),
                )
            )
        parts.append("</table>")

    parts.append("</body>")
    parts.append("</html>")
    return "\n".join(parts) + "\n"


def consolidate(reports):
    """Parse and merge the given (path, inventory_hostname) reports.

    Returns (payload, analyzed, skipped). A report that cannot be read or parsed is recorded in
    skipped rather than raising, so that one bad report does not hide every good one.
    """
    findings_list = []
    analyzed = []
    skipped = []

    for path, inventory_hostname in reports:
        try:
            with open(path, "r") as handle:
                report_data = json.load(handle)
            findings_list.append(parse_report(report_data, inventory_hostname))
        except (IOError, OSError, ValueError, KeyError, TypeError, AttributeError) as err:
            skipped.append({"path": path, "error": "{0}: {1}".format(type(err).__name__, err)})
            continue
        analyzed.append(path)

    ordered = order_findings(merge_findings(findings_list))
    payload = build_payload(ordered, analyzed, skipped, collect_hosts(ordered))
    return payload, analyzed, skipped


def read_if_exists(path):
    """Return the contents of path, or None when it cannot be read."""
    try:
        with open(path, "r") as handle:
            return handle.read()
    except (IOError, OSError):
        return None


def run_module():
    module = AnsibleModule(
        argument_spec=dict(
            src=dict(type="path", required=True),
            dest_json=dict(type="path", required=True),
            dest_html=dict(type="path", required=True),
            report_filename=dict(type="str", default="leapp-report.json"),
        ),
        supports_check_mode=True,
    )

    src = module.params["src"]
    dest_json = module.params["dest_json"]
    dest_html = module.params["dest_html"]

    if not os.path.isdir(src):
        module.fail_json(msg="The source directory {0} does not exist".format(src))

    try:
        report_paths = find_reports(src, module.params["report_filename"])
    except (IOError, OSError) as err:
        module.fail_json(msg="Could not list {0}: {1}".format(src, err))

    result = dict(
        complete=True,
        reports_found=len(report_paths),
        analyzed=[],
        skipped_reports=[],
        hosts=[],
        severity_counts={},
        dest_json=None,
        dest_html=None,
    )

    if not report_paths:
        # Not an error: an analysis run can legitimately produce no fetched reports, for example
        # when every host failed before leapp wrote one. Writing an empty report here would be
        # actively harmful, because it reads like a clean bill of health.
        module.warn(
            "No {0} found under {1}, no consolidated report was written".format(
                module.params["report_filename"], src
            )
        )
        module.exit_json(changed=False, **result)

    reports = [(path, os.path.basename(os.path.dirname(path))) for path in report_paths]
    payload, analyzed, skipped = consolidate(reports)

    result["complete"] = not skipped
    result["analyzed"] = analyzed
    result["skipped_reports"] = skipped
    result["hosts"] = payload["metadata"]["hosts"]
    result["severity_counts"] = dict(
        (severity, len(entries)) for severity, entries in payload["findings"].items()
    )
    result["dest_json"] = dest_json
    result["dest_html"] = dest_html

    for entry in skipped:
        module.warn("Could not parse {0}: {1}".format(entry["path"], entry["error"]))
    if skipped:
        module.warn(
            "The consolidated leapp report is INCOMPLETE, {0} of {1} reports could not be parsed."
            " Do not read it as an absence of findings.".format(len(skipped), len(report_paths))
        )

    json_content = json.dumps(payload, indent=2, sort_keys=False) + "\n"
    html_content = render_html(payload)

    changed = json_content != read_if_exists(dest_json) or html_content != read_if_exists(dest_html)

    if changed and not module.check_mode:
        for path, content in ((dest_json, json_content), (dest_html, html_content)):
            try:
                with open(path, "w") as handle:
                    handle.write(content)
            except (IOError, OSError) as err:
                module.fail_json(msg="Could not write {0}: {1}".format(path, err), **result)

    module.exit_json(changed=changed, **result)


def main():
    run_module()


if __name__ == "__main__":
    main()
