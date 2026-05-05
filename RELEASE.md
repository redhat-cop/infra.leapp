# Releasing the collection

Maintainers publish a new **Ansible Galaxy** version and matching **GitHub release** using two automations in this repository.

## Before you start

Agree with the other maintainers that a release is appropriate (meeting, Slack, or whatever works for your team). If there is a general consensus, continue.

You need **write access** to this GitHub repository to run the changelog workflow and to merge the resulting pull request.

## Choosing the version

Review what has landed on the default branch. Release-relevant changes should already be described by YAML files under [`changelogs/fragments/`](https://github.com/redhat-cop/infra.leapp/tree/main/changelogs/fragments).

Follow [Semantic Versioning](https://semver.org/) when picking `X.Y.Z` (no `v` prefix):

- **major** — breaking or incompatible API or behavior changes
- **minor** — new features or enhancements in a backward-compatible way
- **patch** — backward-compatible bug fixes, small `minor_changes`, documentation-only updates, and similar low-risk changes

The workflow will refuse to run if that **tag** already exists on the remote, or if `galaxy.yml` is already at the version you enter.

## Repository setup (once)

- Create the labels **`release-on-merge`**, **`changelog`**, and **`automated pr`** under **Issues → Labels** if they do not exist (the changelog PR receives all three automatically). The **Requires changelog** job already accepts pure release diffs (see ansible-content-actions `validate_changelog.py`); add the **`skip-changelog`** label only if you must open a release-style PR that also changes other paths and CI incorrectly demands a fragment.
- Under **Settings → Actions → General → Workflow permissions**, use **Read and write permissions** so `GITHUB_TOKEN` can open the PR and the release job can push tags and create the GitHub release.

## 1. Generate changelog and open a release PR

1. Open **Actions**: [Workflow runs](https://github.com/redhat-cop/infra.leapp/actions).
2. Select **Generate changelog and open release PR** (`.github/workflows/generate-changelog-and-release.yml`).
3. Click **Run workflow**, choose the default branch, and enter the new **version** as `X.Y.Z`.
4. The workflow will:
   - set `version` in `galaxy.yml` to the value you entered;
   - run [`antsibull-changelog`](https://docs.ansible.com/projects/antsibull-changelog/) `release` so fragments are folded into `CHANGELOG.rst` and `changelogs/changelog.yaml`;
   - build the collection, install the tarball, and run **ansible-lint** (`--offline`) on that snapshot—the same build/install/lint pattern as the reusable [ansible-lint workflow](https://github.com/redhat-cop/infra.leapp/blob/main/.github/workflows/ansible-lint.yml). If lint fails, **no PR is opened**.
   - open a **pull request** against the default branch, labeled **`release-on-merge`**, **`changelog`**, and **`automated pr`**.

After the PR exists, the normal **CI** workflow (`.github/workflows/ansible-test.yml`) also runs **ansible-lint** on the pull request, so reviewers see lint in the PR checks.

Review the PR (changelog text and version bump) before merging.

## 2. Merge the PR to trigger the release

When that PR is **merged** into the default branch and still has **`release-on-merge`**, **Release** runs (`.github/workflows/release.yml`). In short it:

1. checks out the **merge commit**, builds the collection with **`ansible-galaxy collection build`**;
2. installs the built **`.tar.gz`** with **`ansible-galaxy collection install`** to verify the artifact;
3. creates the **git tag** and **GitHub release** (notes from `CHANGELOG.rst`, tarball attached);
4. **publishes** the same tarball to **Ansible Galaxy** ([published collection](https://galaxy.ansible.com/ui/repo/published/infra/leapp/)).

Lint is intentionally **not** re-run here: it already ran when the changelog workflow prepared the tree, and again on the PR via CI before merge.

For step-by-step job logic, read [`.github/workflows/release.yml`](https://github.com/redhat-cop/infra.leapp/blob/main/.github/workflows/release.yml).

If **branch protection** blocks `github-actions[bot]` from opening or merging PRs or from pushing tags, adjust branch rules or use a PAT as your organization requires.
