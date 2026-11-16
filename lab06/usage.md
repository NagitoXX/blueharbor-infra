# Lab 06 - Usage baseline

Recorded on 2026-11-16, before any Terraform apply.

## GitHub Codespaces (Settings > Billing and plans > Usage, Nov 2026)

- Compute 2-core: 0.68 h (about 1.4 of the 120 free core-hours)
- Storage: 0.82 GB-month (of the 15 free)
- Billed: $0 (gross $0.18, covered by the free quota)

## Vercel (team blueharbor-infra, Hobby > Usage, Oct 17 - Nov 16)

- Fast Data Transfer: 0 B
- Fast Origin Transfer: 0 B
- CDN Requests: 0
- Function Invocations: 0
- Function Duration: 0 GB-Hrs
- Build Minutes: 0s

## Supabase (NagitoXX Org, Free Plan > Usage, 09 Nov - 09 Dec 2026)

- Database Size: 0.026 / 0.5 GB (5%)
- Egress: 0 / 5 GB
- Storage Size: 0 / 1 GB
- Monthly Active Users: 0 / 50 000 MAU
- Edge Function Invocations: 0 / 500 000
- Free Plan quota not exceeded

## Update 2026-11-16 (Exercise 6.6, after 6.3 to 6.5)

| Platform | Usage today | Free quota |
|---|---|---|
| GitHub Codespaces (Nov 2026) | 1.28 h of 2-core compute (about 2.6 core-hours), 0.83 GB-month storage, $0 billed (gross $0.29) | 120 core-hours and 15 GB-month per month [a] |
| Vercel (team blueharbor-infra, Hobby, Oct 17 - Nov 16) | 26 CDN requests, 15 function invocations, 14.98 kB Fast Origin Transfer | 1M requests, 1M invocations, 10 GB origin transfer [b] |
| Supabase (Free plan, 09 Nov - 09 Dec) | Database 0.027 / 0.5 GB (5%), egress 0 / 5 GB, 0 MAU | 2 active projects, 500 MB per DB, 5 GB egress [c] |

## What 100 times more traffic would change

100 x today is still only about 2,600 requests and 1,500 invocations a month: volume alone would stay inside the free quotas. What forces a paid plan for a real company is not the volume but the limits of the free plans:

| Platform | Plan needed | Why | Price per month [source] |
|---|---|---|---|
| Vercel | Pro, 1 developer seat | Hobby has hard caps and no extra usage can be bought, 1 hour of runtime logs, no team access [b] | $20 per seat, includes $20 of usage credit [d] |
| Supabase | Pro | Free projects pause after 1 week idle (TrackIt would go down), 500 MB limit, no paid backups [c] | from $25, includes 8 GB disk, 250 GB egress, $10 compute credit [c] |
| GitHub Codespaces | Free quota still enough | About 2.6 core-hours used out of 120 | $0.18 per hour of 2-core beyond the quota [a] |
| **Total** | | | **about $45 per month (excluding VAT)** |

Watch: Supabase overage is $0.125 per GB of disk and $0.09 per GB of egress beyond the Pro quota [c]; Vercel function invocations beyond the credit cost $0.60 per million [e].

Sources (accessed 2026-11-16):
- [a] https://docs.github.com/en/billing/concepts/product-billing/github-codespaces
- [b] https://vercel.com/docs/plans/hobby
- [c] https://supabase.com/pricing
- [d] https://vercel.com/pricing
- [e] https://vercel.com/docs/limits/fair-use-guidelines
