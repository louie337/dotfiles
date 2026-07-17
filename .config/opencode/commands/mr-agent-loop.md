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
Do not call `$HOME/.local/bin/mr-loop` or any other self-written supervisor
script.
