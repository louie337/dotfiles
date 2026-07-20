---
name: mr-loop-snapshot
description: Use for GitLab MR loop startup checks, exact MR identity, target-branch snapshots, discussion pagination, and same-SHA evidence collection.
---

# MR Loop Snapshot

Collect snapshots for the primary `mr-agent-loop` state machine. This skill does
not authorize edits or GitLab writes.

## Startup Checks

1. Parse the MR URL into `host`, `project path`, and `iid`.
2. Verify `git`, `glab`, and `jq` exist, and treat installed `glab --help` as
   authoritative when examples conflict.
3. Verify `git rev-parse --show-toplevel` succeeds.
4. Require `git status --porcelain --untracked-files=normal` and the index to be
   clean. Never discard unrelated work.
5. Verify remotes against MR source and target projects. Fork MRs require
   unambiguous source push remote, target fetch remote, and source push authority.
6. Run GitLab identity preflight for the host before any later write:
   `glab auth status --hostname <host>` and `glab api --hostname <host> user`.
7. Fetch MR metadata with machine-readable output, using `glab mr view <iid>
   --repo <project> --output json` and API calls for missing fields.
8. Stop when the MR is closed and not merged. Treat an already merged MR as
   success for both requested targets.
9. Discover repository-wide and path-specific rule files and any review-rule
   dispatcher. Run the dispatcher only when allowed by the primary's local
   verification budget.

## Loop Snapshot

Collect the complete snapshot only after the synchronization gate opens. Before
that, collect only identity, source/target refs, rebase/conflict/convergence
state, push authority, target tip, worktree inventory, and conflict-attempt state
needed to open the gate or resume safe conflict integration.

The complete snapshot includes:

- MR state, draft state, source/target branches, source/target project IDs, head
  SHA, title, description, detailed merge status, conflicts, approvals, blocking
  discussions, rebase progress, and merge/rebase error.
- Exact target state from the target project's branch endpoint. Do not infer the
  target tip from local refs or stale MR `diff_refs`.
- Local safety state: clean index/worktree result, `git worktree list
  --porcelain`, local source-branch tip when present, and loop-owned conflict
  attempt phase/ref/worktree.
- MR diff and commits for the current head SHA.
- Linear issue details for a source-branch `SUB-[0-9]+` key when present.
- Activities and discussions, including all paginated discussion pages.
- Every pipeline for the exact current MR head SHA, including pipeline ID, SHA,
  ref, source, status, timestamps, jobs, bridges, downstream relationships, job
  allow-failure state, failure reason, trace URLs, and current-attempt identity.

If identity or MR SHA changes during collection, discard the partial snapshot and
restart the iteration.

## Preferred Commands

Adjust flags after checking local `glab --help`:

```sh
glab mr view <iid> --repo <project> --output json --comments
glab mr diff <iid> --repo <project>
glab mr note list <iid> --repo <project> --output json --state all
glab ci get --repo <project> --merge-request <iid> --output json --with-job-details
glab ci list --repo <project> --sha <sha> --output json
glab api --hostname <host> --paginate "projects/<encoded-project>/merge_requests/<iid>/discussions?per_page=100"
```

Do not trust the MR API's embedded `head_pipeline` as the sole CI source. Resolve
the pipeline through `glab ci get`, `glab ci list --sha <sha>`, or the pipelines
API, then fetch all jobs and bridges.
