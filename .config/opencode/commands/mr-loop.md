---
description: Run the GitLab MR agent loop until the MR is mergeable or merged.
agent: mr-loop-mastermind
---

Run the GitLab MR agent loop with these arguments:

```text
$ARGUMENTS
```

Interpret the arguments as:

```text
/mr-loop <MR URL> [--until mergeable|merged]
```

Default `--until` to `mergeable`.

Examples:

```text
/mr-loop https://gitlab.com/group/project/-/merge_requests/123
/mr-loop https://gitlab.com/group/project/-/merge_requests/123 --until merged
```
