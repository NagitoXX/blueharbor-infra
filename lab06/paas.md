# Lab 06 - TrackIt on PaaS (Vercel)

## What was deployed

- Vercel project `bh-trackit-he` created by Terraform (`cloud/platform/main.tf`): root directory `trackit`, framework preset Flask, linked to `NagitoXX/blueharbor-infra`, production branch `main`.
- Environment variable `APP_VERSION=1.1.0` (production and preview), also managed by Terraform.
- Production: https://bh-trackit-he.vercel.app/health returns `{"status":"ok","version":"1.1.0"}` over HTTPS. The version comes from the environment variable, not from the code default (1.0.1).
- Preview: branch `feature/trackit-heading` built automatically with its own URL, protected by Vercel Authentication.

## What I did not have to do on Vercel

| Task | Lab 03 (VM) / 6.3 (containers) | Vercel (PaaS) |
|---|---|---|
| Operating system | Install, patch and harden the OS | Provider |
| Python runtime and dependencies | Install Python, create a venv, keep it updated | Detected from `requirements.txt`, installed at each build |
| Web server / app server | Install and configure nginx (+ gunicorn) | Provider (serverless functions) |
| TLS certificate | Get, install and renew a certificate | Automatic HTTPS on `*.vercel.app` and custom domains |
| Firewall and open ports | Configure host firewall, publish ports | Provider |
| Scaling | Add VMs or containers by hand (`web_count`) | Automatic, per request |
| Deployment | Copy files or rebuild containers, restart services | `git push` builds and deploys; previews per branch |
| Rollback | Redeploy the previous version by hand | Promote a previous deployment in one click |

## What stays BlueHarbor's job

- The code and its dependencies (vulnerable packages are still our problem).
- Secrets and environment variables, and who can read them.
- Access to the Vercel team and to the GitHub repository (the Vercel GitHub app should only see `blueharbor-infra`).
- Domain and DNS, logs and monitoring of the application.

## Issues met

- Provider `vercel/vercel` v5 uses the attribute form `git_repository = { ... }` and requires `sensitive` on environment variables.
- First deployment returned 404: the framework was not detected. Fixed in Terraform with `framework = "flask"`.
- "Unexpected Identity Change" error on refresh: fixed by setting `team` in the provider block, then re-importing the two resources.
