
# sre-lab

A self-taught SRE / DevOps home lab, built step by step and documented as I went.
Each lab builds a small piece of infrastructure, breaks it on purpose, measures what
happened and ends with a blameless postmortem.

The full learning log (history, decisions, mistakes, quizzes) lives in
[`notes/sre-lab-notatnik.md`](notes/sre-lab-notatnik.md). It is written in Polish.
Some postmortems are in English, some in Polish (marked below).

Highlights: KVM + Ansible lab with rolling patching · Prometheus/Alertmanager with SLO error budgets · CI that blocks broken alert rules · pull-based CD with automatic rollback (63 s) · the same lab rebuilt in AWS with Terraform · external monitoring from a VPS over WireGuard

## Environment

| Part | What it is | Used for |
|---|---|---|
| Home PC | Ubuntu Server on its own SATA disk (dual boot with Windows), i5-12600K, 32 GB RAM | KVM hypervisor for the lab VMs, Docker host for the monitoring stack, Ansible and Terraform control node. Switched off at night. |
| Lab VMs | KVM/libvirt guests from the Ubuntu 24.04 cloud image, configured by cloud-init | `web1`, `web2` (nginx), `db1` (PostgreSQL), `lb1` (nginx load balancer) |
| Laptop | MacBook, SSH client only | editor (VS Code Remote-SSH), terminal, browser |
| VPS | small Ubuntu VPS (OVHcloud), runs 24/7 | external monitoring of the home PC over a WireGuard tunnel, daily AWS cost check |
| AWS | Free plan account, region `eu-north-1` | short-lived copy of the lab built with Terraform, destroyed after every session |

Addresses, account names and Telegram identifiers are intentionally left out of this README.

## Labs

Directory numbers do not match the chapter numbers in the notebook, and there is no `lab4`
directory. The last column points to the matching notebook chapter ("Dział").

| Lab | Topic | Tools | Description | Notebook |
|---|---|---|---|---|
| [`lab1`](lab1) | Virtual machines and configuration management | KVM, libvirt, cloud-init, Ansible | Creates `web1`, `web2` and `db1` from a shared cloud image and configures nginx, PostgreSQL, node_exporter and rolling (`serial: 1`) patching with Ansible. | Dział 2, 3 |
| [`lab2`](lab2) | Monitoring, SLO and alerting | Prometheus, Grafana, Alertmanager, blackbox_exporter, Docker Compose | Monitoring stack with host and HTTP probes, SLO recording rules (99% over 6 h) and alerts delivered to Telegram. | Dział 4, 5, 6 |
| [`lab3`](lab3) | Load test and application-level failure | k6 | k6 script ramping up to 1000 virtual users against the web servers, plus a postmortem of an nginx outage. | Dział 5 |
| [`lab5`](lab5) | Load balancer | nginx, Ansible, libvirt | Adds `lb1` as an nginx reverse proxy in front of `web1`/`web2` with passive health checks and retries. | Dział 7 |
| [`lab6`](lab6) | Continuous integration | GitHub Actions, yamllint, ansible-playbook, promtool, amtool | Postmortem of the CI rollout; the workflow itself is [`.github/workflows/validate.yml`](.github/workflows/validate.yml). | Dział 8 |
| [`lab7`](lab7) | Pull-based continuous deployment | cron, Bash, Docker Compose, Git | Postmortems of the deploy/rollback tests; the deploy script is kept outside the repo on purpose. | Dział 9 |
| [`lab8`](lab8) | The lab rebuilt in AWS | Terraform, AWS (VPC, EC2, ALB, Security Groups), Ansible, Jinja2 | VPC, two nginx instances behind an ALB and a monitoring instance, all created by Terraform and configured by Ansible. | Dział 10 |
| [`lab9`](lab9) | External monitoring from a VPS | WireGuard, Prometheus, blackbox_exporter, Alertmanager, AWS CLI (Cost Explorer) | Copies of the VPS monitoring config (no secrets) that probes the home PC through a tunnel, plus a daily AWS cost alert script. | Dział 11 |

### What is in each directory

```
.github/workflows/validate.yml   CI: lint and validate configs on every push and PR
.yamllint                        yamllint rules (relaxed, no line-length limit)
lab1/  create-vms.sh             builds web1, web2, db1 (qcow2 + cloud-init seed ISO)
       ansible.cfg, inventory.ini
       site.yml                  nginx on [web], PostgreSQL on [db]
       node-exporter.yml         node_exporter on all lab VMs
       patch.yml                 rolling apt upgrade, optional reboot (-e do_reboot=true)
lab2/  docker-compose.yml        Prometheus, Alertmanager, Grafana, blackbox (host network)
       prometheus.yml            targets: nodes, per-backend HTTP probes, probe through lb1
       alerts.yml                InstanceDown, WebBackendProbeFailing, ServiceProbeFailing, SLO rules
       alertmanager.yml          Telegram receiver, token read from a file
       postmortem-web2.md        short timeline of the first VM shutdown test
lab3/  load-test.js              k6 scenario, thresholds p95 < 200 ms and < 1% errors
       postmortem-nginx.md
lab5/  create-lb.sh              builds lb1 with a DHCP reservation and autostart
       lb.yml                    nginx upstream config for lb1
       postmortem-lb.md
lab6/  postmortem-ci.md
lab7/  postmortem-cd.md, postmortem-rollback.md (PL)
lab8/  main.tf                   provider, VPC, subnets in two AZs, routing, web Security Group
       ec2.tf                    AMI lookup, key pair, web1/web2 (for_each), ALB, target group
       monitoring.tf             monitoring instance and its Security Group
       ansible/gen-inventory.py  builds the Ansible inventory from `terraform output -json`
       ansible/monitoring.yml    node_exporter everywhere, Docker monitoring stack on mon1
       ansible/templates/prometheus.yml.j2
       postmortem-aws.md (PL)
lab9/  vps/docker-compose.yml    Prometheus, Alertmanager, blackbox, all bound to loopback
       vps/prometheus.yml, vps/alerts.yml
       vps/alertmanager.example.yml   template; the real file stays on the VPS
       vps/aws-cost.sh           daily cost check via Cost Explorer, Telegram above a threshold
       postmortem-vps-monitoring.md (PL)
notes/ sre-lab-notatnik.md       learning log (PL)
       plan-nauki.md             learning plan (PL)
```

## Results and tests

All tests were planned failure injections in a lab, not production incidents. Times come
from `date`, logs and Prometheus queries; numbers marked "about" were read from graphs or
from Telegram timestamps that only show the minute.

| Test | Result | Postmortem |
|---|---|---|
| Detection time tuning | Failure to firing alert: about 2 min with the default `evaluation_interval` (1 m), about 1 min after setting it to 15 s. Detection time was dominated by rule evaluation, not by scrape interval or `for`. | [lab3/postmortem-nginx.md](lab3/postmortem-nginx.md) |
| Host vs. application monitoring | nginx stopped on a healthy VM: `InstanceDown` did not fire, only the HTTP probe caught it. About 9 failed probes left 37.5% of the 6 h error budget (14.4 failed probes allowed). | [lab3/postmortem-nginx.md](lab3/postmortem-nginx.md)¹ |
| Load test (k6) | 100 VUs: 440 req/s, 0% errors, p95 1.82 ms. 1000 VUs: 3743 req/s, 0% errors, p95 3.89 ms, max 61 ms, `web1` CPU about 33%. The generator ran on the same PC, so the numbers are optimistic. | notebook, Dział 5 |
| One backend down behind the load balancer | 20 of 20 requests through `lb1` served by `web1`, service probe never failed, error budget stayed at 100%, warning alert on Telegram after about 1 min. | [lab5/postmortem-lb.md](lab5/postmortem-lb.md) |
| CI rejects a broken alert rule | A branch with `expr: up ==` failed on the `promtool` step in 23 s with file, line and rule name in the error. | [lab6/postmortem-ci.md](lab6/postmortem-ci.md) |
| CD: three layers of checks | Wrong port (valid syntax): CI green, server-side validation passed, post-deploy health check failed, automatic rollback in about 63 s. Broken PromQL: CI red and the server refused to deploy. | [lab7/postmortem-cd.md](lab7/postmortem-cd.md) |
| Rollback test with a dead target | Push to detection 4 min 33 s (cron tick), detection to rollback 63 s. After the rollback a **false** `InstanceDown` fired for 3 min 40 s for a target that no longer existed. Strongly supported hypothesis: the container was recreated instead of reloaded, so no stale marker was written and the last `up = 0` sample lived for the 5-minute lookback. Not yet proven (test D2 pending). | [lab7/postmortem-rollback.md](lab7/postmortem-rollback.md) (PL) |
| AWS: backend down behind an ALB | Alert firing 54 s after nginx was stopped; ALB returned `502` for about 1.5–2 min until its health check (3 × 30 s) removed the backend; probe recovered 19 s after restart. `terraform destroy` removed 18 resources in 72 s. Day cost about 0.18 USD before credits. | [lab8/postmortem-aws.md](lab8/postmortem-aws.md) (PL) |
| External monitoring from the VPS | Prometheus on the home PC stopped: rule firing on the VPS after about 5 min 55 s, Telegram message after 6.4–7.3 min, against a prediction of 5.5–6 min. Hypothesis: `evaluation_interval` not set on the VPS (default 1 m). *Resolved* arrived about 5 min after recovery (default `group_interval`). | [lab9/postmortem-vps-monitoring.md](lab9/postmortem-vps-monitoring.md) (PL) |

¹ The postmortem uses the alert's earlier name `WebProbeFailing`; it is `WebBackendProbeFailing` in the current [`lab2/alerts.yml`](lab2/alerts.yml).

Lessons that came up again and again: write the time down before and after every test,
read times from metrics and logs (Prometheus, Ansible and the VPS use UTC), write the
prediction before the test, and keep monitoring outside the machine it watches.

## Requirements

Home lab (`lab1`, `lab2`, `lab3`, `lab5`):

- Ubuntu host with hardware virtualization enabled (`kvm-ok` must report that KVM acceleration can be used)
- `qemu-system-x86`, libvirt with the `default` network, `virt-install`, `cloud-localds` (cloud-image-utils), `qemu-img`
- Ubuntu 24.04 cloud image saved as `/var/lib/libvirt/images/noble-base.img`
- SSH key pair `~/.ssh/lab_vm` and `~/.ssh/lab_vm.pub` (used by the scripts, Ansible and Terraform)
- Ansible
- Docker Engine with the Compose plugin
- k6 (only for `lab3`)
- A Telegram bot and a chat that receives its messages (for Alertmanager)

AWS (`lab8`):

- AWS account with an IAM user and access key for Terraform, AWS CLI configured
- Terraform `>= 1.5` (AWS provider `~> 6.0`, pinned in `.terraform.lock.hcl`)
- Ansible and Python 3 on the control node
- A cost budget in AWS before the first `apply`

VPS (`lab9`):

- Ubuntu VPS with Docker and the Compose plugin
- WireGuard tunnel between the VPS and the home PC (config is not in this repo)
- AWS CLI with a read-only Cost Explorer user, for `aws-cost.sh`
- A second Telegram bot

CI needs nothing extra: GitHub-hosted `ubuntu-latest` installs yamllint and ansible-core and
runs promtool and amtool from the official images.

## Secrets

No secret is stored in this repository. These are the names and locations the code expects.

| Secret | Location | Used by | Notes |
|---|---|---|---|
| Telegram bot token (lab) | `lab2/secrets/telegram_token` (on the deploy target: `~/deploy/lab2/secrets/telegram_token`) | `lab2` Alertmanager (`bot_token_file`) | Gitignored (`lab2/secrets/`). The container runs as `nobody`, so the file is owned by uid 65534, mode 600. |
| Telegram chat ID (lab) | `chat_id` in `lab2/alertmanager.yml` | `lab2` Alertmanager | Configuration value, not a credential. |
| SSH private key for VMs and EC2 | `~/.ssh/lab_vm` (public part `~/.ssh/lab_vm.pub`) | `create-vms.sh`, `create-lb.sh`, both `ansible.cfg` files, `aws_key_pair` in `lab8/ec2.tf` | Never committed (`id_*`, `*.key`, `*.pem` are gitignored). |
| AWS access key (Terraform user) | `~/.aws/credentials` on the home PC | Terraform, AWS CLI | Never in the repo or in CI. |
| Your public IP | `lab8/terraform.tfvars` (`my_ip = "x.x.x.x/32"`) | Security Group rules for SSH, Prometheus, Grafana | Gitignored (`*.tfvars`). |
| Terraform state | `lab8/terraform.tfstate` | Terraform | Gitignored, contains resource details. |
| Generated inventory | `lab8/ansible/inventory.ini` | Ansible in `lab8` | Gitignored, regenerated after every `apply`. |
| Telegram bot token (VPS) | `~/.secrets/telegram_token` on the VPS (directory 700, file 600) | `lab9` Alertmanager (mounted read-only), `aws-cost.sh` | `aws-cost.sh` passes it to `curl -K -`, so it never shows up in the process list. |
| Telegram chat ID (VPS) | `~/.secrets/telegram_chat_id` on the VPS | `aws-cost.sh` | |
| Real Alertmanager config (VPS) | `alertmanager.yml` next to `docker-compose.yml` on the VPS | `lab9` Alertmanager | Created from `lab9/vps/alertmanager.example.yml`; kept off GitHub because it contains the chat ID. |
| AWS access key (cost reader) | `~/.aws/credentials` on the VPS | `aws-cost.sh` | Least-privilege user for Cost Explorer only; no admin keys on the VPS. |
| WireGuard private keys | WireGuard config on the VPS and the home PC | `wg-quick@wg0` | Only public keys are ever shared. |

CI uses a fake token (`dummy-token`) so `amtool` finds the file; the real token never reaches CI.

## Reproducing a lab

### Home lab core: VMs (lab1), load balancer (lab5) and monitoring (lab2)

`lab2` monitors the VMs from `lab1` and `lab5`, so they are built together. All commands run
on the Ubuntu host from the repository root unless a `cd` says otherwise.

**1. Prepare the host**

```bash
kvm-ok                                    # must say KVM acceleration can be used
sudo apt install qemu-system-x86 libvirt-daemon-system virtinst cloud-image-utils ansible
sudo virsh net-autostart default
ssh-keygen -t ed25519 -f ~/.ssh/lab_vm
sudo wget -O /var/lib/libvirt/images/noble-base.img \
  https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
```

Install Docker Engine with the Compose plugin as well (Docker's own apt repository).

**2. Create the VMs**

```bash
bash lab1/create-vms.sh                   # web1, web2, db1
bash lab5/create-lb.sh                    # lb1 with a fixed DHCP reservation
for vm in web1 web2 db1; do virsh autostart $vm; done
virsh net-dhcp-leases default             # note the addresses
```

`create-vms.sh` does not reserve addresses or enable autostart; without autostart the VMs
stay off after a host reboot (`No route to host`).

**3. Put your addresses into the config**

VM addresses are hard-coded. Update them in:
`lab1/inventory.ini`, `lab2/prometheus.yml` (`nodes`, `blackbox-http`, `blackbox-lb`),
`lab5/lb.yml` (upstream servers), `lab5/create-lb.sh` (`MAC`, `IP`) and `lab3/load-test.js`.

**4. Configure the VMs with Ansible**

Always run Ansible from `lab1/`, because `ansible.cfg` (user `sre`, key `lab_vm`) is only
read from the current directory.

```bash
cd lab1
ansible all -m ping
ansible-playbook site.yml
ansible-playbook node-exporter.yml
ansible-playbook ../lab5/lb.yml
ansible-playbook site.yml                 # second run should report changed=0
ansible-playbook patch.yml --check        # optional: rolling patching dry run
cd ..
```

Check the load balancer: `for i in $(seq 20); do curl -s http://<lb1-address>; done | sort | uniq -c`
should show both `Hello from web1` and `Hello from web2`.

**5. Add the Telegram secret**

Type `read -rs TOKEN` on its own line, press Enter, then paste the token (this keeps it out of the shell history).

```bash
mkdir -p lab2/secrets
read -rs TOKEN
printf '%s' "$TOKEN" > lab2/secrets/telegram_token; unset TOKEN
sudo chown 65534:65534 lab2/secrets/telegram_token
sudo chmod 600 lab2/secrets/telegram_token
git check-ignore -v lab2/secrets/telegram_token   # must print the .gitignore rule
```

Set your own `chat_id` in `lab2/alertmanager.yml` (send `/start` to the bot, then read it from the Bot API `getUpdates`).

**6. Validate the config (the same checks as CI)**

```bash
yamllint .
docker run --rm --entrypoint promtool \
  -v "$PWD/lab2/prometheus.yml:/etc/prometheus/prometheus.yml:ro" \
  -v "$PWD/lab2/alerts.yml:/etc/prometheus/alerts.yml:ro" \
  prom/prometheus check config /etc/prometheus/prometheus.yml
docker run --rm --entrypoint amtool \
  -v "$PWD/lab2/alertmanager.yml:/a.yml:ro" \
  -v "$PWD/lab2/secrets/telegram_token:/etc/alertmanager/telegram_token:ro" \
  prom/alertmanager check-config /a.yml
docker compose -f lab2/docker-compose.yml config -q
```

**7. Start the monitoring stack**

```bash
cd lab2
docker compose up -d
docker compose ps
curl -s http://localhost:9090/api/v1/targets | grep -o '"health":"[a-z]*"' | sort | uniq -c   # expect 8 up
curl -s http://localhost:9090/api/v1/alertmanagers           # activeAlertmanagers must not be empty
curl -s -XPOST http://localhost:9093/api/v2/alerts -H 'Content-Type: application/json' \
  -d '[{"labels":{"alertname":"TestAlert","severity":"info"},"annotations":{"summary":"Test"}}]'
```

The test alert should reach Telegram in about 10 s (`group_wait`). Targets show `unknown` for a few seconds after a restart; that is normal.

Grafana runs on port 3000 (log in as `admin`/`admin` and change the password). Add Prometheus
as a data source and import dashboard ID 1860 (Node Exporter Full); dashboards are not
stored in this repo.

After editing `prometheus.yml` or `alerts.yml`, reload Prometheus (`--web.enable-lifecycle` is on):
`curl -s -X POST http://localhost:9090/-/reload`. Saving the file alone changes nothing.

**8. Run a failure test**

```bash
cd lab1
date -Is; ansible web2 -b -m ansible.builtin.service -a "name=nginx state=stopped"
# wait for WebBackendProbeFailing (warning) on Telegram, expected about 1 min
date -Is; ansible web2 -b -m ansible.builtin.service -a "name=nginx state=started"
```

Useful queries in Prometheus afterwards:

```
probe_success{job="blackbox-lb"}
min_over_time(probe_success{job="blackbox-lb"}[20m])
slo:error_budget_remaining:ratio_6h{job="blackbox-lb"}
```

Optional load test: `k6 run lab3/load-test.js`.

**9. Clean up**

`docker compose down` in `lab2` stops the stack and keeps the data volumes; `docker compose down -v` deletes them too.
VMs: `virsh shutdown <name>`.

### AWS (lab8)

This creates billable resources. Set a cost budget first and destroy everything at the end of the session.

```bash
aws configure                             # region eu-north-1
aws sts get-caller-identity               # confirm the key works

cd lab8
echo 'my_ip = "<your-public-ip>/32"' > terraform.tfvars
terraform init
terraform fmt && terraform validate
terraform plan                            # read it, especially -/+ and -
terraform apply

ALB=$(terraform output -raw alb_dns)
for i in $(seq 20); do curl -s http://$ALB; done | sort | uniq -c   # about 10 x web1, 10 x web2
# a fresh ALB can take a few minutes before targets pass the health check

cd ansible
python3 gen-inventory.py > inventory.ini  # must be run from lab8/ansible
ansible all -m ping
ansible-playbook monitoring.yml           # run twice: the second run should be changed=0
```

Prometheus and Grafana on the monitoring instance (`terraform output mon_public_ip`, ports
9090 and 3000) accept connections only from `my_ip`. There is no Alertmanager in this
setup, so alerts are only visible on the Prometheus `/alerts` page.

Failure test, from `lab8/ansible`:

```bash
date -Is; ansible web1 -b -m service -a "name=nginx state=stopped"
while true; do date -Is; curl -s -m 2 -o /dev/null -w '%{http_code}\n' http://$ALB; sleep 2; done | tee test.log
date -Is; ansible web1 -b -m service -a "name=nginx state=started"
```

Read the times you need from Prometheus **before** destroying: its data disappears with the instance.

```bash
cd ..
terraform destroy
```

Then check the AWS console (instances, load balancers, volumes, VPCs) and the cost the next
day, since billing data arrives with a delay of about a day.

### VPS (lab9)

`lab9/vps/` holds copies of the files in the VPS monitoring directory, but the tunnel,
firewall and SSH hardening it depends on are not in this repo (see below), so it cannot be
rebuilt from the repo alone. To reuse it: copy `lab9/vps/` to the VPS, create
`alertmanager.yml` from the example, put the token in `~/.secrets/`, adjust the probe target,
and run `docker compose up -d`. Every service listens on loopback only.

## Described in the notebook but not in the repo

These items appear in `notes/sre-lab-notatnik.md` but have no files in this repository.

Kept outside on purpose:

- The CD deploy script `~/deploy/pull-deploy.sh`, its cron entry (every 5 minutes with `flock`), `deploy.log`, `last_sha` and the `.previous/` rollback copy. The script is not versioned so that a commit cannot change code running on the server.
- The real VPS `alertmanager.yml`, the `~/.secrets/` directory and all tokens, keys, `terraform.tfvars` and Terraform state.
- Evidence files from the tests (`~/testA-*.txt`, `~/testB-*.txt`, test loop logs) and the Prometheus data used to rebuild the timelines.

Not committed (yet):

- Grafana: the imported Node Exporter Full dashboard (ID 1860), the `Web SLO` dashboard and the data source settings.
- Kubernetes: the kind cluster and nginx test deployment from Dział 1 (no manifests).
- Host setup from Dział 0–2: dual boot, the SSH client config, the Docker DNS fix in `/etc/docker/daemon.json`, DHCP reservations and `virsh autostart` for `web1`, `web2` and `db1` (only `lb1` gets them, in `create-lb.sh`).
- VPS setup from Dział 11: WireGuard config (`wg0`), `ufw` rules on the VPS and the home PC, SSH hardening (`sshd_config.d/00-hardening.conf`), fail2ban, unattended-upgrades, swap and the cron entry for `aws-cost.sh`.
- AWS account setup done in the console: IAM users (Terraform user, cost reader), MFA and the cost budget.
- A `.gitignore` entry for the VPS `alertmanager.yml`. The notebook says it is gitignored; `.gitignore` has no such rule (the file itself has not been committed).

Planned in the notebook, not done yet:

- Test D2: reload instead of recreate after rollback, to prove or disprove the false-alert hypothesis.
- Repeating the VPS test with `evaluation_interval: 15s`, a dead man's switch, a tunnel-down test and a night-time test of the `hour()` window.
- Telegram notifications from the deploy script on rollback and rejection.
- Alertmanager in AWS, a narrower IAM policy for Terraform, remote Terraform state in S3, restic backups to S3, a hardening playbook in `lab9/`.
- Kubernetes beyond the kind test.
