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

1. Render the exact released Copier template with all required answers and add the role-owned CI/release files; initial `main` must expose `ci / required`.
2. Create the empty repository shell with explicit visibility:

   ```sh
   repo="ternforge-example"
   gh repo create "betabitplus/$repo" --public
   ```

   Use `--private` instead for a private repository.
3. For a versioned repository, before the first `main` push:
   * create the `release` environment with custom branch policy exactly `main`;
   * set `TERNFORGE_RELEASE_CLIENT_ID` from the authoritative repository-control input;
   * restore the current Release App key only from its canonical SOPS/Age escrow, set `TERNFORGE_RELEASE_PRIVATE_KEY` in that environment, and immediately delete the plaintext restoration;
   * add the repository to the existing selected-repository Release App installation. This membership is pre-enrollment bootstrap state only; OpenTofu becomes authoritative after enrollment.

   A non-versioned repository skips this step.
4. Push the prepared initial `main` and verify `.copier-answers.yml`, `main`, `ci / required`, and a successful initial release workflow when versioned.
5. Add one sorted inventory entry by PR. Permanent OpenTofu `import` blocks adopt the repository and, for versioned repositories, the pre-provisioned `TERNFORGE_RELEASE_CLIENT_ID` variable on the reviewed apply; the same apply converges App membership.

Do not add bootstrap flags, `github_repository_file`, an onboarding CLI, or a synthetic bootstrap PR.

## De-enroll and delete

1. Remove the repository's single inventory entry by PR.
2. In the protected plan, verify the `github_repository` object is **forgotten**, not destroyed; only its managed controls are destroyed and App memberships shrink.
3. Apply the reviewed plan and require the built-in post-apply no-drift check to pass.
4. Read back Release/Renovate/Grafana App membership, then delete the repository separately with GitHub.
5. Run one final protected no-drift workflow against the remaining fleet.

Repository deletion is intentionally outside OpenTofu; `lifecycle.destroy = false` prevents de-enrollment from deleting the GitHub repository.

## Plan and apply

Run `repository control` on `main`.

1. Approve `repository control / plan` and review its Job Summary.
2. Approve `repository control / apply` only after reviewing that plan.

Both jobs fail closed unless the PAT is exactly `repo` + `read:user`, the GitHub environment has owner review with admin bypass disabled and only `main` allowed, and Scalr is state-only. Apply re-plans and hashes the complete changed `resource_changes`; a different digest requires a new review.

Plans and plan JSON stay runner-local and are deleted.

## Recovery and rollback

If a managed repository is accidentally deleted, do not run repository-control apply. Restore it with GitHub's built-in deleted-repository restore, then verify `main` and `ci / required` and run the protected workflow to return to no drift. GitHub normally allows eligible deleted repositories to be restored within 90 days.

If GitHub restoration is unavailable, recover the repository contents and initial `main` outside OpenTofu before the next plan; OpenTofu must not become the file/bootstrap owner.

For an ordinary bad configuration change, revert the OpenTofu/inventory PR and run the same protected workflow. Do not add a separate recovery control plane.

## PAT rotation

Normal rotation: create a replacement classic PAT with exactly `repo` + `read:user`, replace `TERNFORGE_REPOSITORY_CONTROL_TOKEN`, run the protected no-drift workflow, then revoke the old token.

If compromise is suspected, revoke the old token first, then replace and verify it.

Never commit or upload `.terraform/`, state, state backups, saved plans, plan JSON, credentials, or tokens.
