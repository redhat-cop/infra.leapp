#!/usr/bin/env bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Description: Library for leapp Ansible collection tests
#   Author: Sergei Petrosian <spetrosi@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   library-prefix = leapp
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Copied from downstream tests/rhel-system-roles/Library/basic rolesGetAnsibleVersion
leappGetAnsibleVersion() {
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

# Copied from downstream tests/rhel-system-roles/Library/basic library rolesInstallAnsible
leappInstallAnsible() {
    local ae_version
    ae_version=$1
    local ansible_pkg
    local pkg_cmd
    local baseurl

    if rlIsRHELLike ">=8.6" && [ "$ANSIBLE_VER" != "2.9" ]; then
        pkg_cmd="dnf"
        ansible_pkg="ansible-core"
    elif rlIsRHELLike 8; then
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

    if rlIsRHELLike ">7"; then
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
}

# declare -A leapp_test_playbooks

leappGetTests() {
    local -n test_playbooks=$1
    local coll_path=$2
    # local roles test_type_name type_test_playbooks_all type_test_playbooks_all

    roles=("$coll_path"/roles/*)
    for test_type in "$coll_path" "${roles[@]}"; do
        test_type_name=$(basename "$test_type")
        type_test_playbooks_all=$(
            find "$test_type"/tests -maxdepth 1 -type f -name "tests_*.yml" | sort | xargs
        )

        if [[ -n $SR_ONLY_TESTS && $SR_ONLY_TESTS == *"$test_type_name"/* ]]; then
            if [[ $SR_ONLY_TESTS == *"$test_type_name"/\** ]]; then
                type_test_playbooks="$type_test_playbooks_all"
            else
                for test_playbook in $type_test_playbooks_all; do
                    playbook_basename=$(basename "$test_playbook")
                    if [[ $SR_ONLY_TESTS == *"$test_type_name"/"$playbook_basename"* ]]; then
                        type_test_playbooks+=" $test_playbook"
                    fi
                done
            fi
        else
            type_test_playbooks="$type_test_playbooks_all"
        fi

        test_playbooks["$test_type_name"]="$type_test_playbooks_all"
    done

    if [ -z "${test_playbooks[*]}" ]; then
        rlDie "No test playbooks found"
    fi
}

leappDebugRepos() {
    local hostname repos
    hostname=$(lsrGetCurrNodeHostname)
    repos=$(find /etc/yum.repos.d -name "*.repo")
    rlLog "Hostname: $hostname"
    for repo in $repos; do
        rlLog "Repo: $repo"
        repo_content=$(cat "$repo")
        rlLog "Repo content:
$repo_content"
    done
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
leappLibraryLoaded() {
    rlLog "Library loaded!"
    return 0
}
