---
name: double-check
description: Audit the current Subanana or Subanana DevOps branch against its Linear ticket and surrounding issue context, then report scope alignment, implementation intent, verification needs, deployment MR count and links, and follow-up gaps. Use when the user asks to double-check, scope-check, or review the current implementation against its ticket without changing code.
---

# Subanana implementation double-check

Perform a read-only scope audit. Use Linear MCP for ticket evidence and the local repository for
implementation evidence. Do not edit code, mutate Git state, update Linear, or write to GitLab
unless the user separately requests that work.
When GitLab metadata is needed to identify merge requests or their URLs, load `gitlab-cli-skills`
and `glab` first and use read-only queries only.

## Resolve the ticket from the branch

1. Read the repository's applicable `AGENTS.md` files and snapshot the repository identity,
   current branch, `HEAD`, staged and unstaged changes, and untracked paths.
2. Scan the current branch name from left to right for case-insensitive `SUB-[0-9]+` keys. Use the
   first occurrence as the primary issue ID and normalize it to uppercase; if later occurrences
   contain different issue IDs, ignore them for primary-ticket resolution. Do not infer the issue
   from commit messages, nearby branches, or a title search. If the branch contains no key, stop
   and ask for the exact issue ID; do not guess.
3. Fetch that exact issue through Linear MCP. Keep Linear strictly read-only. If the issue cannot
   be fetched or belongs to an unexpected workspace/project, report the identity problem before
   evaluating scope.

## Build the scope evidence

Read the primary issue's title, description, acceptance criteria, comments, attachments or linked
documents exposed by Linear, status, labels, project or initiative context, and relationship
metadata. Preserve contradictions, later clarifications, and explicit exclusions instead of
silently choosing one source. Treat a later clear clarification on the primary issue as stronger
than an older ambiguous statement, but flag any genuine conflict that needs a human decision.

Inventory one relationship hop around the primary issue:

- its parent and direct children;
- direct siblings that share the same parent;
- issues linked as related, blocked by, blocking, duplicate, or otherwise directly associated.

Read the available description, comments, and relationship details for those issues when they
clarify shared behavior, sequencing, ownership, dependencies, or exclusions. Do not recursively
expand the entire Linear graph unless a directly linked issue explicitly points to another issue
as the source of a requirement needed to evaluate the current ticket.

Parent, sibling, child, and related issues provide context and scope boundaries; they do not
automatically add their work to the current ticket. Attribute a requirement to the current branch
only when the primary issue or an explicit relationship/parent allocation assigns it there. Note
requirements owned by another issue as dependencies or follow-up, not missing implementation in
the current branch.

## Inspect the current implementation

Determine the comparison base from an unambiguous MR target when already available, otherwise the
repository's configured default branch. Record the base ref and merge base used. If neither can be
resolved reliably, state the limitation rather than choosing an arbitrary branch.

Review the complete current implementation relative to that base:

- branch commits and the aggregate committed diff;
- staged, unstaged, and untracked work, identified separately from committed work;
- affected runtime paths, configuration, migrations, infrastructure, generated artifacts,
  documentation, and tests;
- relevant unchanged call sites or contracts needed to determine whether the change is complete.

Do not judge scope from filenames or commit subjects alone. Trace enough data, control, and
authorization flow to explain what behavior the implementation actually changes. Separate direct
evidence from inference and call out implementation that appears unrelated to the ticket.

## Determine deployment MR coverage

After reviewing the ticket and implementation, explicitly determine how many merge requests are
required for a complete deployment. Treat the Subanana APP and Subanana DevOps repositories as
separate deployment units:

- `1 MR` is required when exactly one repository is in deployment scope (APP-only or DevOps-only)
  and ticket, diff, code, and repository rules provide no evidence that the other repository must
  change.
- `2 MRs` are required when the ticket, implementation, code, or repository rules require both the
  APP change and an actual paired DevOps change, even when the DevOps diff or MR is not yet present.
  The exact source-branch name is the pair key; do not count unrelated, helper, empty, or same-ticket
  MRs on another branch. A verified, non-empty DevOps diff is required before its MR can be reused
  or created, but its absence does not reduce the required count.

Use read-only GitLab metadata when needed to resolve every relevant MR by exact project, source
branch, target, and current SHA; if multiple matches remain, report the identity ambiguity instead
of choosing one. If the two-MR classification applies while the current branch is
in the DevOps repository, resolve and report its exact APP counterpart as well; do not report only
the repository currently checked out. If the DevOps branch is a genuinely standalone one-MR change,
state that no APP MR is required.
When the current branch is in the APP repository, inspect an available same-named DevOps worktree or
branch and its exact diff when deciding whether the paired MR is required; do not create one for this
read-only audit. If that evidence is unavailable and the deployment count cannot be resolved from
the ticket and repository rules, classify it as `cannot-determine` and explain the limitation.
Record the required MR count, each existing MR's canonical web URL, and any required MR that is
missing or inaccessible (including why its URL cannot be provided). This is an audit only: do not
create, edit, merge, or otherwise mutate an MR.

## Evaluate scope alignment

Create a compact requirement-to-implementation mapping. For each acceptance criterion or material
scope statement, classify it as:

- `implemented`: fully supported by concrete code and test evidence;
- `partial`: some required behavior is present but a material part is absent or uncertain;
- `missing`: no implementation evidence covers it;
- `out-of-scope/dependency`: owned by another ticket or explicitly excluded;
- `cannot-determine`: the Linear or repository evidence is contradictory or incomplete.

Also identify behavior implemented by the branch that has no support in the ticket context. An
overall `matches`, `partially matches`, `does not match`, or `cannot determine` verdict must follow
from this mapping. Existing tests are implementation evidence, not proof that behavior has passed;
do not claim verification was executed unless it actually was.

## Write the final summary

Keep the result concise and evidence-backed, with local file links and Linear issue IDs where
useful. Use these sections in order:

1. **Problem we are solving** — explain the user or system problem, intended outcome, primary
   ticket, and relevant surrounding-ticket boundaries.
2. **Current implementation and scope match** — give the overall verdict, briefly explain the
   approach, map material requirements to implementation evidence, and mention unrelated scope.
3. **Verification plan** — list the smallest meaningful checks for happy paths, authorization or
   error paths, regressions, migrations/infrastructure, and applicable E2E coverage. Distinguish
   checks already evidenced from checks still needing execution; use `$test-loop` for interactive
   Subanana browser verification when requested separately.
4. **Missing parts and follow-up** — list only concrete gaps, unresolved decisions, dependencies,
   or verification still required. Name the owning issue when known. If none are found, say so and
   state any residual uncertainty rather than inventing work.
5. **Deployment MRs** — state the exact number of MRs required for complete deployment (`1` MR in
   the sole affected repository, or `2` APP + DevOps MRs). List every relevant MR with its
   repository, IID, source/target, exact SHA or status, and canonical GitLab URL as a Markdown
   link, with one entry per MR rather than one umbrella link. For an app-only change, explicitly
   say that no DevOps MR is required; for a DevOps-only change, say that no APP MR is required. For
   a paired change, list both URLs; if either MR is missing or its URL is inaccessible, include
   `URL unavailable` with the reason and treat it as a follow-up/blocker.

Include which Linear relationships were inspected and any inaccessible evidence. Do not repair
gaps during this skill invocation; return actionable findings for the user or an implementation
workflow to handle separately.
