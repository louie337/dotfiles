---
description: Synchronize, repair discussions and pipelines, then finish a GitLab merge request.
agent: build
---

Run the deterministic GitLab MR supervisor below to synchronize the source
branch, repair and resolve discussions, repair CI, and relay its output.
Do not reproduce the monitoring loop yourself or perform additional GitLab or
Git operations before or after it.

```sh
$HOME/.local/bin/mr-loop $ARGUMENTS
```
