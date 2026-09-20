# Garden Studio operations and recovery runbook

This runbook covers the isolated Garden Studio, the private Obsidian vault repository, and the public Quartz review branch. It deliberately avoids history rewriting. The existing production site and public `main` remain the final safety boundary.

## Safety rules

- Treat the private vault repository as the source of truth.
- Pull before editing in Obsidian; push completed local edits before opening the same note in Studio.
- Let Studio create ordinary commits. A stale Studio save must fail instead of replacing a newer Obsidian revision.
- Publish only through `studio/garden-preview`, its pull request, required checks, and a reviewed Vercel preview.
- Never point an exporter or Studio mutation endpoint at public `main`.
- Prefer a new corrective commit or Studio revision restore. Do not use force-push, reset, or rewritten history for routine recovery.

## Daily health check

1. Open **Connection** in Garden Studio.
2. Confirm the vault branch and revision are expected.
3. Confirm every deployment setup row is configured. Demo fallback is acceptable only for a design-only preview.
4. Open **History** and compare the latest private-vault commit with the expected Obsidian/Studio edit.
5. Before publishing, run the non-mutating boundary check:

```bash
npm run publish:check -- --vault "/absolute/path/to/Obsidian Vault" --site "/absolute/path/to/quartz-garden"
```

The command must report every collection ready. It stages exporter output in temporary storage and does not modify public content.

## Restore one note

Preferred path:

1. Open the note in Garden Studio.
2. Open **Revisions**.
3. Inspect the target revision and select **Restore this version**.
4. Confirm the restore appears as a new private-vault commit.
5. Pull that commit into Obsidian.

Git fallback for an operator working in a clean private-vault checkout:

1. Record the current state with `git status --short` and `git rev-parse HEAD`.
2. Inspect the known-good file with `git show <known-good-sha>:<vault-relative-path>`.
3. Restore only that explicit file from the known-good revision.
4. Review `git diff -- <vault-relative-path>`.
5. Commit and push the restoration as a new commit.

Never restore an entire vault when only one managed note is affected.

## Recover from an editing conflict

1. Do not dismiss the Studio conflict by repeatedly saving.
2. Copy any unsaved browser draft to a temporary local note if needed.
3. Pull the latest private-vault commit and inspect the note in Obsidian.
4. Reconcile the two versions intentionally.
5. Push the reconciled Obsidian note, refresh Studio, and continue from the new revision.

The conflict response may include the latest managed file content, but never credentials or unrelated vault data.

## Abandon a public preview safely

If a generated preview is wrong:

1. Do not type `publish` and do not merge the pull request.
2. Record the private-vault revision and the preview branch head shown in Studio.
3. Correct the private source with a new commit.
4. Run `publish:check` again.
5. Build a new preview from Studio. The fixed review branch and pull request are reused.
6. Confirm public `main` and the production domain never changed.

Closing the preview pull request is optional. It is not a rollback because an unmerged review branch never reached production.

## Recover after a merged publication

If an already merged public change must be reversed:

1. Correct or privatize the source entry in the private vault using an ordinary commit.
2. Build and inspect a new review preview.
3. Merge the corrective pull request after checks pass.
4. If the public repository itself contains an isolated bad merge and an immediate repository-level reversal is required, use GitHub’s **Revert** action to create a new pull request. Do not rewrite `main`.
5. Re-run the exporter preview afterward so generated public content again matches the private source of truth.

## Credential or permission failure

1. Open **Connection** and identify only which setup group is missing; do not paste secret values into issues, chat, logs, or screenshots.
2. Confirm the GitHub App remains installed only on `obsidian-vault-private` and `quartz-garden`.
3. Confirm its repository permissions match the Garden Studio README.
4. Rotate a suspected client secret or private key in GitHub, then replace it only in the separate Garden Studio Vercel project.
5. Redeploy Garden Studio and verify sign-in, private-vault read, and a disposable draft write.
6. Never add a credential to `NEXT_PUBLIC_*` or commit an `.env.local` file.

## Production-readiness drill

Run this only after private workflow PR #1 is reviewed and merged and the real GitHub App is configured:

1. Record private `main`, public `main`, and production deployment revisions.
2. Create disposable writing, quote, and saved-link entries in Studio.
3. Complete the Studio ↔ Obsidian round trip and stale-save conflict test for each type.
4. Upload one image to a `reference` area and one to an `owned` area.
5. Run `publish:check` and build the review branch.
6. Confirm the reference image is absent and the owned image is present in the public preview.
7. Confirm private drafts, credentials, and unrelated vault folders are absent from the public diff.
8. Verify desktop, phone, keyboard, and reduced-motion behavior.
9. Merge only after every required check passes and the exact preview is approved.
10. Correct the disposable entries with ordinary commits and repeat the preview to demonstrate recovery.

Record the date, three repository revisions, preview URL, pull request, test results, and recovery result in the living handoff document.
