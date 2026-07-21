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

Require explicit plan approval unless `--approve-plan` is present. Default `--until` to
`mergeable`. Linear is read-only for this workflow.
