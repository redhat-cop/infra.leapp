#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Description: Library for system roles tests
#   Author: Sergei Petrosian <spetrosi@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   library-prefix = rolesUpstream
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Variables for our tests to define on library import
TMT_TREE_PARENT=${TMT_TREE%/*}
TMT_PLAN=$(basename "$TMT_TREE_PARENT")
TMT_TREE_PROVISION=$TMT_TREE_PARENT/provision
TMT_TREE_DISCOVER="$TMT_TREE_PARENT"/discover
# TMT_TREE_EXECUTE is used in downstream tests
# shellcheck disable=SC2034
TMT_TREE_EXECUTE="$TMT_TREE_PARENT"/execute
GUESTS_YML=${TMT_TREE_PROVISION}/guests.yaml
declare -gA ANSIBLE_ENVS

lsrLabBosRepoWorkaround() {
    sed -i 's|\.lab\.bos.|.devel.|g' /etc/yum.repos.d/*.repo
}

lsrInstallAnsible() {
    # Hardcode to the only supported version on later ELs
    if rlIsFedora '>=41'; then
        SR_PYTHON_VERSION=3.13
    elif rlIsRHELLike 8 && [ "$SR_ANSIBLE_VER" == "2.9" ]; then
        SR_PYTHON_VERSION=3.9
    elif rlIsRHELLike 8 && [ "$SR_ANSIBLE_VER" != "2.9" ]; then
        # CentOS-8 supports either 2.9 or 2.16
        SR_ANSIBLE_VER=2.16
    elif rlIsRHELLike 7; then
        SR_PYTHON_VERSION=3
        SR_ANSIBLE_VER=2.9
    fi

    if rlIsFedora || (rlIsRHELLike ">7" && [ "$SR_ANSIBLE_VER" != "2.9" ]); then
        rlRun "dnf install python$SR_PYTHON_VERSION-pip -y"
        # install ansible dependencies first so that we do not install pre-release versions of them
        rlRun "python$SR_PYTHON_VERSION -m pip install passlib"
        # install possible pre-release version of ansible-core
        rlRun "python$SR_PYTHON_VERSION -m pip install --pre 'ansible-core==$SR_ANSIBLE_VER.*'"
    elif rlIsRHELLike 8; then
        # el8 ansible-2.9
        rlRun "dnf install python$SR_PYTHON_VERSION -y"
        # selinux needed for delegate_to: localhost for file, copy, etc.
        # Providing passlib for password_hash module, see https://issues.redhat.com/browse/SYSROLES-81
        rlRun "python$SR_PYTHON_VERSION -m pip install 'ansible==$SR_ANSIBLE_VER.*' selinux passlib rpm"
    else
        # el7
        rlRun "yum install python$SR_PYTHON_VERSION-pip 'ansible-$SR_ANSIBLE_VER.*' -y"
    fi
}

lsrCloneRepo() {
    local role_path=$1
    local repo_name=$2
    rlRun "git clone -q https://github.com/$SR_GITHUB_ORG/$repo_name.git $role_path --depth 1"
    if [ -n "$SR_PR_NUM" ]; then
        # git on EL7 doesn't support -C option
        pushd "$role_path" || exit
        rlRun "git fetch origin pull/$SR_PR_NUM/head"
        rlRun "git checkout FETCH_HEAD"
        popd || exit
        rlLog "Test from the pull request $SR_PR_NUM"
    else
        rlLog "Test from the main branch"
    fi
}

lsrGetRoleDir() {
    local repo_name=$1
    if [ "$SR_TEST_LOCAL_CHANGES" == true ]; then
        rlLog "Test from local changes"
        role_path="$TMT_TREE"
    else
        role_path=$(mktemp --directory -t "$repo_name"-XXX)
        lsrCloneRepo "$role_path" "$repo_name"
    fi
}

lsrGetTests() {
    local tests_path=$1
    local test_playbooks_all test_playbooks
    test_playbooks_all=$(find "$tests_path" -maxdepth 1 -type f -name "tests_*.yml" | sort)
    if [ -n "$SR_ONLY_TESTS" ]; then
        for test_playbook in $test_playbooks_all; do
            playbook_basename=$(basename "$test_playbook")
            if echo "$SR_ONLY_TESTS" | grep -q "$playbook_basename"; then
                test_playbooks="$test_playbooks $test_playbook"
            fi
        done
    else
        test_playbooks="$test_playbooks_all"
    fi
    if [ -n "$SR_EXCLUDED_TESTS" ]; then
        test_playbooks_excludes=""
        for test_playbook in $test_playbooks; do
            playbook_basename=$(basename "$test_playbook")
            if ! echo "$SR_EXCLUDED_TESTS" | grep -q "$playbook_basename"; then
                test_playbooks_excludes="$test_playbooks_excludes $test_playbook"
            fi
        done
        test_playbooks=$test_playbooks_excludes
    fi
    if [ -z "$test_playbooks" ]; then
        rlDie "No test playbooks found"
    fi
    # Convert to a space-separated str, a format that users provide in env vars
    echo "$test_playbooks" | xargs
}

lsrVaultRequired() {
    local tests_path=$1
    local vault_pwd_file=$tests_path/vault_pwd
    local vault_variables_file=$tests_path/vars/vault-variables.yml
    local vault_pwd_short=vars/vault_pwd
    local vault_variables_short=vars/vault-variables.yml
    local role_name

    role_name=$(lsrGetRoleNameFromTestsPath "$tests_path")

    if [ ! -f "$vault_pwd_file" ] || [ ! -f "$vault_variables_file" ]; then
        rlLogInfo "$role_name: Skipping vault variables because $vault_pwd_short and $vault_variables_short don't exist"
        return 1
    fi
    rlLogInfo "$role_name: including vault variables"
    return 0
}

# Handle Ansible Vault encrypted variables
lsrHandleVault() {
    local playbook_file=$1
    local tests_path
    tests_path=$(dirname "$playbook_file")
    local vault_pwd_file=$tests_path/vault_pwd
    local vault_variables_file=$tests_path/vars/vault-variables.yml
    local no_vault_file=$tests_path/no-vault-variables.txt
    local vault_play role_name vault_pwd_short vault_variables_short playbook_file_bsn

    role_name=$(lsrGetRoleNameFromTestsPath "$tests_path")
    vault_pwd_short=$role_name/vars/vault_pwd
    vault_variables_short=$role_name/vars/vault-variables.yml
    playbook_file_bsn=$(basename "$playbook_file")

    if [ -f "$no_vault_file" ]; then
        if grep -q "^${playbook_file_bsn}\$" "$no_vault_file"; then
            rlLogInfo "$role_name/$playbook_file_bsn: skipping because playbook is in no-vault-variables.txt"
            return
        fi
    fi
    rlLogInfo "$role_name/$playbook_file_bsn: Including vault variables"
    if [ -z "${ANSIBLE_ENVS[ANSIBLE_VAULT_PASSWORD_FILE]}" ]; then
        ANSIBLE_ENVS[ANSIBLE_VAULT_PASSWORD_FILE]="$vault_pwd_file"
    fi
    vault_play="---
- hosts: all
  gather_facts: false
  tasks:
    - name: Include vault variables
      include_vars:
        file: $vault_variables_file"
    sed -i "/---/d" "$playbook_file"
    cat <<< "$vault_play
$(cat "$playbook_file")" > "$playbook_file".tmp
    mv "$playbook_file".tmp "$playbook_file"
}

lsrIsAnsibleEnvVarSupported() {
    # Return 0 if supported, 1 if not supported
    local env_var_name=$1
    ansible-config list | grep -q "name: $env_var_name$"
}

lsrIsAnsibleCmdOptionSupported() {
    # Return 0 if supported, 1 if not supported
    local cmd=$1
    local option=$2
    $cmd --help | grep -q -e "$option"
}

lsrGetCollectionPath() {
    collection_path=$(mktemp --directory -t collections-XXX)
    if lsrIsAnsibleEnvVarSupported ANSIBLE_COLLECTIONS_PATH; then
        ANSIBLE_ENVS[ANSIBLE_COLLECTIONS_PATH]="$collection_path"
    else
        ANSIBLE_ENVS[ANSIBLE_COLLECTIONS_PATHS]="$collection_path"
    fi
}

lsrInstallDependencies() {
    local role_path=$1
    local collection_path=$2
    local coll_req_file="$1/meta/collection-requirements.yml"
    local coll_test_req_file="$1/tests/collection-requirements.yml"
    for req_file in $coll_req_file $coll_test_req_file; do
        if [ ! -f "$req_file" ]; then
            rlLogInfo "Skipping installing dependencies from $req_file, this file doesn't exist"
            continue
        fi
        rlWaitForCmd "ansible-galaxy collection install -p $collection_path -vv -r $req_file" -m 5
        rlLogInfo "$req_file Dependencies were successfully installed"
    done
}

lsrEnableCallbackPlugins() {
    local collection_path=$1
    local cmd
    local basename
    # Enable callback plugins for prettier ansible output
    callback_path=ansible_collections/ansible/posix/plugins/callback
    if [ ! -f "$collection_path"/"$callback_path"/debug.py ] || [ ! -f "$collection_path"/"$callback_path"/profile_tasks.py ]; then
        ansible_posix=$(mktemp --directory -t ansible_posix-XXX)
        cmd="ansible-galaxy collection install ansible.posix -p $ansible_posix -vv"
        if lsrIsAnsibleCmdOptionSupported "ansible-galaxy collection install" "--force-with-deps"; then
            rlWaitForCmd "$cmd --force-with-deps" -m 5
        elif lsrIsAnsibleCmdOptionSupported "ansible-galaxy collection install" "--force"; then
            rlWaitForCmd "$cmd --force" -m 5
        else
            rlWaitForCmd "$cmd" -m 5
        fi
        if [ ! -d "$1"/"$callback_path"/ ]; then
            rlRun "mkdir -p $collection_path/$callback_path"
        fi
        rlRun "cp $ansible_posix/$callback_path/{debug.py,profile_tasks.py} $collection_path/$callback_path/"
        rlRun "rm -rf $ansible_posix"
    fi
    if lsrIsAnsibleEnvVarSupported ANSIBLE_CALLBACKS_ENABLED; then
        ANSIBLE_ENVS[ANSIBLE_CALLBACKS_ENABLED]="profile_tasks"
    else
        ANSIBLE_ENVS[ANSIBLE_CALLBACK_WHITELIST]="profile_tasks"
    fi
    ANSIBLE_ENVS[ANSIBLE_STDOUT_CALLBACK]="debug"
    # grab the lsr_report_errors.py callback plugin
    basename="$(basename "$SR_REPORT_ERRORS_URL")"
    curl -L -s -o "$collection_path/$callback_path/$basename" "$SR_REPORT_ERRORS_URL"
    ANSIBLE_ENVS[ANSIBLE_CALLBACK_PLUGINS]="$collection_path/$callback_path"
}

lsrConvertToCollection() {
    local role_path=$1
    local collection_path=$2
    local role_name=$3
    local collection_script_url=https://raw.githubusercontent.com/linux-system-roles/auto-maintenance/main
    local coll_namespace=fedora
    local coll_name=linux_system_roles
    local subrole_prefix=private_"$role_name"_subrole_
    local tmpdir=/tmp/lsr_role2collection
    local lsr_role2collection=$tmpdir/lsr_role2collection.py
    local runtime=$tmpdir/runtime.yml
    if [ ! -d "$tmpdir" ]; then
        mkdir -p "$tmpdir"
    fi
    if [ ! -f "$lsr_role2collection" ]; then
        rlRun "curl -L -o $lsr_role2collection $collection_script_url/lsr_role2collection.py"
    fi
    if [ ! -f "$runtime" ]; then
        rlRun "curl -L -o $runtime $collection_script_url/lsr_role2collection/runtime.yml"
    fi
    # Remove role that was installed as a dependency
    rlRun "rm -rf $collection_path/ansible_collections/fedora/linux_system_roles/roles/$role_name"
    # Remove performancecopilot vendored by metrics. It will be generated during a conversion to collection.
    if [ "$role_name" = "metrics" ]; then
        rlRun "rm -rf $collection_path/ansible_collections/fedora/linux_system_roles/vendor/github.com/performancecopilot/ansible-pcp"
    fi
    rlRun "python$SR_PYTHON_VERSION -m pip install ruamel-yaml"
    # Remove symlinks in tests/roles
    if [ -d "$role_path"/tests/roles ]; then
        find "$role_path"/tests/roles -type l -exec rm {} \;
        if [ -d "$role_path"/tests/roles/linux-system-roles."$role_name" ]; then
            rlRun "rm -r $role_path/tests/roles/linux-system-roles.$role_name"
        fi
    fi
    rlRun "python$SR_PYTHON_VERSION $lsr_role2collection \
--meta-runtime $runtime \
--src-owner linux-system-roles \
--role $role_name \
--src-path $role_path \
--dest-path $collection_path \
--namespace $coll_namespace \
--collection $coll_name \
--subrole-prefix $subrole_prefix"
}

lsrGetManagedNodes() {
    # xargs to return space-separated string
    sed --quiet --regexp-extended 's/(^managed.*):$/\1/p' "$GUESTS_YML" | sort | xargs
}

lsrGetNodes() {
    # xargs to return space-separated string
    sed --quiet --regexp-extended 's/(^[^ ]*):$/\1/p' "$GUESTS_YML" | sort | xargs
}

lsrGetNodeName() {
    local node_pat=$1
    sed --quiet --regexp-extended "s/(^$node_pat.*):$/\1/p" "$GUESTS_YML"
}

lsrGetCurrNodeHostname() {
    local ip_addr
    ip_addr=$(hostname -I | awk '{print $1}')
    grep "primary-address: $ip_addr$" "$GUESTS_YML" -B 10 | sed --quiet --regexp-extended 's/(^[^ ]*):$/\1/p'
}

lsrGetNodeIp() {
    local node=$1
    # awk '$1=$1' to remove extra spaces
    sed --quiet "/^$node:$/,/^[^ ]/p" "$GUESTS_YML" | sed --quiet --regexp-extended 's/primary-address: (.*)/\1/p' | awk '$1=$1'
}

lsrGetNodeOs() {
    local node=$1
    sed --quiet "/^$node:$/,/^[^ ]/p" "$GUESTS_YML" | sed --quiet --regexp-extended 's/distro: (.*)/\1/p' | awk '$1=$1'
}

lsrGetNodeKeyPrivate() {
    local node=$1
    # Key is a list containing SSH keys, the first key is private RSA
    sed --quiet "/^$node:$/,/^[^ ]/p" "$GUESTS_YML" | grep 'key:' -A1 | tail -n1 | grep -o '/.*'
}

lsrGetNodeKeyPublic() {
    local node=$1
    # Append .pub to the private key
    lsrGetNodeKeyPrivate "$node" | awk '{print $1".pub"}'
}

lsrGenerateAnsibleSSHKey() {
    # crypto_policies/tests_reboot.yml changes crypto policy to FUTURE and does a reboot.
    # FUTURE crypto_policy doesn't allow shorter RSA keys that TF uses by default.
    # Because of this, for use with Ansible, test generates a separate ecdsa key.
    # https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/8/html/security_hardening/using-the-system-wide-cryptographic-policies_security-hardening#system-wide-crypto-policies_using-the-system-wide-cryptographic-policies
    # Note that for other operations e.g. lsrExecuteOnNode tests use the key provided by TF.
    local key_glob key_f
    key_glob="/var/tmp/sr_ecdsa_*"
    if compgen -G "$key_glob" > /dev/null; then
        find /var/tmp -wholename "$key_glob" -not -name "*.pub"
    else
        key_f=$(mktemp -u /var/tmp/sr_ecdsa_XXX)
        ssh-keygen -t ecdsa -b 256 -f "$key_f" -N "" -q
        echo "$key_f"
    fi
}

lsrGetAnsibleKeyPublic() {
    local control_node_key
    control_node_key=$(lsrGenerateAnsibleSSHKey)
    echo "$control_node_key".pub
}

lsrPrepareGlobalInventory() {
    # Prepare inventory file containing all managed nodes
    local inventory is_virtual  managed_nodes
    inventory=$(mktemp -t inventory-XXX.yml)
    # TMT_TOPOLOGY_ variables are not available in tmt try.
    # Reading topology from guests.yml for compatibility with tmt try
    is_virtual=$(lsrIsVirtual "$TMT_TREE_PROVISION")
    managed_nodes=$(lsrGetManagedNodes)
    control_node_name=$(lsrGetNodeName "control-node")
    echo "---
all:
  hosts:" > "$inventory"
    for managed_node in $managed_nodes; do
        ip_addr=$(lsrGetNodeIp "$managed_node")
        {
        echo "    $managed_node:"
        echo "      ansible_host: $ip_addr"
        echo "      ansible_ssh_extra_args: \"-o StrictHostKeyChecking=no\""
        } >> "$inventory"
        if [ "$is_virtual" -eq 0 ]; then
            echo "      ansible_ssh_private_key_file: ${TMT_TREE_PROVISION}/$control_node_name/id_ecdsa" >> "$inventory"
        fi
    done
    rlRun "echo $inventory"
}

lsrPrepareNodesInventories() {
    local inventory managed_nodes ip_addr
    # TMT_TOPOLOGY_ variables are not available in tmt try.
    # Reading topology from guests.yml for compatibility with tmt try
    managed_nodes=$(lsrGetManagedNodes)
    control_node_key=$(lsrGenerateAnsibleSSHKey)
    lsrDistributeAnsibleSSHKey "$managed_nodes"
    for node in $managed_nodes; do
        inventory=/tmp/inventory_"${node}".yml
        if [ ! -f "$inventory" ]; then
            ip_addr=$(lsrGetNodeIp "$node")
            {
            echo "---"
            echo "all:"
            echo "  hosts:"
            echo "    $node:"
            echo "      ansible_host: $ip_addr"
            echo "      ansible_ssh_extra_args: \"-o StrictHostKeyChecking=no\""
            echo "      ansible_ssh_private_key_file: $control_node_key"
            } >> "$inventory"
        fi
    done
}

lsrIsVirtual() {
    # Returns 0 if provisioned with "how: virtual"
    grep -q 'how: virtual' "$TMT_TREE_PROVISION"/step.yaml
    echo $?
}

lsrUploadLogs() {
    local logfile=$1
    local role_name=$2
    local id_rsa_path pr_substr os artifact_dirname target_dir
    rlFileSubmit "$logfile"
    if [ -z "$SR_LSR_SSH_KEY" ]; then
        return
    fi
    id_rsa_path=$(mktemp -t id_rsa-XXXXX)
    echo "$SR_LSR_SSH_KEY" | \
        sed -e 's|-----BEGIN OPENSSH PRIVATE KEY----- |-----BEGIN OPENSSH PRIVATE KEY-----\n|' \
        -e 's| -----END OPENSSH PRIVATE KEY-----|\n-----END OPENSSH PRIVATE KEY-----|' > "$id_rsa_path" # notsecret
    chmod 600 "$id_rsa_path"
    if [ -z "$SR_ARTIFACTS_DIR" ]; then
        control_node_name=$(lsrGetNodeName "control-node")
        os=$(lsrGetNodeOs "$control_node_name")
        printf -v date '%(%Y%m%d-%H%M%S)T' -1
        if [ -z "$SR_PR_NUM" ]; then
            pr_substr=_main
        else
            pr_substr=_$SR_PR_NUM
        fi
        artifact_dirname=tmt-"$role_name""$pr_substr"_"$os"_"$date"/artifacts
        target_dir="/srv/pub/alt/linuxsystemroles/logs"
        SR_ARTIFACTS_DIR="$target_dir"/"$artifact_dirname"
        SR_ARTIFACTS_URL=https://dl.fedoraproject.org/pub/alt/linuxsystemroles/logs/$artifact_dirname/
    fi
    rlRun "ssh -i $id_rsa_path -o StrictHostKeyChecking=no $SR_LSR_USER@$SR_LSR_DOMAIN mkdir -p $SR_ARTIFACTS_DIR"
    chmod +r "$GUESTS_YML"
    rlRun "scp -i $id_rsa_path -o StrictHostKeyChecking=no $logfile $GUESTS_YML $SR_LSR_USER@$SR_LSR_DOMAIN:$SR_ARTIFACTS_DIR/"
    rlLogInfo "Logs are uploaded at $SR_ARTIFACTS_URL"
    rlRun "rm $id_rsa_path"
}

lsrArrtoStr() {
    local keys values key value
    local arr_name=$1
    # Convert associative array into a space separated key=value list
    eval "keys=(\${!${arr_name}[@]})"
    eval "values=(\${${arr_name}[@]})"
    for i in $(seq 0 $((${#keys[@]} - 1))); do
        key="${keys[$i]}"
        value="${values[$i]}"
        printf "%s=%s " "$key" "$value"
    done
    echo
}

lsrGetNodeInventory() {
    local node="$1"
    local inventory
    inventory=/tmp/inventory_${node}.yml
    if [ -f "$inventory" ]; then
        echo "$inventory"
    else
        rlLogError "Error: No inventory file found for node '${node}'"
        return 1
    fi
}

lsrRunAusearch() {
    local start_date=$1
    local start_time=$2
    local role_name=$3
    local playbook_basename=$4
    local node=$5
    local ausearch_out logfile_name control_node_name

    ausearch_cmd=(/sbin/ausearch --input-logs -sv no -m AVC -m USER_AVC -m SELINUX_ERR --start "$start_date" "$start_time" --end now)
    if [ -n "$node" ]; then
        ausearch_out=$(lsrExecuteOnNode "$node" "${ausearch_cmd[*]} 2>/dev/null" "false")
    else
        ausearch_out=$("${ausearch_cmd[@]}" 2>/dev/null)
    fi

    rlLogDebug "lsrRunAusearch ausearch_cmd=${ausearch_cmd[*]}"
    rlLogDebug "lsrRunAusearch node=$node"
    rlLogDebug "lsrRunAusearch ausearch_out=$ausearch_out"

    if [ -n "$ausearch_out" ]; then
        logfile_name=ausearch-"${role_name}"
        if [ -n "$playbook_basename" ]; then
            logfile_name+=-"${playbook_basename}"
        fi
        if [ -n "$node" ]; then
            logfile_name+=-"${node}"
        else
            control_node_name=$(lsrGetNodeName "control-node")
            logfile_name+=-"${control_node_name}"
        fi
        logfile_name+=-FAIL.log
        echo "$ausearch_out" > "$logfile_name"
        rlLogError "$role_name: uploading SELinux denials in $logfile_name"
        lsrUploadLogs "$logfile_name" "$role_name"
    fi
}

lsrRunPlaybook() {
    local test_playbook=$1
    local inventory=$2
    local skip_tags=$3
    local node=$4
    local LOGFILE=$5
    local verbosity="$6"
    local result=FAIL
    local cmd log_msg role_name playbook_basename playbook_start_date playbook_start_time nodes
    role_name=$(lsrGetRoleNameFromTestPlaybook "$test_playbook")
    playbook_basename=$(basename "$test_playbook")

    # When $inventory is impty, $node is required to find inventory
    if [ -z "$inventory" ]; then
        inventory=$(lsrGetNodeInventory "$node")
    fi

    # When $node is empty, it implies that inventory contains multiple nodes
    nodes=$(grep -E '^\s{4}[a-zA-Z0-9.-]+:' "$inventory" | \
        awk -F':' '{print $1}' | \
        sed -E 's/^\s*|\s*$//g' | \
        tr '\n' ' ' | \
        sed 's/ $//')
    if [ "${GET_PYTHON_MODULES:-}" = true ]; then
        ANSIBLE_ENVS[ANSIBLE_DEBUG]=true
    fi
    cmd="$(lsrArrtoStr ANSIBLE_ENVS) ansible-playbook -i $inventory $skip_tags $test_playbook $verbosity"
    log_msg="$role_name: $playbook_basename with ANSIBLE-$SR_ANSIBLE_VER on $nodes"
    playbook_start_date=$(date '+%m/%d/%Y')
    playbook_start_time=$(date '+%H:%M:%S')
    playbook_start_ts=$(date '+%Y-%m-%d %H:%M:%S')

    # If SR_TFT_DEBUG is true, print output to terminal
    if [ "$SR_TFT_DEBUG" == true ]; then
        rlRun "ANSIBLE_LOG_PATH=$LOGFILE $cmd && result=SUCCESS" 0 "$log_msg"
    else
        rlRun "$cmd &> $LOGFILE && result=SUCCESS" 0 "$log_msg"
    fi
    for node_name in $nodes; do
        lsrRunAusearch "$playbook_start_date" "$playbook_start_time" "$role_name" "$playbook_basename" "$node_name"
    done

    logfile_name=$LOGFILE-$result.log
    mv "$LOGFILE" "$logfile_name"
    LOGFILE=$logfile_name
    if [ "$role_name" = podman ]; then
        if grep "${ANSIBLE_ENVS[SYSTEM_ROLES_PODMAN_PASSWORD]}" "$LOGFILE"; then
            rlLogError "podman password found in log files"
        fi
    fi
    if [ "$result" = FAIL ]; then
        # collect journald output from failed machine
        for node_name in $nodes; do
            lsrExecuteOnNode "$node_name" "journalctl --since '$playbook_start_ts' -ex 2>/dev/null" "false" >> "$LOGFILE"
        done
    fi

    lsrUploadLogs "$LOGFILE" "$role_name"
    if [ "${GET_PYTHON_MODULES:-}" = true ]; then
        cmd="$(lsrArrtoStr ANSIBLE_ENVS) ansible-playbook -i $inventory $skip_tags process_python_modules_packages.yml -vv"
        local packages="$LOGFILE.packages"
        rlRun "$cmd -e packages_file=$packages -e logfile=$LOGFILE &> $LOGFILE.modules" 0 "process python modules"
        lsrUploadLogs "$LOGFILE.modules" "$role_name"
        lsrUploadLogs "$packages" "$role_name"
    fi
}

lsrGetRoleNameFromTestsPath() {
    local tests_path=$1
    local test_dir role_dir_abs legacy_name
    test_dir=$(basename "$tests_path")
    if [ "$test_dir" = tests ]; then # legacy role format
        role_dir_abs=$(dirname "$tests_path")
        legacy_name=$(basename "$role_dir_abs")
        echo "$legacy_name" | cut -d'.' -f2
    else # collection format
        echo "$test_dir"
    fi
}

lsrGetRoleNameFromTestPlaybook() {
    local test_playbook=$1
    local tests_path
    tests_path=$(dirname "$test_playbook")
    lsrGetRoleNameFromTestsPath "$tests_path"
}

lsrRunPlaybooksParallel() {
    # Run playbooks on managed nodes one by one
    # Supports running against a single node too
    local skip_tags=$1
    local test_playbooks=$2
    local managed_nodes=$3
    local rolename_in_logfile=$4
    local verbosity=$5
    local role_name test_playbooks_arr inventory

    read -ra test_playbooks_arr <<< "$test_playbooks"
    while_test_pbs_arr_c=0
    while [ "${#test_playbooks_arr[*]}" -gt 0 ]; do
        ((while_test_pbs_arr_c++))
        if (( while_test_pbs_arr_c % 360 == 0 )); then
            rlLogInfo "In the loop 'while [ \${#test_playbooks_arr[*]}' ... iteration $while_test_pbs_arr_c"
            rlLogInfo "{#test_playbooks_arr[*]}: ${#test_playbooks_arr[*]}"
            rlLogInfo "{test_playbooks_arr[*]}: ${test_playbooks_arr[*]}"
        fi
        for managed_node in $managed_nodes; do
            inventory=$(lsrGetNodeInventory "$managed_node")
            if ! pgrep -af "ansible-playbook" | grep -q " -i $inventory "; then
                test_playbook=${test_playbooks_arr[0]}
                test_playbooks_arr=("${test_playbooks_arr[@]:1}") # Remove first element from array
                playbook_basename=$(basename "$test_playbook")
                if [ "$rolename_in_logfile" == true ]; then
                    role_name=$(lsrGetRoleNameFromTestPlaybook "$test_playbook")
                    LOGFILE="$role_name"-"${playbook_basename%.*}"-ANSIBLE-"$SR_ANSIBLE_VER"-$TMT_PLAN
                else
                    LOGFILE="${playbook_basename%.*}"-ANSIBLE-"$SR_ANSIBLE_VER"-$TMT_PLAN
                fi
                lsrRunPlaybook "$test_playbook" "" "$skip_tags" "$managed_node" "$LOGFILE" "$verbosity" &
                sleep 1
                break
            fi
        done
        sleep 1
    done
    # Wait for the last test to finish
    while_playbook_ps_c=0
    while true; do
        ((while_playbook_ps_c++))
        if ! pgrep -af "ansible-playbook" | grep -q "$tests_path"; then
            break
        fi
        if (( while_playbook_ps_c % 1800 == 0 )); then
            rlLogInfo "In the loop 'while true' ... iteration $while_playbook_ps_c"
            rlLogInfo "$(pgrep -af "ansible-playbook" | grep "$tests_path")"
            rlLogInfo "{test_playbooks_arr[*]}: ${test_playbooks_arr[*]}"
        fi
        sleep 1
    done
    # After all playbooks finish, sleep 5s to wait for uploading logs in lsrUploadLogs
    sleep 5
}

lsrDistributeSSHKeys() {
    local control_node_key_pub control_node_name
    control_node_name=$(lsrGetNodeName "control-node")
    control_node_key_pub=$(lsrGetNodeKeyPublic "$control_node_name")
    control_node_key_pub_content=$(cat "$control_node_key_pub")
    if [ -f "$control_node_key_pub" ] && ! grep "$control_node_key_pub_content" ~/.ssh/authorized_keys; then
        rlRun "cat $control_node_key_pub >> ~/.ssh/authorized_keys"
    fi
}

lsrDistributeAnsibleSSHKey() {
    local managed_nodes=$1
    local control_node_key_pub managed_nodes
    managed_nodes=$(lsrGetManagedNodes)
    control_node_key_pub=$(lsrGetAnsibleKeyPublic)
    if [ -z "$control_node_key_pub" ]; then
        rlLogError "control_node_key_pub is empty"
    fi
    for managed_node in $managed_nodes; do
        lsrCopyToNode "$managed_node" "$control_node_key_pub" "/var/tmp/" "true"
        lsrExecuteOnNode "$managed_node" \
            "cat $control_node_key_pub | tee --append ~/.ssh/authorized_keys" \
            "true"
    done
}

lsrSetHostname() {
    hostname=$(lsrGetCurrNodeHostname)
    rlRun "hostnamectl set-hostname $hostname"
}

lsrBuildEtcHosts() {
    managed_nodes=$(lsrGetManagedNodes)
    for managed_node in $managed_nodes; do
        managed_node_ip=$(lsrGetNodeIp "$managed_node")
        if ! grep -q "$managed_node_ip $managed_node" /etc/hosts; then
            rlRun "echo $managed_node_ip $managed_node >> /etc/hosts"
        fi
    done
    rlRun "cat /etc/hosts"
}

lsrEnableHA() {
# This function enables the ha repository on platforms that require it and do not have it enabled by default
# The ha repository is required by the mssql and ha_cluster roles
    local ha_reponame
    if rlIsRHELLike 7; then
        return
    fi
    if rlIsRHELLike 8; then
        ha_reponame=ha
    elif rlIsRHELLike ">8"; then
        ha_reponame=highavailability
    fi
    if [ -n "$ha_reponame" ]; then
        rlRun "dnf config-manager --set-enabled $ha_reponame"
    fi
}

lsrDisableNFV() {
    # The nfv-source repo causes troubles in CentOS-9 Stream compose while system-roles testing
    if [ "$(find /etc/yum.repos.d/ -name 'centos-addons.repo' | wc -l )" -gt 0 ]; then
        rlRun "sed -i '/^\[nfv-source\]/,/^$/d' /etc/yum.repos.d/centos-addons.repo"
    fi
}

lsrDiskProvisionerRequired() {
# check if the test requires additional disk devices
# to be provisioned
    local tests_path=$1
    local provision_fmf="$tests_path/provision.fmf"
    if grep -q "drive:" "$provision_fmf" 2> /dev/null; then
        return 0
    fi
    return 1
}

lsrGetIdentityFile() {
    local node=$1
    local is_virtual node_key

    is_virtual=$(lsrIsVirtual)
    if [ "$is_virtual" -eq 0 ]; then
        node_key=$(lsrGetNodeKeyPrivate "$node")
        echo "-i $node_key"
    fi
}

lsrCopyToNode() {
    local node=$1
    local cp_files=$2
    local dest_path=$3
    local forward_to_log=$4
    local identity_file_args node_ip scp_cmd logfile
    logfile="$node"_tf.log
    identity_file_args=$(lsrGetIdentityFile "$node")
    node_ip=$(lsrGetNodeIp "$node")
    # Passing some variables without quotes to avoid shell considering them a single argument
    # shellcheck disable=SC2206
    scp_cmd=(scp $identity_file_args -o StrictHostKeyChecking=no $cp_files root@"$node_ip":"$dest_path")
    if [ "$forward_to_log" == true ]; then
        {
            echo "\$ ${scp_cmd[*]}"
            "${scp_cmd[@]}"
            echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
        } &>> "$logfile"
    else
        "${scp_cmd[@]}"
    fi
}

lsrExecuteOnNode() {
    local node=$1
    local cmd=$2
    local forward_to_log=$3
    local identity_file_args node_ip ssh_cmd logfile
    logfile="$node"_tf.log
    identity_file_args=$(lsrGetIdentityFile "$node")
    node_ip=$(lsrGetNodeIp "$node")
    # Passing identity_file_args without quotes to avoid shell considering it a single argument
    # shellcheck disable=SC2206
    ssh_cmd=(ssh $identity_file_args -o StrictHostKeyChecking=no root@"$node_ip" "$cmd")
    if [ "$forward_to_log" == true ]; then
        {
            echo "\$ ${ssh_cmd[*]}"
            "${ssh_cmd[@]}"
            echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
        } &>> "$logfile"
    else
        "${ssh_cmd[@]}"
    fi
}

lsrGenerateTestDisks() {
    local tests_path=$1
    local action=$2
    local disk_provisioner_script=$3
    local managed_node=$4
    local provisionfmf="$tests_path"/provision.fmf
    local disk_provisioner_dir disk_provisioner_basename disk_provisioner_tmp
    disk_provisioner_basename=$(basename "$disk_provisioner_script")
    disk_provisioner_tmp=/tmp/$disk_provisioner_basename
    if ! lsrDiskProvisionerRequired "$tests_path"; then
        return 0
    fi
    if [ "$action" != start ] && [ "$action" != stop ]; then
        rlDie "With lsrGenerateTestDisks, action must be either start or stop. Provided action: $action"
    fi

    available=$(lsrExecuteOnNode "$managed_node" "df -k /tmp --output=avail | tail -1" "false")
    # rlLog "Available disk space: $available"
    if [ "$available" -gt 10485760 ]; then
        disk_provisioner_dir=/tmp/disk_provisioner
    else
        disk_provisioner_dir=/var/tmp/disk_provisioner
    fi
    lsrCopyToNode "$managed_node" "$disk_provisioner_script $provisionfmf" "/tmp/" \
        "true"
    lsrExecuteOnNode "$managed_node" \
        "chmod +x $disk_provisioner_tmp" \
        "true"
    lsrExecuteOnNode "$managed_node" \
        "WORK_DIR=$disk_provisioner_dir FMF_DIR=/tmp/ $disk_provisioner_tmp $action" \
        "true"
    # Print devices
    lsrExecuteOnNode "$managed_node" \
        "echo $managed_node ; fdisk -l | grep 'Disk /dev/' ; lsblk -l | cut -d\  -f1 | grep -v NAME | sed 's/^/\/dev\//' | xargs ls -l" \
        "true"
}

lsrAppendHostVarsToInventory() {
    local keys values key value
    local inventory=$1
    # Name of array where:
    #   name or array - name a managed node to set vars for
    #   keys - managed nodes to set vars for
    #   values - vars values
    local arr_name=$2
    eval "keys=(\${!${arr_name}[@]})"
    eval "values=(\${${arr_name}[@]})"
    rlRun "cat $inventory"
    for i in $(seq 0 $((${#keys[@]} - 1))); do
        key="${keys[$i]}"
        if grep "$key" "$inventory"; then
            value="${values[$i]}"
            rlRun "sed -i \"/$key:/a\ \ \ \ \ \ $arr_name: $value\" $inventory"
        fi
    done
    rlRun "cat $inventory"
}

# prepare test playbooks for gathering information about python
# module usage
lsrSetupGetPythonModules() {
    local test_pbs=$1
    for test_pb in $test_pbs; do
        cp "$test_pb" "$test_pb.orig"
        sed -e '/^  hosts:/a\
  environment:\
    PYTHONVERBOSE: "1"' -i "$test_pb"
    done
}

lsrSetAnsibleGathering() {
    local value=$1
    if [[ ! $value =~ ^(implicit|explicit|smart)$ ]]; then
        rlLogError "Value for SR_ANSIBLE_GATHERING must be one of implicit, explicit, smart"
        rlLogError "Provided value: $value"
        return 1
    fi
    ANSIBLE_ENVS[ANSIBLE_GATHERING]="$value"
}

lsrSubmitManagedNodesLogs() {
    managed_nodes=$(lsrGetManagedNodes)
    for node in $managed_nodes; do
        rlFileSubmit "${node}_tf.log"
    done
}

lsrReserveSystems() {
    local reserve_systems=$1
    local control_node_ip_addr tf_run_id
    if [ "$reserve_systems" = true ]; then
        control_node_ip_addr=$(hostname -I | awk '{print $1}')
        tf_run_id=$(grep -Po 'TESTING_FARM_REQUEST_ID: \K.*' "$TMT_TREE_DISCOVER"/tests.yaml)
        rlLogInfo "SR_RESERVE_SYSTEMS=true, 'sleep 36660' to sleep 10 hours to keep machines for troubleshooting"
        rlLogInfo "You can continue the request by killing the sleep process with this cmd:"
        rlLogInfo "$ ssh -i /usr/share/qa-tools/1minutetip/1minutetip root@$control_node_ip_addr \"pkill -f 'sleep 36660' || echo ERROR\""
        rlLogInfo "Or you can cancel the request with the this cmd:"
        rlLogInfo "TESTING_FARM_API_TOKEN=\"\$tftoken\" testing-farm cancel https://api.dev.testing-farm.io/v0.1/requests/$tf_run_id"
        sleep 36660
    fi
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
rolesUpstreamLibraryLoaded() {
    rlLog "Library loaded!"
    return 0
}
