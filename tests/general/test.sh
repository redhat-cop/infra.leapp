#!/bin/bash

. /usr/share/beakerlib/beakerlib.sh || exit 1

# Test parameters:
# SR_ANSIBLE_VER
#   ansible version to use for tests. E.g. "2.9" or "2.16".
[ -n "$ANSIBLE_VER" ] && export SR_ANSIBLE_VER="$ANSIBLE_VER"
#
# SR_REPO_NAME
#   Name of the role repository to test.
[ -n "$REPO_NAME" ] && export SR_REPO_NAME="$REPO_NAME"
#
# SR_TEST_LOCAL_CHANGES
#   Optional: When true, tests from local changes. When false, test from a repository PR number (when SR_PR_NUM is set) or main branch.
[ -n "$TEST_LOCAL_CHANGES" ] && export SR_TEST_LOCAL_CHANGES="$TEST_LOCAL_CHANGES"
SR_TEST_LOCAL_CHANGES="${SR_TEST_LOCAL_CHANGES:-false}"
#   TMT sets True, False with capital letters, need to reset it to bash style
[ "$TEST_LOCAL_CHANGES" = True ] && export TEST_LOCAL_CHANGES=true
[ "$TEST_LOCAL_CHANGES" = False ] && export TEST_LOCAL_CHANGES=false

#
# SR_PR_NUM
#   Optional: Number of PR to test. If empty, tests the default branch.
[ -n "$PR_NUM" ] && export SR_PR_NUM="$PR_NUM"
#
# SR_ONLY_TESTS
#  Optional: Space separated names of test playbooks to test. E.g. "tests_imuxsock_files.yml tests_relp.yml"
#  If empty, tests all tests in tests/tests_*.yml
[ -n "$SYSTEM_ROLES_ONLY_TESTS" ] && export SR_ONLY_TESTS="$SYSTEM_ROLES_ONLY_TESTS"
#
# SR_EXCLUDED_TESTS
#   Optional: Space separated names of test playbooks to exclude from test.
[ -n "$SYSTEM_ROLES_EXCLUDE_TESTS" ] && export SR_EXCLUDED_TESTS="$SYSTEM_ROLES_EXCLUDE_TESTS"
#
# SR_GITHUB_ORG
#   Optional: GitHub org to fetch test repository from. Default: linux-system-roles. Can be set to a fork for test purposes.
[ -n "$GITHUB_ORG" ] && export SR_GITHUB_ORG="$GITHUB_ORG"
SR_GITHUB_ORG="${SR_GITHUB_ORG:-linux-system-roles}"
# SR_LSR_SSH_KEY
#   Optional: When provided, test uploads artifacts to SR_LSR_DOMAIN instead of uploading them with rlFileSubmit "$logfile".
#   A Single-line SSH key.
#   When provided, requires SR_LSR_USER and SR_LSR_DOMAIN.
[ -n "$LINUXSYSTEMROLES_SSH_KEY" ] && export SR_LSR_SSH_KEY="$LINUXSYSTEMROLES_SSH_KEY"
# SR_LSR_USER
#   Username used when uploading artifacts.
[ -n "$LINUXSYSTEMROLES_USER" ] && export SR_LSR_USER="$LINUXSYSTEMROLES_USER"
# SR_LSR_DOMAIN: secondary01.fedoraproject.org
#   Domain where to upload artifacts.
[ -n "$LINUXSYSTEMROLES_DOMAIN" ] && export SR_LSR_DOMAIN="$LINUXSYSTEMROLES_DOMAIN"
# SR_ARTIFACTS_URL
#   URL to store artifacts
[ -n "$ARTIFACTS_URL" ] && export SR_ARTIFACTS_URL="$ARTIFACTS_URL"
# SR_ARTIFACTS_DIR
#   Directory to store artifacts
[ -n "$ARTIFACTS_DIR" ] && export SR_ARTIFACTS_DIR="$ARTIFACTS_DIR"
# SR_PYTHON_VERSION
#   Python version to install ansible-core with (EL 8, 9, 10 only).
[ -n "$PYTHON_VERSION" ] && export SR_PYTHON_VERSION="$PYTHON_VERSION"
SR_PYTHON_VERSION="${SR_PYTHON_VERSION:-3.12}"
# SR_SKIP_TAGS
#   Ansible tags that must be skipped
[ -n "$SKIP_TAGS" ] && export SR_SKIP_TAGS="$SKIP_TAGS"
SR_SKIP_TAGS="--skip-tags tests::nvme,tests::infiniband,tests::bootc-e2e"
# SR_TFT_DEBUG
#   Print output of ansible playbooks to terminal in addition to printing it to logfile
SR_TFT_DEBUG=true
[ -n "$LSR_TFT_DEBUG" ] && export SR_TFT_DEBUG="$LSR_TFT_DEBUG"
#   TMT sets True, False with capital letters, need to reset it to bash style
[ "$LSR_TFT_DEBUG" = True ] && export LSR_TFT_DEBUG=true
[ "$LSR_TFT_DEBUG" = False ] && export LSR_TFT_DEBUG=false

if [ "$(echo "$SR_ONLY_TESTS" | wc -w)" -eq 1 ]; then
    SR_TFT_DEBUG=true
else
    SR_TFT_DEBUG="${SR_TFT_DEBUG:-false}"
fi
# SR_ANSIBLE_GATHERING
#   Use this to set value for the SR_ANSIBLE_GATHERING environmental variable for ansible-playbook.
#   Choices: implicit, explicit, smart
#   https://docs.ansible.com/ansible/latest/reference_appendices/config.html#default-gathering
[ -n "$ANSIBLE_GATHERING" ] && export SR_ANSIBLE_GATHERING="$ANSIBLE_GATHERING"
SR_ANSIBLE_GATHERING="${SR_ANSIBLE_GATHERING:-implicit}"
# SR_REQUIRED_VARS
#   Env variables required by this test
SR_REQUIRED_VARS=("SR_ANSIBLE_VER" "SR_REPO_NAME")
# SR_ANSIBLE_VERBOSITY
#   Default is "-vv" - user can locally edit tft.yml in role to increase this for debugging
[ -n "$LSR_ANSIBLE_VERBOSITY" ] && export SR_ANSIBLE_VERBOSITY="$LSR_ANSIBLE_VERBOSITY"
SR_ANSIBLE_VERBOSITY="${SR_ANSIBLE_VERBOSITY:--vv}"
# SR_REPORT_ERRORS_URL
#   Default is https://raw.githubusercontent.com/linux-system-roles/auto-maintenance/main/callback_plugins/lsr_report_errors.py
#   This is used to embed an error report in the output log
SR_REPORT_ERRORS_URL="${SR_REPORT_ERRORS_URL:-https://raw.githubusercontent.com/linux-system-roles/auto-maintenance/main/callback_plugins/lsr_report_errors.py}"
#
# SR_RESERVE_SYSTEMS
#   Set to true to sleep for 10h after test finishes for troubleshooting purposes
#   You can find IPs of systems from artifacts by looking into workdir/plans/test_playbooks_parallel/provision/guests.yaml
#   It's best to cancel requests after you finish with `testing-farm cancel`
SR_RESERVE_SYSTEMS="${SR_RESERVE_SYSTEMS:-false}"
#   TMT sets True, False with capital letters, need to reset it to bash style
[ "$SR_RESERVE_SYSTEMS" = True ] && export SR_RESERVE_SYSTEMS=true
[ "$SR_RESERVE_SYSTEMS" = False ] && export SR_RESERVE_SYSTEMS=false

echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~ Environment Variables Definition - BEGIN"
echo "ARCH_CONTROLLER=${ARCH_CONTROLLER}"
echo "ARCH_MANAGED_NODE=${ARCH_MANAGED_NODE}"
echo "COMPOSE_CONTROLLER=${COMPOSE_CONTROLLER}"
echo "COMPOSE_MANAGED_NODE=${COMPOSE_MANAGED_NODE}"
env | grep -E '^SR_'
echo "~~~ Environment Variables Definition - END"

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport upstream_library"
        rlRun "rlImport utils"
        # lsrLabBosRepoWorkaround

        # for required_var in "${SR_REQUIRED_VARS[@]}"; do
        #     if [ -z "${!required_var}" ]; then
        #         rlDie "This required variable is unset: $required_var "
        #     fi
        # done
        rolesInstallAnsible "$SR_ANSIBLE_VER"
        #lsrInstallAnsible
        infra_leapp_path="infra.leapp"
        #rlRun "git clone -q https://github.com/redhat-cop/infra.leapp.git  --depth 1"
        rlRun "mkdir -p ~/.ansible/collections/ansible_collections/infra/leapp"
        rlRun "cp -r ../../* ~/.ansible/collections/ansible_collections/infra/leapp/"
        if [ -n "$SR_PR_NUM" ]; then
            # git on EL7 doesn't support -C option
            pushd "$infra_leapp_path" || exit
            rlRun "git fetch origin pull/$SR_PR_NUM/head"
            rlRun "git checkout FETCH_HEAD"
            popd || exit
            rlLog "Test from the pull request $SR_PR_NUM"
        else
            rlLog "Test from the main branch"
        fi
        # mkdir -p ~/.ansible/collections/ansible_collections/infra
        # cp -r "$infra_leapp_path" ~/.ansible/collections/ansible_collections/infra/leapp

        rlRun "ansible-galaxy collection install -r ../../meta/collection-requirements.yml"

        # if [ "${SR_ANSIBLE_VER:-}" = 2.9 ]; then
        #     # does not work with 2.9
        #     GET_PYTHON_MODULES=false
        # fi
        # lsrGetRoleDir "$SR_REPO_NAME"
        # # role_path is defined in lsrGetRoleDir
        # # shellcheck disable=SC2154
        # legacy_test_path="$role_path"/tests
        # test_playbooks=$(lsrGetTests "$legacy_test_path")
        # rlLogInfo "Test playbooks: $test_playbooks"
        # if lsrVaultRequired "$legacy_test_path"; then
        #     for test_playbook in $test_playbooks; do
        #         lsrHandleVault "$test_playbook"
        #     done
        # fi
        # lsrSetAnsibleGathering "$SR_ANSIBLE_GATHERING"
        # lsrGetCollectionPath
        # collection_path is defined in lsrGetCollectionPath
        # shellcheck disable=SC2154
        # lsrInstallDependencies "$role_path" "$collection_path"
        # lsrEnableCallbackPlugins "$collection_path"
        # lsrConvertToCollection "$role_path" "$collection_path" "$SR_REPO_NAME"
        lsrPrepareNodesInventories
        # tests_path="$collection_path"/ansible_collections/fedora/linux_system_roles/tests/"$SR_REPO_NAME"/
        tests_path=~/.ansible/collections/ansible_collections/infra/leapp/tests
        # test_playbooks=$(lsrGetTests "$tests_path")
        # if [ "${GET_PYTHON_MODULES:-}" = true ]; then
        #     # shellcheck disable=SC2086
        #     lsrSetupGetPythonModules "$test_playbooks"
        # fi

        managed_nodes=$(lsrGetManagedNodes)
        # for managed_node in $managed_nodes; do
        #     lsrGenerateTestDisks "$tests_path" start disk_provisioner.sh "$managed_node"
        # done
    rlPhaseEnd
    rlPhaseStartTest
        for test_playbook in "$tests_path"/tests_*.yml; do
            LOGFILE=leapp-"${test_playbook%.*}"-ANSIBLE-"$SR_ANSIBLE_VER"
            LOGFILE="leapp-$(basename "${test_playbook%.*}")-ANSIBLE-$SR_ANSIBLE_VER"
            lsrRunPlaybook "$test_playbook" "" "$SKIP_TAGS" "$managed_nodes" "$LOGFILE" "$SR_ANSIBLE_VERBOSITY"
        done
        # lsrRunPlaybooksParallel "$SR_SKIP_TAGS" "$test_playbooks" "$managed_nodes" "false" "$SR_ANSIBLE_VERBOSITY"
        # lsrSubmitManagedNodesLogs
        lsrReserveSystems "$SR_RESERVE_SYSTEMS"
    rlPhaseEnd
rlJournalEnd
