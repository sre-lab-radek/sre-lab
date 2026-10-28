# Postmortem: CI validation with GitHub Actions (lab6)

**Date:** 2026-10-28
**Type:** New pipeline rollout plus a planned failure test
**Impact:** none on running systems (CI only validates files)
**Outcome:** pipeline `validate` is green on main and fails on a deliberately broken alert rule

## Summary
A GitHub Actions workflow (`.github/workflows/validate.yml`) was added to validate the
repository on every push and pull request: yamllint, `ansible-playbook --syntax-check`,
`promtool check config` (Prometheus config and alert rules), `amtool check-config`
(Alertmanager) and `docker compose config`. The first run failed on a trivial style issue,
two follow-up runs were green, and a test branch with a broken alert expression was
correctly rejected by the pipeline.

## Pipeline contents
- Lint YAML files (yamllint, `extends: relaxed`, `line-length` disabled)
- Check Ansible playbooks (syntax only, from `lab1/` so `ansible.cfg` is found)
- Check Prometheus config and rules (`promtool` in a container)
- Check Alertmanager config (`amtool`, dummy token file; the real token is never in the repo)
- Validate docker compose file (`docker compose config -q`)

## Timeline (UTC; run times approximate, derived from "minutes ago" on the Actions page)
| Run | Approx. time (UTC) | Commit message | Branch | Result | Duration |
|---|---|---|---|---|---|
| #1 | 19:28 | lab6: CI validation with GitHub Actions | main | failed | 11 s |
| #2 | 19:36 | lab6: add trailing newlines (yamllint), update postmortem | main | passed | 25 s |
| #3 | 19:40 | lab6: bump actions/checkout to v6 (Node 24) | main | passed | 22 s |
| #4 | 19:42 | test: broken alert expression | test-broken-alert | failed (expected) | 23 s |

## What happened in each run
- **#1 (failed, 11 s):** the lint step reported `new-line-at-end-of-file` for all 9 YAML files.
  Cause: files created in the VS Code editor had no trailing newline. It was not a config
  error, only a style rule. The pipeline stopped at the first failing step, so the later steps
  did not run.
- **#2 (passed, 25 s):** newline added to all 9 files with a one-line shell loop. All steps ran
  for the first time and passed. The run ended with a warning that `actions/checkout@v4`
  targets Node.js 20, which is deprecated.
- **#3 (passed, 22 s):** `actions/checkout` bumped to `v6` (Node 24). The warning disappeared.
- **#4 (failed, 23 s, expected):** on branch `test-broken-alert`, the alert rule
  `expr: up == 0` was changed to `expr: up ==`. The `promtool` step failed with:
  `alerts.yml: 5:15: group "lab", rule 1, "InstanceDown": could not parse expression:
  1:6: parse error: unexpected end of input`. The error points to the exact file, line and
  rule. yamllint and the Ansible syntax check passed first, because they only validate
  YAML structure, not PromQL.

## What went well
- The pipeline caught a real class of mistake (broken alert expression) in 23 s, before it
  could reach the running Prometheus.
- The error message identified the file, line, group and rule name.
- A secret never entered CI: Alertmanager validation used a dummy token file.
- Cleanup was verified after the test (branch deleted locally and on GitHub,
  `expr: up == 0` confirmed in `lab2/alerts.yml`).

## What went wrong / lessons learned
- Editor-created files lacked a trailing newline. Fix: enable "Files: Insert Final Newline"
  (Remote [SSH: sre-lab] settings), done.
- YAML text was pasted into the terminal once instead of the editor (`-: command not found`).
  Nothing was executed, but only commands belong in the terminal and only file content in
  the editor.
- A copy/paste error (`-qr` instead of `-q` on the last line of `validate.yml`) was caught
  by a local check (`tail`) before the first push. Reading the file back before committing works.
- yamllint is not enough: only semantic validators (`promtool`, `amtool`) catch broken rules.
  Linters and tool-specific checkers complement each other.
- The failure test was done on a branch, but the Prometheus container mounts files from the
  working directory of the same server. While the test branch was checked out, a broken
  `alerts.yml` was on disk, and a Prometheus restart in that moment would have failed.
  The branch was cleaned up right after the test.
- The Node 20 deprecation warning is a reminder that pinned action versions age;
  they need periodic updates.

## Action items
- [x] Add CI validation on every push and pull request
- [x] Prove the pipeline fails on a broken alert rule
- [x] Enable "Insert Final Newline" in VS Code (remote)
- [x] Bump `actions/checkout` to a Node 24 version
- [ ] Add a status badge for the `validate` workflow to README.md
- [ ] Require the `validate` check to pass before merging to main (branch protection)
- [ ] Add dependabot for GitHub Actions versions
- [ ] Add a local pre-commit hook running yamllint
- [ ] Do failure tests on a copy of the stack or in a separate directory, not in the working tree
- [ ] CD: deploy validated configs with Ansible after a green run
