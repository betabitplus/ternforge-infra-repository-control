# Repository control runbook

`fleet.auto.tfvars.json` is the single committed fleet inventory. Do not edit managed repository settings, rulesets, topics, Actions permissions, variables, or Release App membership manually; change the OpenTofu source and review the resulting plan.

## Validate

```sh
tofu fmt -check -recursive
tofu init -backend=false -input=false -lockfile=readonly
tofu validate
```

CI also runs a backend-free read-only plan from an ephemeral copy of the OpenTofu files.

## Plan and apply

Use the protected GitHub Actions environment `repository-control-apply` and the manual `repository control` workflow. The workflow obtains a 600-second Scalr credential through GitHub OIDC, verifies the Scalr workspace is state-only (`execution-mode=local`, `operations=false`, remote backend enabled), checks the repository-control PAT scopes and frozen baseline SHA, then runs a reviewed OpenTofu plan and apply.

Task 0005 bootstrap/adoption is complete. Steady-state execution does not contain import, repository-bootstrap, or template-render branches.

The repository-control classic PAT has exactly `repo`, `workflow`, and `read:user`: `repo` mutates repositories/App membership, `workflow` permits bootstrap workflow files, and provider `6.13.0` needs read-only `read:user` to refresh selected-repository App membership through GitHub's user-installation list endpoint.

## Drift

A clean fleet must return exit code 0:

```sh
tofu plan -detailed-exitcode -input=false
```

Exit code 2 means drift or an intended change and must be reviewed before apply. Exit code 1 is an error.

## Rollback

Rollback one repository at a time by reverting the OpenTofu change (or temporarily disabling the affected ruleset in OpenTofu), running the protected apply, and then restoring corrected desired state. Do not introduce a fleet-wide rollback control plane.

Never commit or upload `.terraform/`, state, state backups, saved plans, credentials, or tokens.
