# Global Codex guidance

Treat repository-local `AGENTS.md` files as the authority for project-specific commands and
conventions. Keep this file limited to personal defaults that should apply across repositories.

## Working style

- Inspect relevant code and repository instructions before changing files.
- Preserve unrelated work in dirty worktrees and keep edits within the requested scope.
- Prefer the smallest coherent change and verify it in proportion to risk.
- Use subagents for bounded investigation, review, or independent work. Keep planning, user
  decisions, and cross-task orchestration in the root thread.
- Use at most one mutating subagent in a shared worktree at a time. Parallelize read-only work.

## Safety

- Never discard work with `git reset`, `git clean`, `git restore`, or checkout-based rollback
  unless the user explicitly requests the exact destructive operation.
- Never rewrite shared history, amend existing commits, or force-push without explicit approval.
- Do not use `git stash` as automatic workflow state.
- Resolve exact Git and remote identities before commits, pushes, merge-request writes, or other
  consequential actions.
- Treat credentials, production data, and shared customer resources as out of scope unless the
  user explicitly supplies a safe, bounded workflow.

## GitLab and Linear

- Load the available `glab` and `gitlab-cli-skills` skills for GitLab CLI work.
- Treat Linear as read-only unless the user explicitly asks for a specific mutation.
- Revalidate branch, commit SHA, merge-request identity, and authorization immediately before a
  remote write.

## Completion

- Run feasible service-free checks locally.
- Do not start containers, databases, browser stacks, or other infrastructure merely to reproduce
  checks already covered by CI; ask before starting material infrastructure.
- Report completed work, verification evidence, and any genuinely pending remote checks.
