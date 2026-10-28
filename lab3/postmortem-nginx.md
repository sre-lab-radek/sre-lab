# Postmortem: nginx stopped on web2 (lab simulation)

**Date:** 2026-10-28
**Impact:** web2 returned no HTTP responses for roughly 2-3 minutes; web1 unaffected.
**Detection:** Prometheus alert `WebProbeFailing` (blackbox HTTP probe). `InstanceDown` did NOT fire.
**Time to detect:** about 2 minutes from first failed probe to firing alert.

## Timeline (UTC)
- 16:32 (TODO: exact time from `date`) nginx stopped on web2 (failure injection); first failed probe
- 16:32:56 `WebProbeFailing` enters pending (first rule evaluation that sees the failure)
- 16:33:58 `WebProbeFailing` firing (observed; next evaluation after `for: 30s`)
- TODO nginx started again on web2
- TODO probes succeeding again, alert resolved

## Detection analysis
- Scrape interval is 15s, but rules are evaluated every `evaluation_interval` (default 1m, not set explicitly).
- Pending to firing took about 1 minute, although the rule says `for: 30s`: the `for` duration is only checked at evaluation time, so it is rounded up to the next evaluation.
- Detection time is dominated by `evaluation_interval`, not by `scrape_interval` or `for`.

## SLO impact
- SLO: 99% successful probes over a 6h window (error budget: 14.4 failed probes at 15s interval).
- Used: about 9 failed probes. Error budget remaining: 37.5%.
- The availability panel showed 94.8% because the probe history was shorter than 6h (blackbox had been running for about 45 minutes). The error budget panel is more reliable, as it divides by a fixed 6h window.

## What went well
- The HTTP probe detected the application failure without manual checks.
- web1 stayed at 100% availability throughout.
- Recovery was a single command (service start via Ansible).

## What went wrong / lessons learned
- Host-level monitoring (`up`, node_exporter) did not detect the failure: the VM and the exporter were healthy while nginx was down.
- Only probing what the user sees (HTTP) caught the application failure.
- The availability panel is misleading until a full 6h of data exists.
- Alert reached nobody: there is no notification channel.

## Action items
- [ ] Add Alertmanager with notifications (Telegram/Discord/e-mail)
- [ ] Set `evaluation_interval: 15s` and re-run the test to compare detection time
- [ ] Put a load balancer in front of web1/web2 so a single web failure is invisible to users
- [ ] Extend the availability panel to show data only when a full 6h window exists