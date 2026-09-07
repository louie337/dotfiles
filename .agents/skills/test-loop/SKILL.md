---
name: test-loop
description: Run browser-based end-to-end checks for Subanana app or staff changes using the correct MR, dev, or approved production environment and logged-in Chrome MCP profile. Use when the user asks to validate a ticket or merge request through the UI, continue an e2e test from the conversation, or verify an implemented workflow before merge.
---

# Subanana end-to-end test loop

Use this skill for interactive, browser-based verification of behavior discussed in the current
conversation. The root thread owns the test scope, environment choice, browser actions, evidence,
and final result. This is a verification workflow: do not edit application or infrastructure code,
create commits, or mutate GitLab/MR state unless the user separately asks for that work.

## Reconstruct the test contract

1. Read the previous conversation first. Extract the requested behavior, acceptance criteria,
   affected app (consumer app or staff app), user roles, setup data, and expected outcomes. Treat
   the latest user clarification as authoritative. Do not invent passing criteria when the
   conversation is ambiguous; state the gap and ask for the smallest needed clarification.
2. If the work is tied to a ticket or MR, read its description and relevant comments as
   read-only evidence. For an MR, inspect comments for a deploy-preview URL and bind the URL to the
   MR before using it. Load `gitlab-cli-skills` and `glab` when GitLab CLI is needed to read MR
   metadata, comments, pipelines, or jobs. Do not use a URL copied from an unrelated MR or an
   untrusted message.
3. Turn the contract into a short scenario matrix. Include setup, exact navigation/actions,
   expected result, role/profile, environment, and observable evidence for each scenario. Cover
   the happy path plus acceptance-critical authorization, error, boundary, and regression cases
   that the conversation calls for; keep unrelated exploratory testing out of scope.

## Choose the environment

Use the first applicable option below and record the resolved base URL before testing:

1. **MR deploy environment (preferred):** use the deploy URL published in the MR's comments when
   it is available, reachable, and clearly associated with the current MR. Prefer the app or staff
   deploy URL matching the scenario. Check that it is HTTPS and, when deployment metadata is
   available, that it represents the current MR SHA; a stale or unrelated preview is not evidence
   for the current change. Before opening the preview, inspect the pipeline for the exact current
   MR SHA and confirm its `dev:ci-deploy:mr` job exists and has succeeded. A missing, manual,
   skipped, canceled, failed, pending, or running job does not establish a ready MR environment;
   do not proceed with MR-environment testing until the exact-SHA job succeeds. Do not play or
   retry this job unless the user separately authorizes that GitLab mutation. You may mutate the data
   inside MR environment freely as they are disposable with docker compose volume. Changes will not 
   affect real data.

2. **Dev fallback:** use `https://dev-plus.subanana.com/` for the consumer app or
   `https://dev-staff-app.subanana.com/` for the staff app. Before asking the user to run a dev
   deployment, inspect the relevant pipeline and prove `services:all:deploy:dev` is runnable for
   the intended ref/SHA: the job is present as a playable manual action, its prerequisites permit
   it to start, and the pipeline has not been canceled, superseded, expired, or archived. If it is
   not runnable, report the observed state and do not tell the user to run it. Never play, trigger,
   retry, or otherwise run `services:all:deploy:dev` yourself, whether through GitLab UI, API, CLI,
   MCP, or another agent. After the user reports running it, re-fetch the exact job and require a
   successful result before starting dev-environment testing; do not infer success from the user's
   message alone. You may mutate the data inside DEV environment with caution as we store mostly
   testing data in the database.

3. **Production:** use `https://plus.subanana.com/` or `https://staff-app.subanana.com/` only
   after the user explicitly approves production testing in this conversation. A general request
   to test, an MR URL, or prior approval for dev does not authorize production access. If approval
   is missing, stop before opening production and report the blocker. You should never mutate any 
   data in prod without explicit approval.

Do not silently substitute dev for an MR deploy when the MR URL is discoverable but unavailable:
record why the MR environment cannot be used, then use the dev fallback if that remains in scope.
Never test against production with customer data or perform irreversible actions. Use safe,
reversible fixtures and stop if a scenario could send real communications, charge a customer,
delete data, or otherwise cause material side effects.

## Select the Chrome MCP profile

The configured `chrome-devtools` server is attach-only: it must connect to the already-running
Chrome instance through `/Users/louie/Library/Application Support/Google/Chrome`. It must never
launch the MCP-managed `~/.cache/chrome-devtools-mcp/chrome-profile` or any temporary/isolated
browser. Before touching an app, call `list_pages` and select an existing page from the required
Chrome window/profile. If the configured server cannot attach, the required profile is not already
open, or the identity cannot be verified, stop and mark the scenario **blocked**. Do not work around
this by starting another Chrome window, using a different MCP server, passing `--isolated`, or using
`new_page` with `isolatedContext`. Never invoke `npx chrome-devtools-mcp`, `chrome-devtools start`,
or another generic browser-MCP command from a shell as a fallback.

If the MCP configuration was changed, restart the client or reconnect the `chrome-devtools` server
before testing; a live MCP process keeps its old launch arguments until it is restarted. If the
reconnect fails, leave the scenario blocked rather than retrying with a generic MCP command.

Use the Chrome MCP `Development` profile for usual scenarios (highly preferred if the scope is allowed); it has
`louie.lee@datax.io` logged in as both user and staff.

Use the Chrome MCP `louielee.learn@gmail.com` profile for scenarios requiring a FREE user; it has
`louielee.learn@gmail.com` logged in.

Use the Chrome MCP `louielee.dev@gmail.com` profile for scenarios requiring a PAID user; it has
`louielee.dev@gmail.com` logged in.

Use the Chrome MCP `Subanana` profile for scenarios requiring the DEV environment; it has the
actual `louie.lee@datax.io` user logged in.

Use the Chrome MCP `Subanana` profile for PROD scenarios only after the explicit production
approval gate above; it has the actual `louie.lee@datax.io` user logged in.

When one scenario combines requirements that name different profiles (for example, staff access
and a DEV-environment actual-user check), do not pretend one login satisfies both. Split the
scenario into the smallest applicable checks and run each with its required profile, recording the
profile and identity used. Never enter or request credentials; verify the active profile and
account before exercising protected behavior.

The profile names above are Chrome profiles, not MCP tool parameters. The MCP server cannot switch
profiles after connecting; select a pre-opened page in the matching profile and verify the visible
account identity. If the requested profile is not among the attached pages, the scenario is blocked.

## Execute and collect evidence

Use Chrome MCP for all browser interaction. Do not call `new_page`: navigate or reuse a pre-opened
page only after selecting an existing page in the matching profile and verifying its identity. If
the required page/profile is not already open, mark the scenario blocked. Confirm the origin,
profile, and logged-in identity before each protected scenario. Keep the
test sequence deterministic: reset to a known start state, perform only the listed actions, and
capture the final URL plus visible success/error state. Use screenshots or other browser evidence
when available, especially for failures and authorization checks. Avoid exposing tokens, cookies,
passwords, or unnecessary personal data in the report.

For every scenario, record:

- environment label and exact base URL (MR preview, dev, or approved prod);
- Chrome MCP profile and logged-in identity;
- setup/data assumptions and actions performed;
- expected result and observed result;
- pass, fail, blocked, or not-applicable status, with concise evidence.

If the environment, profile, fixture, or browser MCP is unavailable, mark the scenario blocked and
explain the missing prerequisite. Do not call a skipped or partially exercised scenario a pass.
If a product defect appears, preserve the evidence and report the smallest reproducible path; do
not patch it inside this skill unless separately instructed.

## Finish the loop

Summarize coverage by scenario and distinguish passed, failed, blocked, and untested cases. Include
the exact environment/profile used and any limitations. For MR or ticket work, return the evidence
to the caller (`mr-loop` or `ticket-loop`) without claiming mergeability or ticket completion:
those loops still require their own review, CI, synchronization, and publication gates. If all
requested scenarios pass, say precisely what passed and what was not exercised.
