---
name: patch
description: Diagnose and implement a focused code fix with minimal scope and proportional verification. Use when the user asks to patch, fix, repair, or resolve a concrete bug and expects implementation rather than diagnosis only.
---

# Focused patch

1. Reproduce or establish the failure from code, tests, logs, or a precise behavioral trace.
2. Identify the root cause and the smallest coherent correction.
3. Inspect repository instructions and nearby patterns before editing.
4. Change only files required for the fix; preserve unrelated work and public behavior.
5. Add or update a regression test when the behavior is testable.
6. Run the narrowest relevant checks, then inspect the final diff for accidental scope.
7. Report the root cause, changed behavior, and verification evidence.

Ask only when ambiguity would materially change product behavior, architecture, or an irreversible
action. Do not perform broad cleanup merely because adjacent code could be improved.
