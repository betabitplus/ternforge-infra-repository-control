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

   Use `--private` instead for a private repository when its role allows it. In the current ten-repository fleet, keep `ternforge-infra-repository-control`, `ternforge-infra-updates`, and `ternforge-infra-observability` public because their reviewed apply paths require environment reviewers on GitHub Pro; keep `ternforge-infra-ci` public because public callers require its reusable workflows/actions. The other six repositories may vary independently.
3. For a versioned repository, before the first `main` push:
   * create the `release` environment with custom branch policies enabled but no branch pattern yet, so deployment stays fail-closed until enrollment;
   * set `TERNFORGE_RELEASE_CLIENT_ID` from the authoritative repository-control input;
   * restore the current Release App key only from its canonical SOPS/Age escrow, set `TERNFORGE_RELEASE_PRIVATE_KEY` in that environment, and immediately delete the plaintext restoration;
   * add the repository to the existing selected-repository Release App installation. This membership is pre-enrollment bootstrap state only; OpenTofu becomes authoritative after enrollment.

   A non-versioned repository skips this step.
4. Push the prepared initial `main` and verify `.copier-answers.yml`, `main`, and `ci / required`; a versioned repository cannot consume the release environment yet because no branch policy is enrolled.
5. Add one sorted inventory entry by PR. Permanent OpenTofu `import` blocks adopt the repository and, for versioned repositories, the pre-provisioned `release` environment and `TERNFORGE_RELEASE_CLIENT_ID` variable; the same reviewed apply creates the sole `main` deployment policy, converges App membership, creates `TERNFORGE_SOURCE_READ_CLIENT_ID`, and restricts new `v*` tag creation to the Release App while keeping existing `v*` tags immutable for everyone.
6. If the rendered repository workflow references `TERNFORGE_SOURCE_READ_PRIVATE_KEY`, provision that repository secret only after the enrollment apply has succeeded: restore the current `ternforge-source-read` key from its canonical SOPS/Age escrow, pipe it directly to `gh secret set TERNFORGE_SOURCE_READ_PRIVATE_KEY -R "betabitplus/$repo"`, and delete the plaintext restoration immediately. Do not maintain a second list of source-consuming repositories; the workflow reference itself is the role contract. Then run the normal required CI and release workflow successfully before considering enrollment complete.

Do not add bootstrap flags, `github_repository_file`, an onboarding CLI, or a synthetic bootstrap PR.

## De-enroll and delete

1. If the repository contains `TERNFORGE_SOURCE_READ_PRIVATE_KEY`, delete that repository secret before de-enrollment. The App private key can mint read tokens for the remaining installation, so it must not survive in a repository that is about to leave the trusted fleet.
2. Remove the repository's single inventory entry by PR.
3. In the protected plan, verify the `github_repository` object is **forgotten**, not destroyed; only its managed controls are destroyed and App memberships shrink.
4. Apply the reviewed plan and require the built-in post-apply no-drift check to pass.
5. Read back Release/Renovate/source-read/Grafana App membership, then delete the repository separately with GitHub.
6. Run one final protected no-drift workflow against the remaining fleet.

Repository deletion is intentionally outside OpenTofu; `lifecycle.destroy = false` prevents de-enrollment from deleting the GitHub repository.

## Plan and apply

Run `repository control` on `main`.

1. Approve `repository control / plan` and review its Job Summary.
2. Approve `repository control / apply` only after reviewing that plan.

Both jobs fail closed unless the PAT is exactly `repo` + `read:user`, the GitHub environment has owner review with admin bypass disabled and only `main` allowed, and Scalr is state-only with `terraform-version=auto`. Apply re-plans and hashes the complete changed `resource_changes`; a different digest requires a new review.

Plans and plan JSON stay runner-local and are deleted.

## Recovery and rollback

If a managed repository is accidentally deleted, do not run repository-control apply. Restore it with GitHub's built-in deleted-repository restore, then verify `main` and `ci / required` and run the protected workflow to return to no drift. GitHub normally allows eligible deleted repositories to be restored within 90 days.

If GitHub restoration is unavailable, recover the repository contents and initial `main` outside OpenTofu before the next plan; OpenTofu must not become the file/bootstrap owner.

For an ordinary bad configuration change, revert the OpenTofu/inventory PR and run the same protected workflow. Do not add a separate recovery control plane.

## PAT rotation

Normal rotation: create a replacement classic PAT with exactly `repo` + `read:user`, replace `TERNFORGE_REPOSITORY_CONTROL_TOKEN`, run the protected no-drift workflow, then revoke the old token.

If compromise is suspected, revoke the old token first, then replace and verify it.

Never commit or upload `.terraform/`, state, state backups, saved plans, plan JSON, credentials, or tokens.
