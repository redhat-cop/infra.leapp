"""Pure-Python RPM EVR comparison filter for Ansible (no rpm module needed).

Implements the rpmvercmp algorithm as specified in rpm-version(7).
"""

DOCUMENTATION = r"""
name: rpm_sort
short_description: Sort a list of RPM package dicts by epoch-version-release (EVR).
description:
  - Sorts a list of package dictionaries using RPM's EVR comparison algorithm
    as specified in rpm-version(7).
  - Implements full support for epoch, tilde (pre-release), and caret
    (post-release/snapshot) semantics.
  - Packages without an explicit epoch (C(None) or C(0)) are treated as epoch 0.
  - Designed to consume the output of M(ansible.builtin.package_facts) directly.
positional: _input
options:
  _input:
    description:
      - A list of dictionaries, each representing an RPM package.
        Each dictionary must contain C(epoch), C(version), and C(release) keys.
        Typically the output of C(ansible_facts.packages['<package_name>']).
      - Alternatively, a dictionary mapping package names to lists of package
        dicts (i.e. the full C(ansible_facts.packages) structure). In this case
        all package lists are flattened into one before sorting.
    type: raw
    required: true
author:
  - Juerg Ritter (jritter@redhat.com)
"""

EXAMPLES = r"""
- name: Sort kernel packages from oldest to newest
  ansible.builtin.set_fact:
    sorted_kernels: "{{ ansible_facts.packages['kernel'] | infra.leapp.rpm_sort }}"

- name: Get the newest kernel (last element after sorting)
  ansible.builtin.set_fact:
    newest_kernel: "{{ ansible_facts.packages['kernel'] | infra.leapp.rpm_sort | last }}"

- name: Sort descending (newest first)
  ansible.builtin.set_fact:
    newest_first: "{{ ansible_facts.packages['kernel'] | infra.leapp.rpm_sort | reverse | list }}"

- name: Sort all installed packages together
  ansible.builtin.set_fact:
    all_sorted: "{{ ansible_facts.packages | infra.leapp.rpm_sort }}"
"""

import re
from functools import cmp_to_key

_SEGMENT_RE = re.compile(r'~|\^|\d+|[a-zA-Z]+')


def _rpmvercmp(a, b):
    """Compare two RPM version/release strings per rpm-version(7)."""
    if a == b:
        return 0

    seg_a = _SEGMENT_RE.findall(a)
    seg_b = _SEGMENT_RE.findall(b)

    i = 0
    while i < len(seg_a) or i < len(seg_b):
        sa = seg_a[i] if i < len(seg_a) else None
        sb = seg_b[i] if i < len(seg_b) else None

        # Tilde sorts older than anything, including absent
        if sa == '~' or sb == '~':
            if sa != '~':
                return 1
            if sb != '~':
                return -1
            i += 1
            continue

        # Caret sorts newer than absent but older than anything else
        if sa == '^' or sb == '^':
            if sa is None:
                return -1
            if sb is None:
                return 1
            if sa != '^':
                return 1
            if sb != '^':
                return -1
            i += 1
            continue

        # One side ran out of segments — the longer one is newer
        if sa is None:
            return -1
        if sb is None:
            return 1

        a_num = sa.isdigit()
        b_num = sb.isdigit()

        # Numeric segments are always newer than alpha segments
        if a_num != b_num:
            return 1 if a_num else -1

        if a_num:
            ia, ib = int(sa), int(sb)
            if ia != ib:
                return 1 if ia > ib else -1
        else:
            if sa < sb:
                return -1
            if sa > sb:
                return 1

        i += 1

    return 0


def _label_compare(evr1, evr2):
    """Compare two (epoch, version, release) tuples per RPM rules."""
    e1, v1, r1 = evr1
    e2, v2, r2 = evr2

    # Epoch wins outright
    ei1, ei2 = int(e1 or 0), int(e2 or 0)
    if ei1 != ei2:
        return 1 if ei1 > ei2 else -1

    rc = _rpmvercmp(v1, v2)
    if rc != 0:
        return rc

    return _rpmvercmp(r1, r2)


def _normalize_epoch(value):
    """Normalize epoch to a string digits representation.

    Handles None, integer 0, string "None", empty string, and numeric strings
    as returned by various ansible_facts.packages implementations.
    """
    if value is None or value == 'None' or value == '':
        return '0'
    return str(int(value))


def rpm_sort(packages):
    """Sort a list of package dicts by EVR using RPM comparison rules.

    Accepts either a list of package dicts or a dict mapping package names
    to lists of package dicts (as returned by ansible_facts.packages).
    In the dict case, each package name's list is sorted by EVR independently,
    then the results are returned sorted by package name.
    """
    if isinstance(packages, dict):
        result = []
        for name in sorted(packages.keys()):
            result.extend(sorted(packages[name], key=cmp_to_key(_compare_evr)))
        return result

    if not packages:
        return []

    return sorted(packages, key=cmp_to_key(_compare_evr))


def _compare_evr(pkg1, pkg2):
    """Compare two package dicts by epoch-version-release."""
    e1 = _normalize_epoch(pkg1.get('epoch'))
    v1 = str(pkg1.get('version', ''))
    r1 = str(pkg1.get('release', ''))

    e2 = _normalize_epoch(pkg2.get('epoch'))
    v2 = str(pkg2.get('version', ''))
    r2 = str(pkg2.get('release', ''))

    return _label_compare((e1, v1, r1), (e2, v2, r2))


class FilterModule(object):
    def filters(self):
        return {
            'rpm_sort': rpm_sort,
        }
