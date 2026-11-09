# BlueHarbor Logistics - Infrastructure dossier

## Architecture

### Target deployment model (v1, from Foundations step 5)

| Workload | Model | Reason |
|----------|-------|--------|
| Active Directory | On-premises (private) | Local logins and GPOs at HQ and WH1, available even without Internet |
| Finance application | On-premises (private) | Sensitive data, needs a specific OS version |
| TrackIt website | Public cloud (PaaS, Vercel) | Internet-facing, variable traffic, needs elasticity |
| TrackIt shipment data | Public cloud (DBaaS, Supabase, EU region) | Managed database close to the app, GDPR (EU region) |
| Off-site backups | Public cloud (object storage, EU region) | Off-site copy of the 3-2-1 rule |

The result is a **hybrid** model: on-premises and public cloud connected by encrypted links (VPN or HTTPS APIs) and a common identity.

## Operations

## Risks
