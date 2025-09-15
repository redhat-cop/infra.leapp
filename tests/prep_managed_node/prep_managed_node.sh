#!/bin/bash

. /usr/share/beakerlib/beakerlib.sh || exit 1

# Test parameters:
# SR_REPO_NAME
#   Name of the role repository to test.
#
# SR_GITHUB_ORG
#   Optional: GitHub org to fetch test repository from. Default: linux-system-roles. Can be set to a fork for test purposes.
SR_GITHUB_ORG="${SR_GITHUB_ORG:-linux-system-roles}"
# SR_REQUIRED_VARS
#   Env variables required by this test
# SR_PYTHON_VERSION
#   Python version to install ansible-core with (EL 8, 9, 10 only).

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport upstream_library"
        # lsrLabBosRepoWorkaround
        for required_var in "${SR_REQUIRED_VARS[@]}"; do
            if [ -z "${!required_var}" ]; then
                rlDie "This required variable is unset: $required_var "
            fi
        done
        is_virtual=$(lsrIsVirtual)
        if [ "$is_virtual" -eq 0 ]; then
            lsrDistributeSSHKeys
        fi
        lsrSetHostname
        lsrBuildEtcHosts
        # lsrEnableHA
        # lsrDisableNFV
    rlPhaseEnd
rlJournalEnd
