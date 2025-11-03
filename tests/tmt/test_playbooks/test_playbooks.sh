#!/usr/bin/env bash

. /usr/share/beakerlib/beakerlib.sh || exit 1

# Test parameters:
# SR_ANSIBLE_VER
#   ansible version to use for tests. E.g. "2.9" or "2.16".
[ -n "$ANSIBLE_VER" ] && export SR_ANSIBLE_VER="$ANSIBLE_VER"
#
# SR_REPO_NAME
#   Name of the role repository to test.
[ -n "$REPO_NAME" ] && export SR_REPO_NAME="$REPO_NAME"
SR_REPO_NAME="${SR_REPO_NAME:-infra.leapp}"
#
# SR_TEST_LOCAL_CHANGES
#   Optional: When true, tests from local changes. When false, test from a repository PR number (when SR_PR_NUM is set) or main branch.
SR_TEST_LOCAL_CHANGES="${SR_TEST_LOCAL_CHANGES:-false}"
#   TMT sets True, False with capital letters, need to reset it to bash style
[ "$SR_TEST_LOCAL_CHANGES" = True ] && export SR_TEST_LOCAL_CHANGES=true
[ "$SR_TEST_LOCAL_CHANGES" = False ] && export SR_TEST_LOCAL_CHANGES=false

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
SR_GITHUB_ORG="${SR_GITHUB_ORG:-redhat-cop}"
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
SR_REQUIRED_VARS=("SR_ANSIBLE_VER")
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
        rlRun "rlImport /library/upstream_library"

        rlRun "rlImport leapp_lib"

        for required_var in "${SR_REQUIRED_VARS[@]}"; do
            if [ -z "${!required_var}" ]; then
                rlDie "This required variable is unset: $required_var "
            fi
        done

        leappInstallAnsible "$SR_ANSIBLE_VER"
        coll_path=~/.ansible/collections/ansible_collections/infra/leapp
        mkdir -p "$coll_path"
        if [ -d "$coll_path" ]; then
            rlRun "rm -rf $coll_path"
        fi
        if [ "$SR_TEST_LOCAL_CHANGES" == true ]; then
            local_infra_leapp_path=$TMT_TREE_DISCOVER/Run-test-playbooks-from-control_node/tests
            rlRun "cp -r $local_infra_leapp_path/. $coll_path/"
        else
            rlRun "git clone -q https://github.com/$SR_GITHUB_ORG/$SR_REPO_NAME.git $coll_path --depth 1"
            if [ -n "$SR_PR_NUM" ]; then
                pushd "$coll_path" || exit
                rlRun "git fetch origin pull/$SR_PR_NUM/head"
                rlRun "git checkout FETCH_HEAD"
                popd || exit
                rlLog "Test from the pull request $SR_PR_NUM"
            else
                rlLog "Test from the main branch"
            fi
        fi

        rlWaitForCmd "ansible-galaxy collection install -r $coll_path/meta/collection-requirements.yml -vv" -m 5

        # if lsrVaultRequired "$legacy_test_path"; then
        #     for test_playbook in $test_playbooks; do
        #         lsrHandleVault "$test_playbook"
        #     done
        # fi
        # lsrSetAnsibleGathering "$SR_ANSIBLE_GATHERING"
        lsrPrepareNodesInventories
        managed_nodes=$(lsrGetManagedNodes)
    rlPhaseEnd
    rlPhaseStartTest
        roles=("$coll_path"/roles/*)
        for test_type in "$coll_path" "${roles[@]}"; do
            test_playbooks=$(lsrGetTests "$test_type/tests")
            lsrRunPlaybooksParallel "$SR_SKIP_TAGS" "$test_playbooks" "$managed_nodes" "true" "$SR_ANSIBLE_VERBOSITY"
        done

        lsrSubmitManagedNodesLogs
        lsrReserveSystems "$SR_RESERVE_SYSTEMS"
    rlPhaseEnd
rlJournalEnd
