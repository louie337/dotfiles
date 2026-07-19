---
description: Use glab skills to repeatedly repair a GitLab MR until mergeable or merged.
agent: mr-agent-loop
---

Run the GitLab MR agent loop with these arguments:

```text
$ARGUMENTS
```

Interpret the arguments as:

```text
/mr-agent-loop <MR URL> [--until mergeable|merged]
```

Default `--until` to `mergeable`. Use the `gitlab-cli-skills` and `glab`
skills plus the installed `glab` CLI for all GitLab inspection and mutations.
Synchronize the source branch with the latest fetched remote target and wait for
SHA convergence before review fixes, repair commits, pushes, or CI evaluation.
If GitLab-side rebase encounters bounded deterministic conflicts, integrate the
exact fetched remote target with a guarded normal merge and normal push. Never
locally rebase or force-push.

Examples:

```text
/mr-agent-loop https://gitlab.com/group/project/-/merge_requests/123
/mr-agent-loop https://gitlab.com/group/project/-/merge_requests/123 --until merged
```
