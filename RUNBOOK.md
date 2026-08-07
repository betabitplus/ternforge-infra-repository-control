# Repository control runbook

`fleet.auto.tfvars.json` is the single committed fleet inventory. Do not edit managed repository settings, rulesets, topics, Actions permissions, variables, or Release App membership manually; change the OpenTofu source and review the resulting plan.

## Validate

```sh
tofu fmt -check -recursive
tofu init -backend=false -input=false -lockfile=readonly
tofu validate
```

CI also runs a backend-free read-only plan from an ephemeral copy of the OpenTofu files.

## Bootstrap a repository before enrollment

Repository files and Copier provenance are created before repository-control enrollment. Use the already approved exact released Ternforge Copier template for the repository role; do not make OpenTofu a second template/file owner.

A minimal owner-operated bootstrap is:

```sh
repo="ternforge-example"
template="https://github.com/betabitplus/<released-template>.git"
ref="vX.Y.Z"
workdir="$(mktemp -d)"

uvx --from copier==9.17.0 copier copy --vcs-ref "$ref" "$template" "$workdir/$repo" \
  --data repository_name="$repo"

git -C "$workdir/$repo" init -b main
git -C "$workdir/$repo" add .
git -C "$workdir/$repo" commit -m "chore: bootstrap repository"
gh repo create "betabitplus/$repo" --source "$workdir/$repo" --remote origin --push
rm -rf "$workdir"
```

Supply the template's other required Copier answers explicitly. Verify `.copier-answers.yml`, `main`, and the role-owned `ci / required` workflow before enrollment. At this point the repository is intentionally outside the managed fleet.

Enroll it with one normal PR that adds exactly one sorted entry to `fleet.auto.tfvars.json`. The permanent configuration-driven OpenTofu `import` block adopts the existing `github_repository` object; the reviewed apply then converges settings, rulesets, variables, security controls, and GitHub App access. No bootstrap flag, custom onboarding CLI, `github_repository_file` tree, or synthetic bootstrap PR is used.

## Plan and apply

Use the manual `repository control` workflow on `main`. The protected `repository-control-apply` environment is restricted to `main`, requires the owner reviewer, and does not allow administrator bypass.

The workflow has two protected jobs:

1. Approve `repository control / plan`. It obtains the environment PAT and a 600-second Scalr credential, verifies the state-only workspace/PAT/frozen baseline, builds a fresh OpenTofu plan, and publishes the human-readable plan plus a canonical resource-changes digest in the Job Summary.
2. Review that plan, then approve `repository control / apply`. It repeats the preflight, re-plans, requires the canonical digest to match the reviewed plan, and applies only that runner-local saved plan.

Saved plan files and plan JSON are ephemeral runner files and are never uploaded as artifacts. A changed re-plan fails closed and must be reviewed in a new workflow run.

The repository-control classic PAT has exactly `repo` and read-only `read:user`: `repo` is required for repository administration and selected-repository GitHub App membership; provider `6.13.0` needs `read:user` to refresh selected-repository membership through GitHub's user-installation repository listing endpoint. `workflow` is not part of the steady-state PAT because bootstrap workflow files are created before enrollment.

## Rotate or revoke the repository-control PAT

Normal rotation:

1. Create a replacement classic PAT with exactly `repo` + `read:user` and no expiration only if the accepted steady-state policy still requires a persistent PAT.
2. Replace `TERNFORGE_REPOSITORY_CONTROL_TOKEN` in the protected `repository-control-apply` environment. Do not save a second plaintext copy.
3. Run the protected workflow through both approvals and require a no-drift result.
4. Delete/revoke the old PAT and confirm the replacement is the only repository-control token left.

If compromise is suspected, reverse the first part: revoke the old PAT immediately, then create the replacement, replace the environment secret, and run the protected verification.

If GitHub later supports a narrower credential for selected-repository App membership, replace the classic PAT through a reviewed architecture change rather than retaining it for convenience.

## Drift

A clean fleet must return exit code 0:

```sh
tofu plan -detailed-exitcode -input=false
```

Exit code 2 means drift or an intended change and must be reviewed before apply. Exit code 1 is an error.

## Rollback

Rollback one repository at a time by reverting the OpenTofu change (or temporarily disabling the affected ruleset in OpenTofu), running the protected apply, and then restoring corrected desired state. Do not introduce a fleet-wide rollback control plane.

Never commit or upload `.terraform/`, state, state backups, saved plans, plan JSON, credentials, or tokens.
