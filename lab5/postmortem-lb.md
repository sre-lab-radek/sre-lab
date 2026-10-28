# Postmortem: single backend failure behind a load balancer (lab5)

**Date:** 2026-10-28
**Type:** Failure injection (planned test)
**Impact on users:** none (20/20 test requests served, service probe never failed)
**Impact on backend:** web2 unavailable for about 3 minutes
**Detection:** Prometheus alert `WebBackendProbeFailing` (severity: warning), delivered to Telegram

## Summary
A load balancer (nginx on lb1, 192.168.122.20) was placed in front of web1 and web2.
nginx was then stopped on web2 for about 3 minutes to check that a single backend failure
is invisible to users while still being reported to a human. All 20 test requests through
lb1 were served by web1, the service-level probe stayed at 1 during the whole outage, and
the error budget remained at 100%.

## Setup tested
- lb1: nginx reverse proxy, upstream `web_backend` with web1 and web2
  (`max_fails=1`, `fail_timeout=10s`, `proxy_next_upstream` on error/timeout/502/503/504)
- Monitoring: blackbox probe on each backend (`job=blackbox-http`) and one probe through the
  load balancer (`job=blackbox-lb`), scraped every 15s, rules evaluated every 15s
- SLO (service level): 99% successful probes over 6h (error budget: 14.4 failed probes),
  computed from `job=blackbox-lb`
- Alerts: `WebBackendProbeFailing` (warning, backend probe fails for 30s),
  `ServiceProbeFailing` (critical, probe through lb1 fails for 30s), `InstanceDown` (critical)
- All 8 Prometheus targets were `up` before the test

## Timeline (UTC; local time = UTC+1)
| Time (UTC) | Event |
|---|---|
| 18:42:46 | nginx stopped on web2 (command issued) |
| 18:42:50 | backend probe for web2 first fails (`probe_success` = 0) |
| 18:42:50+ | 20 requests through lb1: 20 x "Hello from web1", no errors |
| 18:43 | Telegram: `[FIRING]` `WebBackendProbeFailing` (about 1 min after the stop) |
| 18:45:50 | backend probe for web2 recovers (nginx started again; about 3 min outage) |
| 18:46 | Telegram: `[RESOLVED]` received |

The restart time was not recorded when the command was run. It was reconstructed from the
`probe_success{instance="http://192.168.122.175"}` graph (accuracy: one scrape interval, 15s).

## Results
- Backend probe web2: 0 for about 3 minutes, then back to 1.
- User-facing test: 20 requests through lb1 returned 20 x "Hello from web1", 0 errors.
- Service probe through lb1: `min_over_time(probe_success{job="blackbox-lb"}[20m])` = 1,
  and 0 failed probes in the window.
- Error budget: `slo:error_budget_remaining:ratio_6h{job="blackbox-lb"}` = 1 (100% left).
- Alert fired: `WebBackendProbeFailing` (warning). `ServiceProbeFailing` did not fire,
  as expected.
- Time to detect: about 1 minute from failure to Telegram message (down from about 2 minutes
  before `evaluation_interval` was reduced from 1m to 15s).

## What went well
- The load balancer hid the backend failure completely: 20/20 requests succeeded and the
  service probe never failed.
- A human was still notified (Telegram) about the degraded backend.
- Splitting alerts by severity separated "one backend down" (warning) from
  "service down" (critical).
- Detection time was about 1 minute, consistent with the configured intervals.

## What went wrong / lessons learned
- Ansible was first run from `lab5/` and failed with `Permission denied (publickey)`:
  `ansible.cfg` (remote_user, key file) is read only from the current directory.
  Playbooks must be run from `lab1/`.
- After editing `prometheus.yml`, Prometheus kept the old configuration until restarted
  (`activeAlertmanagers` was empty earlier for the same reason).
- Right after the restart, targets showed `unknown` for a few seconds until the first scrape.
- After changing the SLO rules, old series (`job=blackbox-http`) stayed visible in Grafana.
  Dashboard queries should filter on `job="blackbox-lb"`.
- The 6h availability panel is misleading until a full 6h of data exists.
- `RESOLVED` arrives with a small delay (rule evaluation plus Alertmanager grouping),
  so it does not mark the exact recovery time.
- The restart time of nginx was not noted down; it had to be read from a graph.

## Action items
- [x] Put a load balancer in front of web1/web2
- [x] Measure the SLO from the user's perspective (probe through lb1)
- [ ] Add a CI pipeline validating configs on every push (lab6)
- [ ] Filter Grafana SLO panels on `job="blackbox-lb"`
- [ ] Run `date` in the same command line for both stop and start in future failure tests
- [ ] lb1 is a single point of failure: consider a second load balancer or keepalived