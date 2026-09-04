"""Unit tests for the pure-Python RPM EVR comparison filter."""

import pytest
from ansible_collections.infra.leapp.plugins.filter.rpm_sort import (
    _rpmvercmp,
    _label_compare,
    _normalize_epoch,
    rpm_sort,
)


# ---------------------------------------------------------------------------
# _rpmvercmp — low-level version string comparison
# ---------------------------------------------------------------------------

class TestRpmvercmp:
    """Test cases derived from rpm-version(7) spec and real-world edge cases."""

    @pytest.mark.parametrize("a, b", [
        ("1.0", "1.0"),
        ("0001", "1"),       # leading zeros ignored
        ("abc", "abc"),
        ("", ""),
    ])
    def test_equal(self, a, b):
        assert _rpmvercmp(a, b) == 0

    @pytest.mark.parametrize("newer, older", [
        ("1.1", "1.0"),
        ("2.0", "1.999"),
        ("10", "9"),         # numeric, not lexicographic
        ("1.0.1", "1.0"),    # more segments = newer
        ("0.0", "0"),        # more segments = newer
    ])
    def test_numeric_ordering(self, newer, older):
        assert _rpmvercmp(newer, older) == 1
        assert _rpmvercmp(older, newer) == -1

    @pytest.mark.parametrize("newer, older", [
        ("b", "a"),
        ("add", "ab"),
    ])
    def test_alpha_ordering(self, newer, older):
        assert _rpmvercmp(newer, older) == 1
        assert _rpmvercmp(older, newer) == -1

    def test_numeric_beats_alpha(self):
        """Numeric segments are always newer than alpha segments."""
        assert _rpmvercmp("1", "a") == 1
        assert _rpmvercmp("a", "1") == -1

    @pytest.mark.parametrize("newer, older", [
        ("1.0", "1.0~beta1"),    # release > pre-release
        ("1.0~rc1", "1.0~beta1"),
    ])
    def test_tilde_pre_release(self, newer, older):
        assert _rpmvercmp(newer, older) == 1
        assert _rpmvercmp(older, newer) == -1

    @pytest.mark.parametrize("newer, older", [
        ("2.0^150825", "2.0"),     # snapshot > release
        ("2.0.1", "2.0^150825"),   # next release > snapshot
    ])
    def test_caret_post_release(self, newer, older):
        assert _rpmvercmp(newer, older) == 1
        assert _rpmvercmp(older, newer) == -1

    def test_leading_zeros_ignored(self):
        assert _rpmvercmp("001", "1") == 0
        assert _rpmvercmp("0100", "100") == 0


# ---------------------------------------------------------------------------
# _label_compare — full (epoch, version, release) comparison
# ---------------------------------------------------------------------------

class TestLabelCompare:

    def test_epoch_wins(self):
        assert _label_compare(("2", "1.0", "1"), ("1", "9.9", "99")) == 1

    def test_epoch_zero_default(self):
        assert _label_compare(("0", "1.0", "1"), ("0", "1.0", "1")) == 0

    def test_version_breaks_tie(self):
        assert _label_compare(("0", "2.0", "1"), ("0", "1.0", "1")) == 1

    def test_release_breaks_tie(self):
        assert _label_compare(("0", "1.0", "2"), ("0", "1.0", "1")) == 1

    def test_none_epoch_treated_as_zero(self):
        assert _label_compare(("", "1.0", "1"), ("0", "1.0", "1")) == 0

    def test_epoch_present_vs_absent(self):
        """A package with epoch=1 always beats one without an epoch."""
        with_epoch = ("1", "1.0", "1.el9")
        without_epoch = ("", "99.0", "1.el9")
        assert _label_compare(with_epoch, without_epoch) == 1
        assert _label_compare(without_epoch, with_epoch) == -1


# ---------------------------------------------------------------------------
# _normalize_epoch — handle the various epoch representations
# ---------------------------------------------------------------------------

class TestNormalizeEpoch:

    @pytest.mark.parametrize("value, expected", [
        (None, "0"),
        ("None", "0"),
        ("", "0"),
        (0, "0"),
        ("0", "0"),
        (1, "1"),
        ("1", "1"),
        (2, "2"),
        ("10", "10"),
    ])
    def test_normalize(self, value, expected):
        assert _normalize_epoch(value) == expected


# ---------------------------------------------------------------------------
# rpm_sort — epoch handling with package_facts-style dicts
# ---------------------------------------------------------------------------

class TestRpmSortEpoch:
    """Test epoch edge cases as returned by ansible_facts.packages.

    package_facts returns epoch as None when no explicit epoch is set,
    while packages with an epoch get an integer value.
    """

    def _pkg(self, version, release, epoch=None):
        return {"name": "glibc", "epoch": epoch,
                "version": version, "release": release, "arch": "x86_64"}

    def test_none_epoch_equals_zero_epoch(self):
        """epoch=None and epoch=0 are equivalent (both mean 'no epoch')."""
        pkg_none = self._pkg("2.28", "236.el8_9.12")
        pkg_zero = self._pkg("2.28", "236.el8_9.12", epoch=0)
        result = rpm_sort([pkg_none, pkg_zero])
        assert result[0]["epoch"] is None
        assert result[1]["epoch"] == 0

    def test_string_none_epoch(self):
        """epoch='None' (as returned by some package_facts) is treated as 0."""
        pkg_str_none = self._pkg("2.28", "236.el8", epoch="None")
        pkg_zero = self._pkg("2.28", "236.el8", epoch=0)
        pkg_real_none = self._pkg("2.28", "236.el8")
        result = rpm_sort([pkg_str_none, pkg_zero, pkg_real_none])
        assert all(
            r["version"] == "2.28" for r in result
        ), "all three should be equivalent epoch"

    def test_explicit_epoch_beats_no_epoch(self):
        """epoch=1 wins over epoch=None even with a lower version number."""
        old_version_with_epoch = self._pkg("1.0", "1.el9", epoch=1)
        new_version_no_epoch = self._pkg("99.0", "999.el9")
        result = rpm_sort([new_version_no_epoch, old_version_with_epoch])
        assert result[-1] == old_version_with_epoch, (
            "epoch=1 must sort newer than no epoch regardless of version"
        )

    def test_both_none_epoch_falls_through_to_version(self):
        """When both packages have epoch=None, version decides."""
        older = self._pkg("2.28", "236.el8")
        newer = self._pkg("2.34", "100.el9")
        result = rpm_sort([newer, older])
        assert result == [older, newer]

    def test_mixed_epoch_types_in_list(self):
        """Sorting works with a mix of None, 0, and integer epochs."""
        pkg_none = self._pkg("5.0", "1.el9")          # epoch=None -> 0
        pkg_zero = self._pkg("5.0", "1.el9", epoch=0)  # epoch=0 -> 0
        pkg_one = self._pkg("1.0", "1.el9", epoch=1)   # epoch=1
        pkg_two = self._pkg("0.1", "1.el9", epoch=2)   # epoch=2
        result = rpm_sort([pkg_two, pkg_none, pkg_one, pkg_zero])
        assert result[0]["epoch"] is None
        assert result[1]["epoch"] == 0
        assert result[2]["epoch"] == 1
        assert result[3]["epoch"] == 2


# ---------------------------------------------------------------------------
# The real-world kernel case that started this whole thing
# ---------------------------------------------------------------------------

class TestKernelSortCase:
    """553.157.1.el8_10 is newer than 553.el8_10 per RPM rules."""

    def test_z_stream_newer_than_base(self):
        result = _rpmvercmp("553.157.1.el8_10", "553.el8_10")
        assert result == 1, "z-stream update must sort newer than base release"

    def test_kernel_packages_sort(self):
        base = {
            "name": "kernel", "epoch": 0,
            "version": "4.18.0", "release": "553.el8_10", "arch": "x86_64",
        }
        zstream = {
            "name": "kernel", "epoch": 0,
            "version": "4.18.0", "release": "553.157.1.el8_10", "arch": "x86_64",
        }
        result = rpm_sort([base, zstream])
        assert result[0] == base
        assert result[1] == zstream, "z-stream must sort after base (ascending)"

        reversed_result = list(reversed(rpm_sort([zstream, base])))
        assert reversed_result[0] == zstream, "newest first when reversed"


# ---------------------------------------------------------------------------
# rpm_sort — full filter function with package_facts-style dicts
# ---------------------------------------------------------------------------

class TestRpmSort:

    def _pkg(self, version, release, epoch=0):
        return {"name": "kernel", "epoch": epoch,
                "version": version, "release": release, "arch": "x86_64"}

    def test_ascending_order(self):
        pkgs = [
            self._pkg("4.18.0", "553.157.1.el8_10"),
            self._pkg("4.18.0", "553.el8_10"),
            self._pkg("4.18.0", "477.10.1.el8_8"),
        ]
        result = rpm_sort(pkgs)
        releases = [p["release"] for p in result]
        assert releases == ["477.10.1.el8_8", "553.el8_10", "553.157.1.el8_10"]

    def test_epoch_trumps_version(self):
        old_epoch = self._pkg("1.0", "1.el9", epoch=2)
        new_version = self._pkg("99.0", "1.el9", epoch=1)
        result = rpm_sort([new_version, old_epoch])
        assert result[-1] == old_epoch

    def test_empty_list(self):
        assert rpm_sort([]) == []

    def test_single_package(self):
        pkg = self._pkg("5.14.0", "362.el9")
        assert rpm_sort([pkg]) == [pkg]

    def test_identical_packages(self):
        pkg = self._pkg("5.14.0", "362.el9")
        result = rpm_sort([pkg, pkg])
        assert len(result) == 2


# ---------------------------------------------------------------------------
# rpm_sort — dict input (ansible_facts.packages style)
# ---------------------------------------------------------------------------

class TestRpmSortDictInput:
    """Test that rpm_sort accepts a full ansible_facts.packages dict."""

    def test_multi_key_dict_sorted_by_name_then_evr(self):
        """Passing a dict sorts by package name, then by EVR within each."""
        packages = {
            "kernel": [
                {"name": "kernel", "epoch": 0, "version": "4.18.0",
                 "release": "553.el8_10", "arch": "x86_64"},
                {"name": "kernel", "epoch": 0, "version": "4.18.0",
                 "release": "477.10.1.el8_8", "arch": "x86_64"},
            ],
            "glibc": [
                {"name": "glibc", "epoch": 0, "version": "2.28",
                 "release": "236.el8_9", "arch": "x86_64"},
            ],
        }
        result = rpm_sort(packages)
        assert len(result) == 3
        assert result[0]["name"] == "glibc"
        assert result[1]["name"] == "kernel"
        assert result[1]["release"] == "477.10.1.el8_8"
        assert result[2]["name"] == "kernel"
        assert result[2]["release"] == "553.el8_10"

    def test_single_key_dict(self):
        """A dict with one key behaves like passing that key's list."""
        packages = {
            "kernel": [
                {"name": "kernel", "epoch": 0, "version": "4.18.0",
                 "release": "553.157.1.el8_10", "arch": "x86_64"},
                {"name": "kernel", "epoch": 0, "version": "4.18.0",
                 "release": "553.el8_10", "arch": "x86_64"},
            ],
        }
        result = rpm_sort(packages)
        assert len(result) == 2
        assert result[0]["release"] == "553.el8_10"
        assert result[1]["release"] == "553.157.1.el8_10"

    def test_empty_dict(self):
        """An empty dict returns an empty list."""
        assert rpm_sort({}) == []
