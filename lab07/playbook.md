# Configure the web tier with a playbook (Exercise 7.2)

Done on 17/11/2026 from WEB01 (control node) as `opsadmin`, against the `web` group (web01, web02).

- Code: [ansible/](../ansible/).
- Run outputs: [evidence/7.2/](evidence/7.2/).

## Files

| File | Role |
|------|------|
| `web.yml` | **Challenge done:** a 3-line play that applies the `webserver` role to the `web` group |
| `roles/webserver/tasks/main.yml` | Installs nginx and prometheus-node-exporter, deploys the status page, opens 9100/tcp to WEB01 only, keeps nginx running |
| `roles/webserver/handlers/main.yml` | `Reload nginx`, only notified when the page changes |
| `roles/webserver/templates/index.html.j2` | The status page: `{{ inventory_hostname }}` and `{{ trackit_version }}` |
| `roles/webserver/defaults/main.yml` | `trackit_version: "1.0.1"`, `node_exporter_allowed_from: 10.10.20.20` |
| `web-flat.yml` | The workbook's original single-file playbook, kept for comparison (template path updated) |

```yaml
# web.yml
- hosts: web
  become: true
  roles: [webserver]
```

## Runs

Every run used `-K`: the sudo password of opsadmin was typed at the `BECOME password:` prompt on the WEB01 console. Ansible never stores it between runs.

| # | Command | web01 | web02 | Evidence |
|---|---------|-------|-------|----------|
| 1 | `ansible-playbook web.yml -K --check --diff` | ok=6 **changed=4** | ok=6 changed=4 | `r1-check.txt` |
| 2 | `ansible-playbook web.yml -K` | ok=6 **changed=4** | ok=6 changed=4 | `r2-run.txt` |
| 3 | `ansible-playbook web.yml -K` (again) | ok=5 **changed=0** | ok=5 **changed=0** | `r3-rerun.txt` |
| 4 | `ansible-playbook web.yml -K -e trackit_version=1.0.1` | ok=6 changed=2 | **failed: Incorrect sudo password** | `r4-v101.txt` |
| 5 | same, retried | ok=5 changed=0 (already 1.0.1) | ok=6 **changed=2** | `r5-v101-retry.txt` |
| 6 | role version: `ansible-playbook web.yml -K` | ok=5 **changed=0** | ok=5 **changed=0** | `r6-role.txt` |

**Run 1, `--check --diff`.** Ansible connected, gathered facts and reported what it *would* change, without changing anything. Four tasks would change:

- install node_exporter;
- write the page;
- add the ufw rule;
- run the handler.

`--diff` printed the new `index.html` line by line (`@@ -0,0 +1,2 @@`). It is a new file: until then nginx only had its default `index.nginx-debian.html`.

**Run 2** applied those four changes.

**Run 3, idempotence.** Every task reports `ok` and nothing changed:

- the packages are already present;
- the page already has the right content (same checksum);
- the ufw rule already exists;
- nginx is already running.

Because no task changed, the handler did not run either. A playbook can therefore be run as often as needed: it only acts when reality has drifted from the code.

**Runs 4 and 5, version change.** Only `Deploy the status page` and the `Reload nginx` handler changed (`changed=2`). The packages, the firewall and the service stayed `ok`. The handler ran because the template task notified it; on the runs where the page did not change, it did not run.

- In run 4, web02 failed at fact gathering: the password was mistyped.
- web01 went through because sudo still had the previous run's authentication cached on that console. Ansible stops a host on its first failure and goes on with the others.
- Run 5 was the same command, and on it web01 had nothing left to do.

**Run 6, role.** The role gives exactly the same state, `changed=0` on both hosts. Its tasks are prefixed `webserver :`.

## Results

| Check | Result |
|-------|--------|
| `curl http://10.10.20.20` | `Host: web01 - version 1.0.1 - managed by Ansible` |
| `curl http://10.10.20.21` | `Host: web02 - version 1.0.1 - managed by Ansible` |
| nginx and prometheus-node-exporter | `active` on both (`ansible web -a "systemctl is-active ..."`) |
| node_exporter from WEB01 | `curl 10.10.20.21:9100/metrics` → 1 556 `node_*` metrics |
| node_exporter from WEB02 | `curl 10.10.20.20:9100/metrics` → timeout: ufw only lets WEB01 in |

**Checkpoint:**

- The second run reports `changed=0` on every host.
- Each page shows its own host name (`inventory_hostname`), from a single template.

## What the exercise shows

- **Declarative, not a script.** Each task describes a state (`state: present`, `started`), not an action. A shell script would reinstall the packages, rewrite the file and restart nginx every time. A playbook only changes what differs.
- **Handlers avoid useless restarts.** nginx was only reloaded when its content changed. A reload, not a restart, keeps the existing connections.
- **One template, many hosts.** Host-specific values come from Ansible variables (`inventory_hostname`) and from the command line (`-e`), so the same code configures WEB01, WEB02 and any future web node.
- **`--check --diff` before every real change**, like `terraform plan`.
- **Roles make the code reusable.** Tasks, handlers, templates and defaults live in one folder with a README, and the play only says which hosts get which role.

## Notes

- **No DNS on the Wi-Fi.** The packages came from the Ubuntu mirrors through the school DNS, set temporarily with `resolvectl` on both servers, because DC01 (normal DNS) was off for lack of host RAM.
- **Rule order.** The ufw rule for 9100/tcp comes after the existing rules, so the default deny still applies to every other source.
