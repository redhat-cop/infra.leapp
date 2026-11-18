"""Unit tests for the leapp_consolidated_report module's report handling."""

import html
import json

import pytest

from ansible_collections.infra.leapp.plugins.modules.leapp_consolidated_report import (
    build_payload,
    collect_hosts,
    combine_hostname,
    consolidate,
    escape_html,
    find_reports,
    merge_findings,
    order_findings,
    parse_report,
    render_html,
    render_remediation,
)


def entry(**overrides):
    """A minimal leapp report entry, overridable per test."""
    base = {
        "title": "cgroups-v1 enabled on the system",
        "hostname": "host01.example.com",
        "severity": "high",
        "groups": ["boot"],
        "key": "aaaa",
    }
    base.update(overrides)
    return base


def report(*entries):
    return {"leapp_run_id": "test", "entries": list(entries)}


def write_report(directory, hostname, content):
    """Write content into the <hostname>/leapp-report.json layout fetch produces."""
    host_dir = directory / hostname
    host_dir.mkdir()
    path = host_dir / "leapp-report.json"
    path.write_text(content if isinstance(content, str) else json.dumps(content))
    return str(path)


# ---------------------------------------------------------------------------
# escape_html - this is the XSS boundary, so it is checked against the stdlib
# ---------------------------------------------------------------------------

class TestEscapeHtml:
    @pytest.mark.parametrize("value", [
        "",
        "plain text",
        "<img src=x onerror=alert(1)>",
        "a & b",
        "quote\" and 'apostrophe'",
        "&lt;already escaped&gt;",
        "<>&\"'",
        "héllo wörld",
    ])
    def test_matches_stdlib(self, value):
        assert escape_html(value) == html.escape(value, quote=True)

    def test_ampersand_is_escaped_first(self):
        # Escaping < before & would produce &amp;lt; from a literal <
        assert escape_html("<") == "&lt;"
        assert escape_html("&lt;") == "&amp;lt;"

    def test_non_string_input(self):
        assert escape_html(7) == "7"
        assert escape_html(None) == "None"


# ---------------------------------------------------------------------------
# combine_hostname - pairs the inventory hostname with the report's own hostname
# ---------------------------------------------------------------------------

class TestCombineHostname:
    def test_matching_names_are_shown_once(self):
        assert combine_hostname("host01.example.com", "host01.example.com") == "host01.example.com"

    def test_differing_names_show_both(self):
        assert combine_hostname("host01", "host01.prod.example.com") == "host01 (host01.prod.example.com)"

    @pytest.mark.parametrize("report_hostname", [None, ""])
    def test_missing_report_hostname_falls_back_to_inventory_name(self, report_hostname):
        assert combine_hostname("host01", report_hostname) == "host01"


# ---------------------------------------------------------------------------
# parse_report
# ---------------------------------------------------------------------------

class TestParseReport:
    def test_groups_by_severity_and_key(self):
        findings = parse_report(report(entry()), "host01.example.com")
        assert list(findings) == ["high"]
        assert findings["high"]["aaaa"]["title"] == "cgroups-v1 enabled on the system"
        assert findings["high"]["aaaa"]["hostnames"] == ["host01.example.com"]

    def test_differing_inventory_and_report_hostnames_are_combined(self):
        findings = parse_report(report(entry(hostname="host01.prod.example.com")), "host01")
        assert findings["high"]["aaaa"]["hostnames"] == ["host01 (host01.prod.example.com)"]

    def test_inhibitor_group_overrides_severity(self):
        findings = parse_report(report(entry(groups=["inhibitor", "boot"])), "fallback")
        assert list(findings) == ["inhibitor"]

    def test_inhibitor_flag_from_old_reports(self):
        raw = entry(flags=["inhibitor"])
        del raw["groups"]
        findings = parse_report(report(raw), "fallback")
        assert list(findings) == ["inhibitor"]

    def test_title_is_used_when_key_is_absent(self):
        raw = entry()
        del raw["key"]
        findings = parse_report(report(raw), "fallback")
        assert list(findings["high"]) == ["cgroups-v1 enabled on the system"]

    @pytest.mark.parametrize("hostname", [None, ""])
    def test_directory_name_is_used_when_hostname_is_missing(self, hostname):
        raw = entry(hostname=hostname)
        if hostname is None:
            del raw["hostname"]
        findings = parse_report(report(raw), "host-from-directory")
        assert findings["high"]["aaaa"]["hostnames"] == ["host-from-directory"]

    def test_missing_severity_defaults_to_info(self):
        raw = entry()
        del raw["severity"]
        findings = parse_report(report(raw), "fallback")
        assert list(findings) == ["info"]

    def test_remediations_are_collected(self):
        raw = entry(detail={"remediations": [{"type": "hint", "context": "do the thing"}]})
        findings = parse_report(report(raw), "fallback")
        assert findings["high"]["aaaa"]["remediations"] == [{"type": "hint", "context": "do the thing"}]

    def test_duplicate_entries_in_one_report_are_not_duplicated(self):
        findings = parse_report(report(entry(), entry()), "host01.example.com")
        assert findings["high"]["aaaa"]["hostnames"] == ["host01.example.com"]

    def test_missing_entries_key_raises(self):
        with pytest.raises(KeyError):
            parse_report({"leapp_run_id": "test"}, "fallback")


# ---------------------------------------------------------------------------
# merge_findings - the regression that silently dropped per-host remediations
# ---------------------------------------------------------------------------

class TestMergeFindings:
    def test_hosts_are_collected_under_a_shared_key(self):
        first = parse_report(report(entry(hostname="a")), "a")
        second = parse_report(report(entry(hostname="b")), "b")
        merged = merge_findings([first, second])
        assert merged["high"]["aaaa"]["hostnames"] == ["a", "b"]

    def test_differing_remediations_are_unioned_not_overwritten(self):
        hint = {"type": "hint", "context": "edit the kernel command line"}
        command = {"type": "command", "context": ["grubby", "--update-kernel=ALL"]}
        first = parse_report(report(entry(hostname="a", detail={"remediations": [hint]})), "a")
        second = parse_report(report(entry(hostname="b", detail={"remediations": [command]})), "b")

        merged = merge_findings([first, second])
        assert merged["high"]["aaaa"]["remediations"] == [hint, command]

        # Merging is order independent, so output does not depend on directory listing order
        reversed_merge = merge_findings([second, first])
        assert reversed_merge["high"]["aaaa"]["remediations"] == [command, hint]
        assert sorted(reversed_merge["high"]["aaaa"]["hostnames"]) == ["a", "b"]

    def test_identical_remediations_are_deduplicated(self):
        hint = {"type": "hint", "context": "same advice"}
        first = parse_report(report(entry(hostname="a", detail={"remediations": [hint]})), "a")
        second = parse_report(report(entry(hostname="b", detail={"remediations": [hint]})), "b")
        merged = merge_findings([first, second])
        assert merged["high"]["aaaa"]["remediations"] == [hint]

    def test_empty_input(self):
        assert merge_findings([]) == {}


# ---------------------------------------------------------------------------
# order_findings
# ---------------------------------------------------------------------------

class TestOrderFindings:
    def test_severities_are_ordered_by_urgency(self):
        merged = {
            "info": {"k1": {"title": "t", "hostnames": [], "remediations": []}},
            "inhibitor": {"k2": {"title": "t", "hostnames": [], "remediations": []}},
            "medium": {"k3": {"title": "t", "hostnames": [], "remediations": []}},
        }
        assert list(order_findings(merged)) == ["inhibitor", "medium", "info"]

    def test_unknown_severity_is_dropped(self):
        merged = {"bogus": {"k": {"title": "t", "hostnames": [], "remediations": []}}}
        assert order_findings(merged) == {}

    def test_entries_are_sorted_by_title_and_hostnames_alphabetically(self):
        merged = {
            "high": {
                "k2": {"title": "Zebra", "hostnames": ["c", "a"], "remediations": []},
                "k1": {"title": "Apple", "hostnames": ["b"], "remediations": []},
            }
        }
        ordered = order_findings(merged)
        assert list(ordered["high"]) == ["k1", "k2"]
        assert ordered["high"]["k2"]["hostnames"] == ["a", "c"]

    def test_equal_titles_fall_back_to_key_for_stable_order(self):
        merged = {
            "high": {
                "kb": {"title": "same", "hostnames": [], "remediations": []},
                "ka": {"title": "same", "hostnames": [], "remediations": []},
            }
        }
        assert list(order_findings(merged)["high"]) == ["ka", "kb"]


class TestCollectHosts:
    def test_hosts_are_deduplicated_and_sorted(self):
        ordered = {
            "high": {"k1": {"title": "t", "hostnames": ["b", "a"], "remediations": []}},
            "info": {"k2": {"title": "t", "hostnames": ["a"], "remediations": []}},
        }
        assert collect_hosts(ordered) == ["a", "b"]

    def test_no_findings(self):
        assert collect_hosts({}) == []


# ---------------------------------------------------------------------------
# find_reports
# ---------------------------------------------------------------------------

class TestFindReports:
    def test_finds_one_report_per_host_directory(self, tmp_path):
        write_report(tmp_path, "b.example.com", report(entry()))
        write_report(tmp_path, "a.example.com", report(entry()))
        (tmp_path / "consolidated-analysis.json").write_text("{}")
        (tmp_path / "empty-host").mkdir()

        found = find_reports(str(tmp_path), "leapp-report.json")
        assert [path.split("/")[-2] for path in found] == ["a.example.com", "b.example.com"]

    def test_empty_directory(self, tmp_path):
        assert find_reports(str(tmp_path), "leapp-report.json") == []

    def test_honours_a_custom_filename(self, tmp_path):
        host_dir = tmp_path / "host"
        host_dir.mkdir()
        (host_dir / "other.json").write_text("{}")
        assert find_reports(str(tmp_path), "leapp-report.json") == []
        assert len(find_reports(str(tmp_path), "other.json")) == 1


# ---------------------------------------------------------------------------
# consolidate - the end to end behaviour the role depends on
# ---------------------------------------------------------------------------

class TestConsolidate:
    def test_all_reports_valid(self, tmp_path):
        first = write_report(tmp_path, "a", report(entry(hostname="a")))
        second = write_report(tmp_path, "b", report(entry(hostname="b", groups=["inhibitor"])))

        payload, analyzed, skipped = consolidate([(first, "a"), (second, "b")])

        assert sorted(analyzed) == sorted([first, second])
        assert skipped == []
        assert payload["metadata"]["complete"] is True
        assert payload["metadata"]["hosts"] == ["a", "b"]
        assert list(payload["findings"]) == ["inhibitor", "high"]

    def test_unparsable_report_is_skipped_not_fatal(self, tmp_path):
        good = write_report(tmp_path, "good", report(entry(hostname="good")))
        bad = write_report(tmp_path, "bad", '{"entries": [')

        payload, analyzed, skipped = consolidate([(bad, "bad"), (good, "good")])

        assert analyzed == [good]
        assert len(skipped) == 1
        assert skipped[0]["path"] == bad
        assert skipped[0]["error"]
        # The good host is still reported
        assert payload["metadata"]["hosts"] == ["good"]
        assert payload["metadata"]["complete"] is False
        assert payload["metadata"]["reports_skipped"] == 1

    def test_report_without_entries_is_skipped(self, tmp_path):
        bad = write_report(tmp_path, "bad", {"leapp_run_id": "x"})
        payload, analyzed, skipped = consolidate([(bad, "bad")])
        assert analyzed == []
        assert payload["findings"] == {}
        assert "KeyError" in skipped[0]["error"]

    def test_missing_file_is_skipped(self, tmp_path):
        missing = str(tmp_path / "nope" / "leapp-report.json")
        payload, analyzed, skipped = consolidate([(missing, "nope")])
        assert analyzed == []
        assert payload["findings"] == {}
        assert len(skipped) == 1

    def test_every_report_unparsable(self, tmp_path):
        bad = write_report(tmp_path, "bad", "not json at all")
        payload, analyzed, skipped = consolidate([(bad, "bad")])
        assert analyzed == []
        assert len(skipped) == 1
        assert payload["findings"] == {}
        assert payload["metadata"]["complete"] is False

    def test_no_reports(self):
        payload, analyzed, skipped = consolidate([])
        assert (analyzed, skipped) == ([], [])
        assert payload["findings"] == {}
        # Nothing failed, so an empty input set is formally complete. The module refuses to
        # write a report in that case, which is what stops it reading as "no findings".
        assert payload["metadata"]["complete"] is True

    def test_output_is_deterministic(self, tmp_path):
        first = write_report(tmp_path, "a", report(entry(hostname="a")))
        second = write_report(tmp_path, "b", report(entry(hostname="b")))
        forward = consolidate([(first, "a"), (second, "b")])[0]
        backward = consolidate([(second, "b"), (first, "a")])[0]
        assert json.dumps(forward) == json.dumps(backward)


# ---------------------------------------------------------------------------
# render_remediation / render_html
# ---------------------------------------------------------------------------

class TestRenderRemediation:
    def test_hint(self):
        assert render_remediation({"type": "hint", "context": "do it"}) == "do it"

    def test_playbook(self):
        rendered = render_remediation({"type": "playbook", "context": "/tmp/fix.yml"})
        assert rendered == "Ansible playbook: <code>/tmp/fix.yml</code>"

    def test_command_list_is_joined(self):
        rendered = render_remediation({"type": "command", "context": ["yum", "install", "foo"]})
        assert rendered == "Command: <code>yum install foo</code>"

    def test_command_string_is_accepted(self):
        rendered = render_remediation({"type": "command", "context": "yum install foo"})
        assert rendered == "Command: <code>yum install foo</code>"

    def test_unknown_type_is_dropped(self):
        assert render_remediation({"type": "carrier-pigeon", "context": "x"}) is None

    def test_context_is_escaped(self):
        rendered = render_remediation({"type": "hint", "context": "<script>alert(1)</script>"})
        assert "<script>" not in rendered
        assert "&lt;script&gt;" in rendered


class TestRenderHtml:
    def build(self, entries, skipped=None):
        ordered = order_findings(merge_findings([entries]))
        skipped = skipped or []
        return build_payload(ordered, ["report.json"], skipped, collect_hosts(ordered))

    def test_hostnames_from_reports_are_escaped(self):
        hostile = "host<img src=x onerror=alert(1)>"
        payload = self.build(parse_report(report(entry(hostname=hostile)), "fallback"))
        rendered = render_html(payload)
        assert "<img src=x onerror=alert(1)>" not in rendered
        assert "host&lt;img src=x onerror=alert(1)&gt;" in rendered

    def test_titles_from_reports_are_escaped(self):
        payload = self.build(parse_report(report(entry(title="Use of <NFS> detected")), "fallback"))
        rendered = render_html(payload)
        assert "<NFS>" not in rendered
        assert "Use of &lt;NFS&gt; detected" in rendered

    def test_complete_report_has_no_warning_banner(self):
        payload = self.build(parse_report(report(entry()), "fallback"))
        rendered = render_html(payload)
        assert "This report is incomplete." not in rendered
        assert "<div class='incomplete'>" not in rendered
        assert "Covering 1 host(s) from 1 leapp report(s)." in rendered

    def test_incomplete_report_carries_a_banner_naming_the_bad_reports(self):
        payload = self.build(
            parse_report(report(entry()), "fallback"),
            skipped=[{"path": "/tmp/b/leapp-report.json", "error": "ValueError: broken"}],
        )
        rendered = render_html(payload)
        assert "This report is incomplete." in rendered
        assert "/tmp/b/leapp-report.json" in rendered
        assert "ValueError: broken" in rendered

    def test_skipped_paths_in_the_banner_are_escaped(self):
        payload = self.build(
            parse_report(report(entry()), "fallback"),
            skipped=[{"path": "<script>alert(1)</script>", "error": "<b>bad</b>"}],
        )
        rendered = render_html(payload)
        assert "<script>alert(1)</script>" not in rendered
        assert "<b>bad</b>" not in rendered

    def test_empty_findings_render_a_document(self):
        payload = build_payload({}, [], [], [])
        rendered = render_html(payload)
        assert rendered.startswith("<!DOCTYPE html>")
        assert "No findings were reported" in rendered

    def test_every_severity_in_the_legend_is_rendered(self):
        payload = build_payload({}, [], [], [])
        rendered = render_html(payload)
        for severity in ("Inhibitor", "High", "Medium", "Low", "Info"):
            assert "<td>{0}</td>".format(severity) in rendered
