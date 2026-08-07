# Repository control runbook

`fleet.auto.tfvars.json` is the only fleet inventory. Change managed GitHub state through OpenTofu, not by hand.

## Validate

```sh
tofu fmt -check -recursive
tofu init -backend=false -input=false -lockfile=readonly
tofu validate
```

## Bootstrap and enroll

A repository gets its files before it enters the fleet:

1. Render the exact released Copier template with all required answers.
2. Add the role-owned CI/release files required by that repository; initial `main` must expose `ci / required`.
3. Commit the initial `main` and create the repository with explicit visibility:

   ```sh
   repo="ternforge-example"
   repo_dir="/path/to/rendered/repository"
   gh repo create "betabitplus/$repo" --public --source "$repo_dir" --remote origin --push
   ```

   Use `--private` instead for a private repository.
4. Verify `.copier-answers.yml`, `main`, and `ci / required`.
5. Add one sorted inventory entry by PR. The permanent OpenTofu `import` block adopts the repository on the reviewed apply.

Do not add bootstrap flags, `github_repository_file`, an onboarding CLI, or a synthetic bootstrap PR.

## Plan and apply

Run `repository control` on `main`.

1. Approve `repository control / plan` and review its Job Summary.
2. Approve `repository control / apply` only after reviewing that plan.

Both jobs fail closed unless the PAT is exactly `repo` + `read:user`, the GitHub environment has owner review with admin bypass disabled and only `main` allowed, Scalr is state-only, and the frozen baseline SHA is unchanged. Apply re-plans and hashes the complete changed `resource_changes`; a different digest requires a new review.

Plans and plan JSON stay runner-local and are deleted.

## Recovery and rollback

If a managed repository is accidentally deleted, do not run repository-control apply. Restore it with GitHub's built-in deleted-repository restore, then verify `main` and `ci / required` and run the protected workflow to return to no drift. GitHub normally allows eligible deleted repositories to be restored within 90 days.

If GitHub restoration is unavailable, recover the repository contents and initial `main` outside OpenTofu before the next plan; OpenTofu must not become the file/bootstrap owner.

For an ordinary bad configuration change, revert the OpenTofu/inventory PR and run the same protected workflow. Do not add a separate recovery control plane.

## PAT rotation

Normal rotation: create a replacement classic PAT with exactly `repo` + `read:user`, replace `TERNFORGE_REPOSITORY_CONTROL_TOKEN`, run the protected no-drift workflow, then revoke the old token.

If compromise is suspected, revoke the old token first, then replace and verify it.

Never commit or upload `.terraform/`, state, state backups, saved plans, plan JSON, credentials, or tokens.
