---
description: Implement a Linear ticket, independently gate the local branch, publish an MR, then run the MR loop.
agent: ticket-loop-mastermind
---

Run the ticket implementation and MR workflow with these arguments:

```text
$ARGUMENTS
```

Interpret the arguments as:

```text
/ticket-loop <LINEAR-ID> [--approve-plan] [--until mergeable|merged]
```

Before any implementation, inspect the relevant repository code and present an evidence-backed,
newcomer-friendly overview of the affected system or feature, followed by the implementation plan.
Require explicit plan approval unless `--approve-plan` is present; approval covers the complete
briefing. Even with the flag, show the briefing before implementation. Default `--until` to
`mergeable`. Linear is read-only for this workflow.
