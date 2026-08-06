# CI Testing Plans

Leapp CI runs [tmt](https://tmt.readthedocs.io/en/stable/index.html) test plans in [Testing Farm](https://docs.testing-farm.io/Testing%20Farm/0.1/index.html) with the [testing-farm.yml](https://github.com/redhat-cop/infra.leapp/blob/main/.github/workflows/testing-farm.yml) GitHub workflow.

## Plan Structure

Plans use FMF inheritance. The base plan `plans/main.fmf` contains shared configuration (provisioning, environment, prepare steps, setup discover). Child plans inherit from it and add scope-specific discover filters:

- `plans/integration/main.fmf` — discovers tests tagged `integration`. Uses TMT context `upgrade_type` to filter by upgrade subtype (e.g., `custom`). Without the context, all integration tests are discovered.
- `plans/remediation/main.fmf` — discovers tests tagged `remediation`, filtered by managed node version (`7to8`, `8to9`, `9to10`)
- `plans/role/main.fmf` — discovers tests tagged `role_test`

Each child plan gets three discover steps: `prep_managed_node` + `setup_control_node` (inherited from base) + scope-specific tests (added by child).

## Running Tests

You can run tests locally with `tmt try` or remotely in Testing Farm. In CI, tests are triggered by commenting `/citest` on a pull request.

### CI (`/citest`)

Comment on a PR to trigger tests:

```
/citest integration           — run all integration upgrade types
/citest integration custom    — run only custom upgrade type
/citest remediation           — run remediation tests
/citest role                  — run role tests
```

The workflow parses the scope and optional subtype from the comment, builds a matrix from `.github/test-matrix.json` (which contains `managed_node`, `upgrade_type`, and `ansible_version`), and submits requests to Testing Farm. Both `managed_node` and `upgrade_type` are passed as TMT context dimensions so plans can filter tests and select version-specific configuration.

### Running Tests Locally

1. Install `tmt` as described in [Installation](https://tmt.readthedocs.io/en/stable/stories/install.html).
2. Change to the collection repository directory.
3. In `plans/main.fmf`, provide the URL to `leapp_coll_env_file` stored in Red Hat GitLab in the `environment-file` entry.
4. Run a command to run on local VMs or on 1minutetip VMs:

    ```bash
    # Provision local VMs — all integration tests
    $ tmt -c managed_node=<platform> try -p /plans/integration
    # Only custom upgrade type
    $ tmt -c managed_node=<platform> -c upgrade_type=custom try -p /plans/integration
    # Provision VMs in 1minutetip
    $ tmt -c 1minutetip=true -c managed_node=<platform> try -p /plans/integration
    ```

    `<platform>` can be `rhel7`, `rhel8`, or `rhel9`.

### Running in Testing Farm

1. Install `testing-farm` as described in [Installation](https://gitlab.com/testing-farm/cli/-/blob/main/README.adoc#user-content-installation).
2. Change to the collection repository directory.
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
        -c initiator=testing-farm \
        -c managed_node=rhel8 \
        -c control_node=rhel9 \
        -c upgrade_type=custom \
        --tag user=spetrosi \
        --tag purpose=test-leapp \
        --no-wait
    ```
