# Introduction CI Testing Plans

Leapp CI runs [tmt](https://tmt.readthedocs.io/en/stable/index.html) test plans in [Testing farm](https://docs.testing-farm.io/Testing%20Farm/0.1/index.html) with the [tft.yml](https://github.com/redhat-cop/infra.leapp/blob/main/.github/workflows/tft.yml) GitHub workflow.

The `plans/test_playbooks.fmf` plan is a test plan that runs test playbooks in parallel on multiple managed nodes.

The `plans/test_playbooks_parallel.fmf` plan does the following steps:

1. Provisions systems to be used as a control node and as managed nodes.
2. Does the required preparation on systems.
3. Run test playbooks matching the pattern `tests_*.yml` from each role's tests directory, and from the root of the collection from [test.sh](https://github.com/redhat-cop/infra.leapp/blob/main/tests/tmt/test_playbooks/test_playbooks.sh).

The [tft.yml](https://github.com/redhat-cop/infra.leapp/blob/main/.github/workflows/tft.yml) workflow runs the above plan and uploads the results to our Fedora storage for public access.

This workflow uses Testing Farm's Github Action [Schedule tests on Testing Farm](https://github.com/marketplace/actions/schedule-tests-on-testing-farm).

## Running Tests

You can run tests locally with the `tmt try` cli or remotely in Testing Farm.

### Running Tests Locally

1. Install `tmt` as described in [Installation](https://tmt.readthedocs.io/en/stable/stories/install.html).
2. Change to the role repository directory.
3. Optionally, modify `plans/test_playbooks_parallel.fmf` to modify variables to suit your requirements.
4. In the plan `plans/test_playbooks_parallel.fmf`, uncomment environment-file and provide a URL to leapp_coll_env_file stored in Red Hat GitLab.
5. Run a command to run on local VMs or on 1minutetip VMs:

    ```bash
    # Provision local VMs
    $ tmt -c COMPOSE_MANAGED_NODE=<platform> try -p /plans/test_playbooks
    # Provision VMs in 1minutetip
    $ tmt -c 1minutetip=true -c COMPOSE_MANAGED_NODE=<platform> try -p /plans/test_playbooks
    ```

    `<platform>` can be `rhel7`, `rhel8`, or `rhel9`.

### Running in Testing Farm

1. Install `testing-farm` as described in [Installation](https://gitlab.com/testing-farm/cli/-/blob/main/README.adoc#user-content-installation).
2. Change to the role repository directory.
3. If you want to run tests with edits in your branch, you need to commit and push changes first to some branch.
4. Save the environment file to `leapp_coll_env_file`. TF doesn't allow providing URL for environment-files.
5. Enter `testing-farm request`.
    Edit to your needs.

    ```bash
    $ TESTING_FARM_API_TOKEN="$tftoken" \
        testing-farm request --pipeline-type="tmt-multihost" \
        --git-url https://github.com/redhat-cop/infra.leapp \
        --git-ref main \
        -e @leapp_coll_env_file \
        -e SR_REPO_NAME=infra.leapp \
        -e SR_GITHUB_ORG=redhat-cop \
        -e SR_PR_NUM=303 \
        -e SR_TEST_LOCAL_CHANGES=false \
        -e COMPOSE_CONTROLLER=RHEL-9-Nightly \
        -e COMPOSE_MANAGED_NODE=RHEL-8.10.0-Nightly \
        -e 'SR_EXCLUDED_TESTS=""' \
        -e 'SR_ONLY_TESTS=""' \
        -e SR_RESERVE_SYSTEMS=false \
        -c initiator=testing-farm \
        --tag user=spetrosi \
        --tag purpose=test-leapp \
        --no-wait
    ```
