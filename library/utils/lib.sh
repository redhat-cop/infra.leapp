#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   lib.sh of /CoreOS/rhel-system-roles/Library/basic
#   Description: Basic functions for rhel-system-roles testing
#   Author: David Jez <djez@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2020 Red Hat, Inc.
#
#   This program is free software: you can redistribute it and/or
#   modify it under the terms of the GNU General Public License as
#   published by the Free Software Foundation, either version 2 of
#   the License, or (at your option) any later version.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE.  See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program. If not, see http://www.gnu.org/licenses/.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   library-prefix = rolesBasic
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~





rolesGetAnsibleVersion() {
    local ver
    ver="$(ansible --version | grep '^ansible .*[0-9][.]')"
    if [[ "$ver" =~ ^ansible\ ([0-9]+[.][0-9]+) ]]; then
        echo "${BASH_REMATCH[1]}"
    elif [[ "$ver" =~ ^ansible\ .*core\ ([0-9]+[.][0-9]+) ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo UNKNOWN_ANSIBLE_VERSION
    fi
}


rolesInstallAnsible() {
    local ae_version
    ae_version=$1
    local ansible_pkg
    local pkg_cmd
    local baseurl

    if rlIsRHEL ">=8.6" && [ "$ANSIBLE_VER" != "2.9" ]; then
        pkg_cmd="dnf"
        ansible_pkg="ansible-core"
    elif rlIsRHEL 8; then
        pkg_cmd="dnf"
        ansible_pkg="ansible"
        baseurl="https://rhsm-pulp.corp.redhat.com/content/dist/layered/rhel8/$(arch)/ansible/$ae_version/os/"
    else
        # el7
        pkg_cmd="yum"
        ansible_pkg="ansible"
        if [ "$(arch)" == "ppc64le" ]; then
            baseurl="https://rhsm-pulp.corp.redhat.com/content/dist/rhel/power-le/7/7Server/$(arch)/ansible/$ae_version/os/"
        elif [ "$(arch)" == "s390x" ]; then
            baseurl="https://rhsm-pulp.corp.redhat.com/content/dist/rhel/system-z/7/7Server/$(arch)/ansible/$ae_version/os/"
        else
            baseurl="https://rhsm-pulp.corp.redhat.com/content/dist/rhel/server/7/7Server/$(arch)/ansible/$ae_version/os/"
        fi
    fi

    if rlIsRHEL ">7"; then
        if "$pkg_cmd" module info standard-test-roles > /dev/null 2>&1; then
            "$pkg_cmd" -y module disable standard-test-roles
        fi
    fi
    if [ -n "${baseurl:-}" ]; then
        echo "[${ansible_pkg}-$ae_version]
name=${ansible_pkg}-$ae_version
baseurl=$baseurl
enabled=1
gpgcheck=0
priority=1" > /etc/yum.repos.d/lsr-test-ansible.repo
    fi

    # We need to swap an ansible/ansible-core if other package has been previously installed. Otherwise try to install a chosen one.
    action="install"
    rpm --quiet -q ansible && test "$ansible_pkg" = "ansible-core" && action="swap ansible"
    rpm --quiet -q ansible-core && test "$ansible_pkg" = "ansible" && action="swap ansible-core"

    rlRun "$pkg_cmd -y $action $ansible_pkg"
    rlAssertRpm "$ansible_pkg"
    # set SR_ANSIBLE_VER from ansible
    SR_ANSIBLE_VER="$(rolesGetAnsibleVersion)"
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Verification
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   This is a verification callback which will be called by
#   rlImport after sourcing the library to make sure everything is
#   all right. It makes sense to perform a basic sanity test and
#   check that all required packages are installed. The function
#   should return 0 only when the library is ready to serve.
#
#   This library does not do anything, it is only a list of functions, so simply returning 0
rolesBasicLibraryLoaded() {
    rlLog "Library loaded!"
    return 0
}
