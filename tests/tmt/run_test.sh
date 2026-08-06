#!/usr/bin/env bash
. /usr/share/beakerlib/beakerlib.sh || exit 1

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport /library/upstream_library"
        rlRun "rlImport leapp_lib"
        source "$TMT_PLAN_DATA/leapp_test_env.sh"
    rlPhaseEnd
    rlPhaseStartTest "$TEST_NAME"
        # shellcheck disable=SC2154 # managed_nodes sourced from leapp_test_env.sh
        managed_node=$(echo "$managed_nodes" | awk '{print $1}')
        # shellcheck disable=SC2153,SC2154 # PLAYBOOK set by TMT, coll_path sourced from leapp_test_env.sh
        playbook="$coll_path/$PLAYBOOK"
        LOGFILE="${LOGFILE_PREFIX}-${managed_node}-ANSIBLE-${SR_ANSIBLE_VER}"
        lsrRunPlaybook "$playbook" "" "$SR_SKIP_TAGS" "$managed_node" "$LOGFILE" "$SR_ANSIBLE_VERBOSITY"
    rlPhaseEnd
    rlPhaseStartCleanup
        lsrSubmitManagedNodesLogs
        lsrReserveSystems "$SR_RESERVE_SYSTEMS"
    rlPhaseEnd
rlJournalEnd
