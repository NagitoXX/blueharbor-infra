# Lab 06 - Provider comparison

All facts checked on **2026-11-16** on the URLs given in the Sources section (numbers in brackets).

## Providers compared

| Provider | Type | Head office / law |
|---|---|---|
| Vercel | Developer platform (PaaS web) | Vercel Inc., USA; certified under the EU-U.S. Data Privacy Framework [1] |
| Supabase | Developer platform (DBaaS) | Supabase Inc., Delaware, USA; databases hosted on AWS [6] |
| Microsoft Azure | US hyperscaler | Microsoft, USA |
| OVHcloud | European provider | OVHcloud, Roubaix, France [11] |

## Facts per criterion

| Criterion | Vercel | Supabase | Azure | OVHcloud |
|---|---|---|---|---|
| VM | No | No | Yes, Virtual Machines [9] | Yes, Public Cloud instances [12] |
| PaaS web | Yes, core product [2] | No (Edge Functions only) | Yes, App Service [9] | Partial (web hosting, Kubernetes) |
| Managed Postgres | No (through marketplace) | Yes, core product [4] | Yes, Database for PostgreSQL Flexible Server [9] | Yes, Public Cloud Databases [13] |
| Object storage | Yes, Blob [3] | Yes, Storage [4] | Yes, Blob Storage [9] | Yes, Object Storage [13] |
| Managed Kubernetes | No | No | Yes, AKS (cluster management free) [9] | Yes, MKS (free control plane on the Free plan) [12] |
| Region in France / EU | Paris `cdg1` available, but functions default to `iad1` (Washington) [2] | Paris `eu-west-3`, plus Ireland, Frankfurt, Stockholm [5] | France Central and France South [10] | Paris 3-AZ region; Roubaix, Gravelines, Strasbourg [11][14] |
| Free offer for learners | Hobby plan, $0, hard caps (100 GB transfer, 1M invocations) [3] | Free plan, $0: 2 projects, 500 MB DB, paused after 1 week idle [4] | Azure for Students: $100 for 12 months, **no credit card** [8] | $200 voucher for 1 month, **payment method required** [15] |
| Jurisdiction | US law | US law, AWS sub-processor, FISA 702 applicable [6] | US law (CLOUD Act); standard regions not SecNumCloud [16] | French / EU law |
| Verifiable certifications | ISO 27001:2022, SOC 2 Type 2 [1] | SOC 2 Type 2 [7], ISO 27001 (April 2026) [7b] | ISO 27001:2022, HDS on France Central/South [10] | ISO 27001:2022, 27017, 27018, 27701 [17]; SecNumCloud-qualified private cloud offers [11] |
| Terraform provider | `vercel/vercel` (used in 6.4) | `supabase/supabase` (used in 6.5) | `hashicorp/azurerm` | `ovh/ovh` and OpenStack [18] |

## Weighted matrix

Scores from 1 (poor) to 5 (best). Weighted score = sum(weight x score) / 5, out of 100.

| Criterion | Weight | Vercel | Supabase | Azure | OVHcloud |
|---|---|---|---|---|---|
| Services BlueHarbor needs | 25 | 2 | 2 | 5 | 4 |
| Region in France / EU | 15 | 3 | 4 | 5 | 5 |
| Free offer for learners, no card | 15 | 4 | 4 | 5 | 2 |
| Jurisdiction | 15 | 2 | 2 | 2 | 5 |
| Certifications | 15 | 3 | 3 | 4 | 5 |
| Terraform provider | 15 | 5 | 4 | 5 | 5 |
| **Total / 100** | 100 | **61** | **61** | **88** | **86** |

Why these weights: services count most because one provider covering VM, Postgres, storage and Kubernetes means fewer contracts and fewer tokens. Jurisdiction and certifications matter because TrackIt holds customer data (GDPR).

## Recommendation

1. Keep Vercel + Supabase for TrackIt now: free, already automated with Terraform, both can run in Paris.
2. Pin the Vercel functions to `cdg1` (Paris): today they run in Washington by default while the database is in Paris.
3. For the full BlueHarbor platform (VMs, backups, Kubernetes), Azure covers everything and is free for students without a card: best choice for the labs.
4. For production data that must stay under EU law (customers, finance), OVHcloud scores almost as high and adds French jurisdiction and SecNumCloud options.
5. Decision: Azure for learning, OVHcloud as the target for sensitive workloads, and review this matrix once a year.

## Sources (accessed 2026-11-16)

- [1] Vercel Security & Compliance: https://vercel.com/docs/security/compliance
- [2] Vercel regions: https://vercel.com/docs/regions
- [3] Vercel Hobby plan: https://vercel.com/docs/plans/hobby ; pricing: https://vercel.com/pricing
- [4] Supabase pricing: https://supabase.com/pricing
- [5] Supabase regions: https://supabase.com/docs/guides/platform/regions
- [6] Supabase Transfer Impact Assessment: https://supabase.com/downloads/docs/Supabase%2BTIA%2B250314.pdf
- [7] Supabase SOC 2: https://supabase.com/docs/guides/security/soc-2-compliance
- [7b] Supabase ISO 27001: https://supabase.com/blog/supabase-is-now-iso-27001-certified
- [8] Azure for Students: https://azure.microsoft.com/en-us/free/students
- [9] Azure free services: https://azure.microsoft.com/en-gb/pricing/free-services/
- [10] Azure HDS France: https://learn.microsoft.com/en-us/compliance/regulatory/offering-hds-france
- [11] OVHcloud SecNumCloud offers: https://ovhcloud.com/en/enterprise/products/hosted-private-cloud/secnumcloud-qualified ; Paris 3-AZ: https://corporate.ovhcloud.com/en/newsroom/news/ovhcloud-managed-kubernetes-service-standard-3az/
- [12] OVHcloud Managed Kubernetes: https://ovhcloud.com/en-gb/public-cloud/kubernetes
- [13] OVHcloud PostgreSQL: https://www.ovhcloud.com/en-gb/public-cloud/free-postgresql-hosting/
- [14] OVHcloud regions: https://www.ovhcloud.com/en-gb/public-cloud/regions-availability/
- [15] OVHcloud free trial: https://www.ovhcloud.com/en/lp/cloud-native-free-trial/
- [16] Azure SecNumCloud status (Microsoft Q&A, community answer, to confirm on ANSSI list): https://learn.microsoft.com/answers/a/12392505
- [17] OVHcloud certifications: https://docs.ovhcloud.com/en/guides/account-and-service-management/account-information/security-certifications
- [18] OVHcloud and Terraform: https://docs.ovhcloud.com/en/guides/manage-and-operate/terraform/at-ovhcloud
