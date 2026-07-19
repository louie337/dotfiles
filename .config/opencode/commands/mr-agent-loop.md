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
/mr-agent-loop <MR URL> [--until mergeable|merged] [--allow-local-rebase] [--allow-force-with-lease]
```

Default `--until` to `mergeable`. Use the `gitlab-cli-skills` and `glab`
skills plus the installed `glab` CLI for all GitLab inspection and mutations.
Do not call `$HOME/.local/bin/mr-loop` or any other self-written supervisor
script. Synchronize the source branch with the latest fetched remote target and
wait for SHA convergence before review fixes, repair commits, pushes, or CI
evaluation. Local conflict rebases and SHA-bound force-with-lease pushes require
their corresponding explicit invocation flags.

Examples:

```text
/mr-agent-loop https://gitlab.com/group/project/-/merge_requests/123
/mr-agent-loop https://gitlab.com/group/project/-/merge_requests/123 --until merged
/mr-agent-loop https://gitlab.com/group/project/-/merge_requests/123 --allow-local-rebase --allow-force-with-lease
```
