# Orchestrate a rolling update (Exercise 7.3)

Done on 17/11/2026 from WEB01 as `opsadmin`.

- Playbook: [ansible/rolling.yml](../ansible/rolling.yml).
- Outputs: [evidence/7.3/](evidence/7.3/).

The template now lives in the role from Exercise 7.2. `rolling.yml` therefore points to `roles/webserver/templates/index.html.j2` instead of `templates/index.html.j2`. Everything else is the workbook's playbook.

## How the playbook works

| Setting / task | Effect |
|----------------|--------|
| `serial: 1` | The play runs on **one host at a time**: web01 does all its tasks, then web02. Each batch appears as its own `PLAY [...]` block in the output. |
| `max_fail_percentage: 0` | If any host of a batch fails, **no later batch starts**. |
| `Deploy the new version` | Writes the page with the new `trackit_version`. |
| `Health check from the control node` | `uri` on `http://<host>/`, run **from WEB01** (`delegate_to: localhost`, `become: false`), the way a user or load balancer would see it. |
| `Verify the version is served` | `assert` that the page really contains `version <new version>`. |

## Runs

| UTC | Run | web01 (batch 1) | web02 (batch 2) | Evidence |
|-----|-----|-----------------|-----------------|----------|
| 09:58:31 | `ansible-playbook rolling.yml -K` (1.1.0) | changed=1, health ✔, assert ✔ | changed=1, health ✔, assert ✔ | `s1-v110.txt` |
| 09:58:54 | 1st failure attempt: `ssh web02 sudo systemctl stop nginx` | - | **did not run**: `Could not resolve hostname web02` (no DNS for that name), so nginx kept running | (log overwritten by the second attempt; error quoted here) |
| 09:58:54 | `-e trackit_version=1.2.0` | changed=1 ✔ | changed=1 ✔ (nginx was still up) | `s3-v120-nofailure.txt`, `s5-v120-rerun.txt` |
| | Fix: `Host web02 → HostName 10.10.20.21` added to opsadmin's `~/.ssh/config` on WEB01 | | | |
| 10:00:29 | `ssh -t web02 sudo systemctl stop nginx` | - | nginx `inactive` | `s2-stop.txt` |
| 10:00:52 | `-e trackit_version=1.3.0` (both hosts were already on 1.2.0) | **changed=1, health ✔, assert ✔** | changed=1, then **health check FAILED**: `Status code was -1 ... [Errno 111] Connection refused` → `NO MORE HOSTS LEFT`, exit code 2 | `s3-v130-fail.txt` |
| 10:01:18 | `ssh -t web02 sudo systemctl start nginx` | - | nginx `active` | `s4-start.txt` |
| 10:01:29 | `-e trackit_version=1.3.0` again | ok, changed=0 | ok, changed=0, health ✔, assert ✔ | `s5-v130-retry.txt` |

Final state: `curl` on both hosts → `version 1.3.0` (`pages-after.txt`).

What the failed run shows:

- **One host per batch.** Each run prints two `PLAY [Rolling update of the status page]` blocks, one per host.
- **WEB01 first.** WEB01 was updated, checked and verified before WEB02 was touched.
- **The run stops at WEB02.**
  - The health check failed, so the `assert` never ran: the request was refused before there was any content to check. Here the failing step is the `uri` task, not the assertion the workbook mentions.
  - Ansible printed `NO MORE HOSTS LEFT` and ended with exit code 2.
  - With more web servers, `max_fail_percentage: 0` is what keeps the next batches from starting. The rollout stops while most of the fleet still serves the previous version.
- **The new file was already written on WEB02** (`changed=1` before the failed check). Writing the file is not the problem: the check proves whether the service works. That is why the retry after restarting nginx showed `changed=0` and the checks passed.

## Configuration management versus orchestration

| | Configuration management (7.2, `web.yml`) | Orchestration (7.3, `rolling.yml`) |
|---|---|---|
| **Question answered** | *What state must each server be in?* | *In what order, and under what conditions, does a change go through the fleet?* |
| **Unit** | One host, independently of the others | The fleet: batches, order, dependencies between hosts |
| **Order between hosts** | Irrelevant: every host is configured in parallel (`forks = 10`) | Central: `serial: 1` makes web02 wait for web01 |
| **Success criterion** | Each resource matches the description (`changed=0` when it already does) | The **service** still works after each step (health check, assert) |
| **On failure** | That host is reported failed; the others still converge | **The whole rollout stops** (`max_fail_percentage: 0`), so a bad version never reaches every server |
| **Runs** | Again and again, to detect and correct drift (idempotent) | Once per release, as a controlled sequence |
| **Typical tools** | Ansible playbooks and roles, Puppet, Chef, Group Policy (Lab 02) | Ansible with `serial` and `delegate_to`, load balancer drain, Kubernetes rolling updates (Lab 09), CI/CD pipelines |

In short:

- **Configuration management makes each server correct.**
- **Orchestration changes many servers without ever breaking the service:**
  - one batch at a time;
  - a check from outside after each step;
  - a stop at the first failure.

For TrackIt behind a load balancer, a full orchestrated release would, for each host in turn:

1. take the host out of the pool;
2. deploy;
3. run the health check;
4. put the host back.

That way, users never land on a server that is being updated.

## Notes

- The first attempt did not fail as planned. The workbook's `ssh web02 ...` assumes that the name `web02` resolves on WEB01, but there is no DNS record or `/etc/hosts` entry for it while DC01 is off.
  - Adding `Host web02` to `~/.ssh/config` fixed it without root.
  - In the long run, WEB02 should get an A record on DC01, like `web01`.
- The commands that change a server (`systemctl stop/start`) used `sudo` with opsadmin's password, typed on the console. The health checks (`delegate_to: localhost`, `become: false`) need no privileges.
