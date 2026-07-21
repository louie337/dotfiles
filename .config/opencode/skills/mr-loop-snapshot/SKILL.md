---
name: mr-loop-snapshot
description: Use for GitLab MR loop startup checks, exact MR identity, target-branch snapshots, discussion pagination, and same-SHA evidence collection.
---

# MR Loop Snapshot

Collect snapshots for the primary `mr-loop` state machine. This skill does
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
   dispatcher. Run a dispatcher when it is service-free and allowed by the
   primary's local verification budget; do not let a dispatcher start local
   infrastructure implicitly.
10. Inspect GitLab CI includes, job commands, and `rules`/path selection for the
    changed paths. Record exact automatically selected job names and demonstrated
    coverage for database integration, backend services, Docker, browser,
    full-stack, preview, or other resource-heavy verification. Do not infer
    coverage from names. Store jobs required to verify the changed behavior as
    `verification_required_jobs`, including command and rule evidence plus the
    expected pipeline source or parent/child graph selector. A mapping identifies
    an expected `(pipeline graph selector, job name)` occurrence; the same job name
    in a different graph is not equivalent.
11. If CI includes or selection evidence are temporarily inaccessible or
    incomplete, set `remote_verification_pending` with the failed evidence source;
    do not invent names or classify a gap. Set `remote_coverage_gap` only when
    readable, complete CI configuration and path rules prove no automatic job
    covers a required verification obligation. Neither state permits local service
    startup.

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
- Expected `verification_required_jobs` selected by the current paths, whether
  each expected graph/job occurrence appears and succeeds in its exact-SHA graph,
  pending remote evidence, proven coverage gaps, mapped selection gaps, and any
  exact-SHA approved local fallback evidence.

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
