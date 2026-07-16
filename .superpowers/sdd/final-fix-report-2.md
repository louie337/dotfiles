# Final Re-review Fix Report

## Status

Complete. The remaining Important rebase-attribution finding and all three test gaps from `final-review-2.md` are closed. The unrelated `.config/opencode/opencode.json` modification was not changed or staged. No live `mr-loop`, GitLab, OpenCode agent, or model call was made.

## Changes

- `request_gitlab_rebase` now starts polling with `seen_active=false`. The PUT response proves only that GitLab accepted the request; it is not treated as an MR SHA/state observation.
- Request convergence requires identity-checked GET observations of `old SHA + rebase_in_progress=true`, followed by `new SHA + rebase_in_progress=false`. A first GET returning `new + inactive` fails closed without alignment.
- The request-path test now models the valid initial identity check, PUT, polled old/active state, and polled new/inactive state. A separate regression rejects immediate unobserved completion.
- Discussion-agent branch and HEAD mutations now occur inside the agent stub after `process_discussion` captures its baseline. Tests assert that neither commit nor reply occurs.
- Focused post-reply tests independently change MR SHA, MR identity, local branch, and local HEAD during the POST stub. Each test asserts that resolution is not attempted.
- The label-only dry-run was replaced with stubbed production orchestration. It invokes production `sync_local_descendant` and production `monitor` for notify and merge, while stubbing external/mutating boundaries. The observed calls cover descendant push, rebase routing, discussion repair, pipeline repair/push, fresh health, ready notification, and merge; the shared repair count is also asserted.

## RED Evidence

After adding the regressions and before changing production code, `sh tests/mr-loop-test.sh` reported 2 failures:

```text
not ok 97 - request rejects immediate new inactive MR state (expected '1', got '0')
not ok 98 - immediate unobserved rebase result is not aligned (expected '0', got '1')
1..144
```

The new discussion timing and production-orchestration tests passed against the existing guards, while the two failures reproduced the remaining attribution bug precisely.

## GREEN Evidence

After changing request polling to `seen_active=false`:

- `sh -n .local/bin/mr-loop`: exit 0.
- `sh -n tests/mr-loop-test.sh`: exit 0.
- `sh tests/mr-loop-test.sh`: exit 0, 144/144 assertions `ok`, TAP plan `1..144`.

## Concerns

- GitLab still provides no operation identifier for rebase attribution. Fast rebases that complete before an identity-checked GET observes the old active state intentionally fail closed.
- Live integration was not run, as required.
