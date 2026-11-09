# Foundations - BlueHarbor's infrastructure journey (Exercise I.1)

## Step 1 · On-premises

### 1. The six layers of the server room and who operates them today

| # | Layer | Who operates it today |
|---|-------|-----------------------|
| 1 | Building and facilities (room, power, cooling, physical access) | BlueHarbor (general services) |
| 2 | Network (one flat LAN shared by PCs, printers and servers) | BlueHarbor IT |
| 3 | Hardware (physical servers, external backup disk) | BlueHarbor IT |
| 4 | Operating systems (Windows Server, domain controller) | BlueHarbor IT; the DC was installed by a contractor and never documented |
| 5 | Applications (directory, files, finance, print, web) | BlueHarbor IT, changes made by hand without records. Exception: Microsoft 365 mailboxes are operated by Microsoft |
| 6 | Data (business data, backups never tested) | BlueHarbor |

BlueHarbor owns and operates every layer, from the building to the data.

### 2. Consequences of owning every layer

- **Advantage:** full control. BlueHarbor decides where the data lives, which versions run and when changes happen, with no dependency on a provider and no recurring subscription.
- **Drawback:** full responsibility and up-front cost. Hardware purchase, power, patching and backups are all BlueHarbor's job. Today this shows: an undocumented DC, manual changes and backups that have never been restored.

## Step 2 · Virtualisation

### 1. Resources really used

Each server has 8 cores and 32 GB of RAM.

| Server | CPU use | Cores used (8 × use) | RAM used |
|--------|---------|----------------------|----------|
| Directory | 8 % | 0.64 | 6 GB |
| Files | 15 % | 1.20 | 10 GB |
| Finance | 20 % | 1.60 | 14 GB |
| Print | 5 % | 0.40 | 3 GB |
| Web | 10 % | 0.80 | 6 GB |
| Backup | 12 % | 0.96 | 8 GB |
| **Total** | | **5.6 cores** | **47 GB** |

The six servers own 48 cores and 192 GB of RAM but use only 5.6 cores (about 12 %) and 47 GB (about 24 %).

### 2. Number of virtualisation hosts

Usable capacity of one host at 70 % maximum:

- CPU: 16 × 0.70 = **11.2 cores**, and 5.6 / 11.2 = 50 % of the limit.
- RAM: 128 × 0.70 = **89.6 GB**, and 47 / 89.6 = 52 % of the limit.

**For capacity, 1 host is enough.**

**I would buy 2 hosts (N+1).** With a single host, a hardware failure or a maintenance reboot stops all six servers. With two hosts, the VMs are spread over both. If one host fails, the other can run everything at about 35 % CPU (5.6 / 16) and 37 % RAM (47 / 128), still under the 70 % limit. The figures are averages, so the margin also absorbs peaks and growth.

### 3. Putting all six servers on the same host

- **Benefit 1:** fewer physical machines, which means lower purchase, power, cooling and floor-space costs.
- **Benefit 2:** easier operations: snapshots before changes, cloning from templates, moving a VM to new hardware.
- **Risk:** the host becomes a single point of failure. If it fails, all six services stop at the same time. A "noisy neighbour" VM can also slow down the others.

## Step 3 · Hypervisor type

| Case | Choice | Justification |
|------|--------|---------------|
| (a) Future production hosts in the server room | **Type 1** (Hyper-V Server, Proxmox VE, ESXi) | Runs directly on the hardware: better performance, smaller attack surface, and data-centre features (clustering, high availability, live migration). |
| (b) My laptop for this course | **Type 2** (VirtualBox) | Runs as an application on my Windows 11 laptop, is free, and lets me keep using the laptop normally while the lab VMs run. |
| (c) Accountant's laptop running one old Windows application | **Type 2** (VirtualBox or VMware Workstation) | One old VM next to the user's normal desktop, simple to install and to back up as a file. A type 1 hypervisor would mean reinstalling the laptop, which is too much for a single application. |

## Step 4 · From on-premises to cloud

After step 2, BlueHarbor has a virtualised data centre: resources are pooled on the hosts, but everything is still requested and done by hand.

**Still missing to be a private cloud:**

- **On-demand self-service:** a portal or catalogue where a team requests a VM without a ticket to IT.
- **Automation and APIs:** provisioning by script or infrastructure as code instead of clicks.
- **Measured service:** usage metering and chargeback per department.
- **Rapid elasticity:** resources that grow and shrink automatically with demand, within the limit of the hosts.

**Gained in a public cloud:**

- Near-unlimited elasticity, so there is no need to buy hardware for peaks.
- Pay-per-use (operating costs instead of up-front hardware purchases).
- Managed services (PaaS, DBaaS, object storage): the provider runs the OS, patching and redundancy.
- Several regions and data centres for availability and off-site copies.
- The provider operates the building, power and hardware layers.

## Step 5 · Deployment model

### 1. Placement of each workload

| Workload | Model | Reason |
|----------|-------|--------|
| Active Directory | On-premises (private) | Users at HQ and WH1 log in and receive GPOs locally, so the directory must stay available and fast even if the Internet link fails. |
| Finance application | On-premises (private) | Sensitive financial data and an application that needs a specific OS version, which does not fit a managed cloud service. |
| TrackIt website | Public cloud (PaaS, Vercel) | Customers reach it from the Internet, traffic varies a lot (Black Friday), and it needs elasticity and HTTPS without managing servers. |
| TrackIt shipment data | Public cloud (DBaaS, Supabase, EU region) | Kept close to the application, with managed backups and row level security. The EU region keeps customer data under GDPR. |
| Off-site backups | Public cloud (object storage, EU region) | Gives the off-site copy of the 3-2-1 rule, physically separate from the server room, cheap and encrypted before upload. |

### 2. Why the result is hybrid

BlueHarbor keeps private workloads on-premises (AD, Finance) and runs others in the public cloud (TrackIt, its data, the backups), so the model is **hybrid**. The two parts must be connected securely: an encrypted link (site-to-site VPN or HTTPS/TLS APIs) for the data flows (backups, shipment updates from the warehouse), and a common identity (AD synchronised or federated with the cloud identity provider).

## Step 6 · Scalability

TrackIt goes from 500 to 5,000 visits per hour for two days.

### 1. Scale up versus scale out

| Criterion | Scale up (2 → 16 vCPU) | Scale out (2 → 8 copies) |
|-----------|------------------------|---------------------------|
| Downtime during the change | Usually yes: the VM must be stopped or restarted to receive more vCPU | None: new copies are added behind the load balancer while the others keep serving |
| Maximum capacity | Limited by the largest machine available (hard ceiling) | Grows with the number of copies; more can be added beyond 8 if needed |
| Cost after the peak | Pay for 16 vCPU until someone scales down again (another restart) | Remove the extra copies, or let autoscaling do it, and pay only for the peak |
| What the application must allow | Nothing special: it simply uses more CPU (more workers) | It must be **stateless**: sessions and cache stored outside the instance (for example Redis), shared data in the database, and a load balancer in front |
| Resilience | Still one machine: if it fails, the site is down | Several copies: losing one does not stop the service |

### 2. Choice

- **Web tier: scale out.** TrackIt is a stateless web application. Adding copies is done without downtime, removed after Black Friday, and also gives redundancy. Vercel and Kubernetes (Lab 09) do this automatically.
- **Database: scale up.** A database is stateful, and spreading writes over several machines is complex. Giving the single database more CPU and RAM (a larger Supabase compute size) is the simple, safe option. Read replicas could be added later if reads become the bottleneck.
