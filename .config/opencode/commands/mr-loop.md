---
description: Monitor and repair a GitLab merge request until it is mergeable.
agent: build
---

Run the deterministic GitLab MR repair supervisor below and relay its output.
Do not reproduce the monitoring loop yourself or perform additional GitLab or
Git operations before or after it.

```sh
$HOME/.local/bin/mr-loop $ARGUMENTS
```
