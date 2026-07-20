---
name: mr-loop-linear-context
description: Use for GitLab MR loop Linear issue lookup from SUB keys and deterministic domain conflict precedence against exact target behavior.
---

# MR Loop Linear Context

Use this skill when the MR source branch contains a Linear key matching
`SUB-[0-9]+`, or when a domain/business conflict requires ticket-versus-target
precedence.

## Exact Issue Lookup

1. Match the source branch case-insensitively for `SUB-[0-9]+`.
2. Fetch that exact issue through the globally configured Linear MCP before
   resolving domain or business conflicts.
3. Capture identifier, title, description, acceptance criteria, and relevant
   comments.
4. Do not infer requirements from the branch name alone.
5. If Linear MCP is unavailable or the exact issue cannot be found, stop with
   `manual_action_required` rather than guessing ticket intent.

## Domain Conflict Precedence

For domain, business, authorization, and permission-scope conflicts:

1. An explicit ticket requirement that addresses the conflicting behavior wins.
2. Otherwise preserve behavior at the exact freshly fetched target SHA. Absence
   of a ticket requirement means target behavior wins; it is not permission to
   infer new product policy.
3. Use acceptance criteria, relevant Linear comments, repository rules, tests, and
   nearby code to interpret and implement the selected behavior. MR discussions
   may clarify implementation but must not silently override an explicit ticket
   requirement.
4. Add or update focused tests proving preserved target behavior or
   ticket-directed behavior, including authorization boundaries when relevant.
5. Record the issue key, evidence, selected behavior, rejected alternative, and
   verification in the decision log.

Stop when the exact Linear issue cannot be retrieved, explicit ticket
requirements conflict internally, ticket-versus-target migration semantics are
unclear, or another non-autonomous category remains. Never use a stale local
target branch as evidence; target behavior means the exact recorded SHA fetched
from the target project and confirmed through GitLab's branch endpoint.
