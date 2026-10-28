# Postmortem: pull-based CD for the monitoring stack (lab7)

**Date:** 2026-10-28
**Type:** New deployment automation plus planned failure tests
**Impact on running systems:** none lasting. Two false `InstanceDown` alerts (one firing/resolved pair) were sent to Telegram.
**Outcome:** a cron job deploys the monitoring config from `main` every 5 minutes, verifies it, and rolls back automatically on failure.

## Summary
A self-hosted GitHub Actions runner was the first plan, but it was dropped because the
repository is public (a runner in a public repo can execute code from outside pull requests),
and the repository could not be switched to private (the "Change visibility" button did
nothing; email verified, incognito mode tried, cause not found). A pull-based design was
built instead: `~/deploy/pull-deploy.sh` fetches `main`, validates the config with
`promtool` and `amtool`, deploys to `~/deploy/lab2`, checks that all Prometheus targets are
`up` (12 tries, 5 s apart), and rolls back on failure. It runs from cron every 5 minutes
with `flock`. The script lives outside the repository on purpose, so a commit cannot change
the code that runs on the server.

## Design
- Source: `git fetch origin main` into `~/deploy/src`; each commit SHA is handled once
  (state in `~/deploy/last_sha`); a rejected commit is fixed with a new commit.
- Validation: `promtool check config` (config and rules), `amtool check-config` with a dummy
  token, `docker compose config -q`.
- Deploy: previous files copied to `.previous/`, new files copied in,
  `docker compose -p lab2 up -d --force-recreate prometheus alertmanager`.
  Grafana and blackbox are not touched.
- Health check: Alertmanager `/-/healthy` and all targets `up` within 60 s; otherwise rollback.
- Secrets: the Telegram token lives only in `~/deploy/lab2/secrets` (gitignored, never in the repo).

## Timeline (UTC; local time = UTC+1)
| Time (UTC) | Event |
|---|---|
| 19:49 | CI run #5 green (commit fe8b3e0, last commit before CD) |
| 20:21:36 | first run of the script: repository cloned (from git reflog); its own output was not saved |
| 20:23:37 | test A: wrong port (`:9199`) pushed, commit 809dfb7 (CI #6 green) |
| 20:23:39 | script: validation passed, containers recreated |
| 20:24:42 | health check failed (`1 not up`), rollback done (about 63 s) |
| 20:25:31 | revert 94820f2 pushed (CI #7 green) |
| 20:26:01 | script: `DEPLOY OK` (about 27 s from detection of the new commit) |
| 20:26:41 / 20:26:48 | `InstanceDown` for `192.168.122.14:9199` pending, then firing (Telegram about 20:26) |
| 20:28:19 | test B: the same wrong port pushed again, commit 131ca5e (CI #8 green) |
| 20:29:24 | health check failed, rollback done (about 63 s) |
| 20:34:09 | series `up{instance="192.168.122.14:9199"}` stops being visible |
| 20:34 | Telegram: `InstanceDown` `Resolved` for the same instance |
| 20:35:02 | cron deployed revert 3ec9937 (CI #9 green), `DEPLOY OK` at 20:35:24 |
| about 21:02 | test C: broken alert expression pushed, commit 73ffa2b (CI red on promtool) |
| 21:02:11 | script: `REJECTED: validation failed, nothing deployed` |
| after 21:02 | revert 9e75b2e deployed, `DEPLOY OK`; exact push time not recorded |

Notes: the revert push time of 3ec9937 was not recorded, so the push-to-deploy time of
cron is known only as "at most 5 minutes". Test B repeated test A. During about 7 minutes
`main` held the bad port until the revert was deployed.

## Results
- Test A and B (wrong port, valid syntax): CI green, validation passed, health check
  caught it, automatic rollback in about 63 s each. Final state `8 "health":"up"`.
- Test C (broken PromQL expression): CI failed on `promtool`, and the server rejected the
  commit before touching any container. `promtool` message:
  `alerts.yml: 5:15: group "lab", rule 1, "InstanceDown": could not parse expression:
  1:6: parse error: unexpected end of input`. No new alert reached Telegram after 21:00.
- Cron test: the revert was deployed automatically at 20:35:02 without manual action.

## False alert: InstanceDown for a target that no longer existed
Both `InstanceDown` messages were for `192.168.122.14:9199`, the wrong target. The
`Firing` message arrived about 2 minutes after the first rollback (when the port was
already removed from the config), and `Resolved` arrived at 20:34, about 5 minutes after
the last rollback. The last visible sample of the series was at 20:34:09.
- Hypothesis 1 (consistent with the data, not proven): the container was recreated instead
  of reloaded, so the old series did not get an end marker and Prometheus kept reading the
  last value (0) for about 5 minutes. The alert ended when the series went stale.
- Hypothesis 2 (not checked): the alert state was restored after the restart, which could
  explain why pending to firing took only 7 s even though the rule has `for: 1m`.
- Not explained: why the first alert appeared at 20:26 and not right after the restart.
- Evidence for hypothesis 1: after the rejected deploy (no containers recreated) and after
  the healthy deploy of the revert, no false alert was sent.

## What went well
- Three layers caught three kinds of mistakes: CI (syntax), server validation (syntax and
  semantics before deploy), health check (runtime behaviour after deploy).
- Rollback worked twice without manual intervention and took about a minute.
- A rejected commit left the running stack untouched.
- Secrets stayed out of the repository and out of CI.
- Runs are idempotent: a second run without a new commit exits silently with code 0.

## What went wrong / lessons learned
- CI was green for both wrong-port commits. CI validates syntax and cannot know whether a
  target exists, so the health check after deploy is a separate and necessary safety net.
- The same test was run twice, so `main` was left in a broken state for about 7 minutes
  until the revert was deployed by cron.
- Recreating containers produced false alerts. Reloading the config in the running process
  is the better pattern.
- The first manual run's output and the exact push times were not saved, so some
  durations could not be measured.
- The self-hosted runner variant was dropped: a public repository makes it unsafe.
- The deploy script is not versioned in the repository, so it has no history or review.
- Right after a restart Prometheus shows `0 targets` and several targets `unknown` for a
  few seconds, so a health check without retries would roll back every deploy.

## Action items
- [ ] Reload Prometheus instead of recreating it (`--web.enable-lifecycle` plus
      `curl -X POST localhost:9090/-/reload`) and repeat test A to see whether the false
      alert disappears
- [ ] Check hypothesis 2 (`ALERTS_FOR_STATE` after restart)
- [ ] Add `date` to start and end of every failure test and save the output
- [ ] Rotate `~/deploy/deploy.log` (logrotate)
- [ ] Send a Telegram message from the script on REJECTED and ROLLBACK
- [ ] Keep a reference copy of `pull-deploy.sh` in a private place (not executed from the repo)
- [ ] Make the repository private and retry the self-hosted runner variant
      (or retest the visibility button in another browser)
- [ ] Do failure tests on a branch or a copy of the stack, not on `main`
