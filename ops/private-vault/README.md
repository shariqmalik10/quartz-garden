# Private vault automation template

These files belong in the private Obsidian repository, not in the public Quartz
repository. During setup, copy them into the canonical vault while preserving
the paths shown here.

## Private repository variables and secret

Configure this Actions variable:

```text
PUBLIC_QUARTZ_REPOSITORY=shariqmalik10/quartz-garden
```

Configure this Actions secret:

```text
PUBLIC_REPO_PUSH_TOKEN
```

Use a fine-grained token restricted to that single public repository with only
Contents read/write. Do not store it in the vault, the public repository, or
Garden Drop.

The workflow runs after a private `main` push or manually. It exports the
allowlisted garden, runs the public repository's checks/tests/build, and pushes
only when every gate succeeds.

## Local 23:00 backup

Copy `scripts/backup-vault.sh` into `System/Sync/backup-vault.sh` in the vault,
make it executable, and install the launch agent:

```bash
./scripts/install-launch-agent.sh "/Users/shariq/Documents/Obsidian Vault"
```

The calendar trigger uses the Mac's local timezone. The installer refuses to
continue unless the local timezone is `Asia/Riyadh`. A sleeping Mac may run the
calendar job after wake; the script's lock prevents overlapping runs.
