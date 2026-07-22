---
name: mr-loop-conflict-analysis
description: Use for GitLab MR loop read-only merge-conflict classification, generated-file detection, deterministic intent evidence, and conflict worker guidance.
---

# MR Loop Conflict Analysis

This skill is read-only. It supports the primary agent and read-only conflict
investigators. It does not authorize editing, staging, committing, pushing, or
cleanup.

## Conflict Scope

- Paths Git reports as unmerged are conflict-repair paths.
- Additional changed paths are allowed only when they are canonical generated
  outputs causally regenerated from a conflicted source definition or one proven
  validation-enabling metadata path under
  `INV-PRESYNC-CAUSAL-METADATA-REPAIR`.
- Non-conflicting target changes remain part of the eventual merge but must not be
  edited as repairs.
- A path outside the recorded merge manifest, initial unmerged set, or proven
  generated-output or causal-metadata set is unrelated or concurrent work and
  must not be staged or committed.

## Validation-Enabling Metadata

Treat metadata such as `.gitattributes`, `.gitignore`, formatter configuration,
or lint configuration as a causal integration path even when Git did not mark it
unmerged only when all evidence proves:

- the exact ordinary source/target merge is otherwise content-clean or has only
  deterministic conflict resolutions;
- one mandatory service-free validation fails solely on target-introduced paths;
- repository rules document those paths as immutable, generated, vendored,
  byte-identical, or maintained from a canonical source, so editing their content
  is prohibited;
- the metadata change is the smallest correct fix, scoped to the exact affected
  paths and validation category, while first-party and unrelated paths retain the
  original validation;
- protected bytes remain identical to their blobs at `<exact-target-sha>`; and
- the rule makes no product, runtime, deployment, schema, or security decision
  and satisfies applicable repository rules and documentation requirements.

Fail closed and request human input if the contract is unproven, direct repair is
safe and appropriate, the exemption is broad or spans unrelated target defects,
or behavior is affected. Target ownership alone does not require a helper MR and
does not authorize arbitrary cleanup.

Examples:

- Allowed: a path-scoped `.gitattributes` whitespace exemption for pinned
  upstream vendor files whose bytes remain identical to the target SHA.
- Denied: repository-wide `-whitespace`.
- Denied: disabling a linter for unrelated first-party code.
- Denied: changing runtime configuration to make a failing test pass.

## Deterministic Resolution Evidence

Resolve autonomously only when repository evidence establishes one intended
combined behavior:

- Preserve non-overlapping behavior from both parents.
- Preserve the MR's intended feature.
- Incorporate target-side API, schema, and configuration changes.
- Follow nearby code, tests, MR/ticket evidence, repository review rules, and
  path-specific instructions.
- Content conflicts with a clear contract and add/add conflicts containing
  compatible definitions are ordinary resolvable cases; deduplicate and combine
  them without dropping behavior.

Stop without commit or push for product ambiguity, migrations needing rollout or
data-policy decisions, destructive data consequences, unsupported security
acceptance, deployment or approval choices, reviewer-intent ambiguity,
incompatible definitions, or any conflict whose correct behavior cannot be
inferred from code and tests.

## Generated Files

- Detect generated conflicts through file headers, repository attributes,
  generator configuration, build scripts, path rules, SQLC output, protobuf
  output, and equivalent generated-source conventions.
- Identify and resolve the source schema, query, proto, or other definition
  first.
- The primary must run the canonical generator from the isolated worktree, review
  the complete output, and require all generated drift to be attributable to the
  resolved source definitions.
- Do not hand-edit generated output unless repository rules explicitly classify
  it as maintained source.
- If the canonical generator, required version, inputs, or execution context is
  unavailable, the primary stops without commit or push and reports the gap.

## Mechanism Fallbacks

Conflict intent and mechanism availability are separate. A denied convenience
command is not ambiguity while safe inspection, file editing, marker resolution,
or deterministic regeneration remains available.

Read-only analysis may inspect exact stages and blobs:

```sh
git show :1:<path>
git show :2:<path>
git show :3:<path>
git show <expected-source-sha>:<path>
git show <exact-target-sha>:<path>
```

If every safe write mechanism is unavailable after deterministic analysis, the
primary returns `manual_action_required`, not `blocked_conflicts`, and reports the
established result, attempted mechanisms, and unavailable capabilities.

## Worker Instructions

Conflict investigators must receive the MR URL, expected source SHA, exact target
SHA, assigned conflict paths and types, and one narrow read-only question. Return
file/line evidence and a recommendation only. Do not mutate files or Git state.
