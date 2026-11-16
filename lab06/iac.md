# Lab 06 - Infrastructure as code with Terraform

## Workflow seen in cloud/lab-infra

| Step | Command | What happened |
|---|---|---|
| Init | `terraform init` | Downloads the kreuzwerker/docker provider and writes `.terraform.lock.hcl` |
| Check | `terraform fmt && terraform validate` | Formats the code and checks the syntax |
| Create | `terraform plan` / `apply` | 1 network, 1 image, 2 nginx containers on ports 8080 and 8081 |
| Change | `-var web_count=3` | Plan shows 1 to add, apply creates `bh-web-dev-3` on port 8082 |
| Drift | `docker rm -f bh-web-dev-1` then `plan` | Terraform sees the container is missing and plans to recreate it; apply repairs it |
| Guardrail | `-var env=qa` | Plan fails with "env must be dev, test or prod." before touching anything |
| Destroy | `terraform destroy` | Everything removed, `docker ps` shows no bh-web container |

## Why the state file is in .gitignore

`terraform.tfstate` is Terraform's record of what it created: every resource with all its attributes (IDs, IPs, ports, labels). `terraform show` displays it.

It must not be committed because:

1. **It can contain secrets in plain text.** Any sensitive attribute (database passwords, API keys, connection strings) is stored in clear in the state, even when marked `sensitive` in the code. With the Supabase and Vercel resources coming later, a committed state would leak them in a public repo.
2. **It describes our real infrastructure.** Names, IPs and layout help an attacker map BlueHarbor.
3. **It is generated, not written.** It changes on every apply; versioning it in Git causes merge conflicts and two people can apply from different copies and corrupt it.
4. **The right place is a remote backend with locking** (Terraform Cloud, S3 + DynamoDB, Azure Storage), encrypted and with access control, so only one apply runs at a time.

What goes in Git instead: `main.tf` (the desired state) and `.terraform.lock.hcl` (pins the provider versions so everyone gets the same provider).

`.gitignore` entries:

```
.terraform/
*.tfstate
*.tfstate.*
crash.log
*.tfvars
```
