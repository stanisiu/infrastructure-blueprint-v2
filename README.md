# 🌐 Infrastructure Blueprint v2

> **Azure Hybrid Cloud Network & Security Infrastructure**  
> Terraform-based deployment of a hybrid Azure network architecture applying Zero Trust network security principles.

---

## 📌 Project Overview

This project demonstrates the design, deployment, and validation of a **hybrid Azure network infrastructure** connecting a simulated on-premises environment with Microsoft Azure.

The infrastructure is declaratively managed using **Terraform** and focuses on hybrid connectivity, network segmentation, secure routing, DNS integration, observability, and infrastructure automation.

### Key Objectives

- Build a hybrid Azure network using Site-to-Site VPN connectivity
- Implement dynamic routing using BGP
- Apply network segmentation and least-privilege access controls
- Configure custom IPsec/IKEv2 encryption policies
- Integrate Azure Private DNS Resolver for hybrid name resolution
- Manage infrastructure declaratively using Terraform
- Centralize network diagnostics using Azure Log Analytics
- Validate deployment and troubleshoot infrastructure failures

> **Project Focus:** Azure Networking · Terraform IaC · Hybrid Connectivity · Network Security · DNS · Observability

---

# 🏗️ Architecture Overview

The infrastructure is built around a central Azure VNet:

```text
vnet-core-network
10.0.0.0/16
```

The VNet is divided into dedicated subnets for gateway, application, DNS, and future container workloads.

```text
                 Simulated On-Premises
                   192.168.0.0/16
                          │
                          │
                    IPsec / IKEv2
                          │
                          │ BGP
                          ▼
               Azure VPN Gateway
                  (VpnGw1AZ)
                          │
                          ▼
              vnet-core-network
                 10.0.0.0/16
                          │
          ┌───────────────┼───────────────┐
          │               │               │
          ▼               ▼               ▼
   Applications       DNS Resolver      AKS Reserved
   10.0.1.0/24        10.0.4.0/28      10.0.8.0/22
          │               │
          ▼               ▼
         NSG        Private DNS Resolver
                       10.0.4.4
```

---

# ☁️ Core Infrastructure Components

The infrastructure is managed through Terraform and includes the following core components.

### Core Network

**`vnet-core-network`**

Address space:

```text
10.0.0.0/16
```

The VNet is divided into four purpose-driven subnets:

| Subnet | Address Range | Purpose |
|---|---|---|
| `GatewaySubnet` | `10.0.254.0/27` | Azure VPN Gateway |
| `snet-applications` | `10.0.1.0/24` | Application workloads |
| `snet-dns-resolver-inbound` | `10.0.4.0/28` | Private DNS Resolver inbound endpoint |
| `snet-aks-cluster` | `10.0.8.0/22` | Reserved for future AKS workloads |

---

## Hybrid Connectivity

Hybrid connectivity is implemented using:

- Azure Virtual Network Gateway
- Local Network Gateway
- Site-to-Site VPN
- IPsec/IKEv2
- BGP dynamic routing

The Azure VPN Gateway uses the `VpnGw1AZ` SKU to provide zone-redundant gateway capability.

The Local Network Gateway represents the simulated on-premises network:

```text
192.168.0.0/16
```

> **Scope:** The on-premises side is simulated through Azure Local Network Gateway configuration. Physical firewall/router integration is not part of the current implementation.

---

## Network Security

Network security controls are implemented through:

- Network Security Groups
- Subnet-level segmentation
- Least-privilege inbound rules
- Explicit deny rules
- Restricted public access
- Private network communication

These controls apply **Zero Trust network security principles** by limiting network paths and explicitly defining permitted communication.

---

## Hybrid DNS

Azure Private DNS Resolver provides inbound DNS resolution for the hybrid network.

Inbound endpoint:

```text
10.0.4.4
```

The DNS architecture is designed to support conditional forwarding and hybrid name resolution between Azure and the simulated on-premises environment.

---

## Observability

Azure Log Analytics Workspace is integrated to collect infrastructure diagnostics and network telemetry.

The environment uses:

- Azure Log Analytics
- VPN diagnostic logs
- Network telemetry
- Infrastructure troubleshooting data

These logs were also used during IPsec/IKE troubleshooting to identify tunnel negotiation failures.

---

# 🖼️ Infrastructure Verification & Evidence

This section documents the actual deployment state and configurations verified through the Azure Portal and Terraform CLI.

## 1. Resource Group Inventory

Resource Group:

```text
rg-enterprise-vpn-sec-v2
```

Core infrastructure resources were provisioned in **Japan East**.

| Resource Name | Resource Type | Description |
|---|---|---|
| `vnet-core-network` | Virtual Network | Core Hub VNet (`10.0.0.0/16`) |
| `vng-core-vpn` | Virtual Network Gateway | VPN Gateway using `VpnGw1AZ` |
| `lng-onprem-datacenter` | Local Network Gateway | Simulated on-premises network (`192.168.0.0/16`) |
| `conn-azure-to-onprem` | VPN Connection | Site-to-Site IPsec/IKE connection |
| `dnspr-core-network` | Private DNS Resolver | Hybrid DNS resolver |
| `nsg-app-subnet` | Network Security Group | Application subnet access controls |
| `law-vpn-diagnostics` | Log Analytics Workspace | Centralized diagnostic logging |
| `stvpnflowlogs...` | Storage Account | Diagnostic storage with restricted public access |

<details>
<summary><b>🔍 View Resource Group Screenshot</b></summary>

<br>

<img src="./images/스크린샷 2026-08-19 104202.png" width="850" alt="Azure Resource Group Overview">

</details>

---

# 🧱 Infrastructure as Code

The infrastructure lifecycle is managed using **Terraform** with the AzureRM provider.

Terraform is used to provision and manage:

- Virtual Network
- Subnets
- Virtual Network Gateway
- Local Network Gateway
- Site-to-Site VPN Connection
- Network Security Group
- Private DNS Resolver
- Log Analytics Workspace
- Diagnostic Storage

## Terraform Deployment Evidence

Successful Terraform deployment:

<img src="./images/스크린샷 2026-08-19 104351.png" width="850" alt="Terraform Apply Output">

Key Terraform outputs include:

```text
Inbound DNS Resolver IP : 10.0.4.4
VPN Gateway BGP Peer IP : 10.0.254.30
Hub VNet Address Space  : 10.0.0.0/16
On-Premises Network     : 192.168.0.0/16
```

Terraform outputs expose infrastructure attributes that can be reused by downstream network components and future Spoke integrations.

---

# 🔐 IPsec / IKEv2 Configuration

A custom IPsec/IKE policy was configured for the Site-to-Site VPN connection.

| Phase | Parameter | Value |
|---|---|---|
| IKE Phase 1 | Encryption | `AES256` |
| IKE Phase 1 | Integrity | `SHA256` |
| IKE Phase 1 | DH Group | `DHGroup14` |
| IPsec Phase 2 | Encryption | `AES256` |
| IPsec Phase 2 | Integrity | `SHA256` |
| IPsec Phase 2 | PFS Group | `PFS2048` |
| SA | Lifetime | `27000 sec` |
| DPD | Timeout | `45 sec` |
| Routing | BGP | `Enabled` |
| Protocol | VPN | `IKEv2` |

<details>
<summary><b>🔍 View Connection Policy Screenshot</b></summary>

<br>

<img src="./images/스크린샷 2026-08-19 105827.png" width="850" alt="IPsec IKE Policy">

</details>

---

# 🛡️ Network Access Control

Network Security Group rules were applied to the application subnet:

```text
snet-applications
10.0.1.0/24
```

The rules follow least-privilege network access principles.

| Priority | Rule | Port | Protocol | Source | Destination | Action |
|---:|---|---:|---|---|---|---|
| 100 | `Allow_SSH_From_OnPrem_Mgmt` | 22 | TCP | `192.168.1.0/24` | Any | Allow |
| 200 | `Allow_VNet_Internal` | Any | Any | `10.0.0.0/16` | Any | Allow |
| 4096 | `Deny_All_Inbound` | Any | Any | Any | Any | Deny |

This configuration restricts administrative SSH access to the designated management network while explicitly denying unmatched inbound traffic.

<details>
<summary><b>🔍 View NSG Rules Screenshot</b></summary>

<br>

<img src="./images/스크린샷 2026-08-19 105014.png" width="850" alt="NSG Rules">

</details>

---

# 🌐 Network Segmentation

The core VNet uses dedicated subnets to separate infrastructure responsibilities.

| Subnet | CIDR | Role |
|---|---|---|
| `snet-applications` | `10.0.1.0/24` | Application workloads |
| `snet-dns-resolver-inbound` | `10.0.4.0/28` | DNS Resolver inbound endpoint |
| `snet-aks-cluster` | `10.0.8.0/22` | Reserved AKS address space |
| `GatewaySubnet` | `10.0.254.0/27` | VPN Gateway |

<details>
<summary><b>🔍 View Network Topology</b></summary>

<br>

| VNet Topology | Subnet Details |
|---|---|
| <img src="./images/스크린샷 2026-08-19 110043.png" width="400"> | <img src="./images/스크린샷 2026-08-19 104554.png" width="400"> |

</details>

---

# 🚀 Key Engineering Features

## 1. Hybrid Network Design

Designed the Azure VNet address space and subnet segmentation strategy for gateway, application, DNS, and future container workloads.

## 2. Terraform Infrastructure Automation

Infrastructure resources are declaratively managed using Terraform.

The configuration supports repeatable:

```text
Create → Modify → Validate → Destroy
```

infrastructure lifecycle operations.

## 3. Hybrid Routing

BGP was enabled to support dynamic route exchange between Azure and the simulated on-premises network.

## 4. Network Security

Zero Trust network security principles were applied through:

- Subnet segmentation
- NSG-based least-privilege access
- Explicit inbound deny rules
- Restricted public access
- Controlled administrative access

## 5. Hybrid DNS

Azure Private DNS Resolver was integrated to support hybrid DNS forwarding architecture.

## 6. Infrastructure Observability

Log Analytics was integrated to support VPN diagnostics, network telemetry, and troubleshooting.

---

# 🚨 Troubleshooting & Issue Resolution

## 1. VPN Gateway SKU Availability

### Issue

Terraform returned:

```text
SkuNotAvailable
```

while attempting to deploy the `VpnGw1AZ` gateway.

### Root Cause

Regional subscription limitations affected availability of the requested Public IP and VPN Gateway resources.

### Resolution

A standard `VpnGw1` configuration was temporarily used to validate the network topology.

The VPN Gateway SKU was parameterized through Terraform variables so the configuration could be changed without restructuring the infrastructure code.

---

## 2. IPsec/IKE Negotiation Failure

### Issue

The VPN connection remained disconnected after deployment.

### Root Cause

The IKE/IPsec parameters between Azure and the simulated on-premises endpoint were not aligned.

### Resolution

VPN diagnostic logs were analyzed through Log Analytics.

Explicit encryption parameters were configured:

```text
AES256
SHA256
DHGroup14
PFS2048
IKEv2
```

After aligning the VPN parameters, the tunnel configuration was successfully validated.

---

## 3. Terraform Resource Dependency

### Issue

The Private DNS Resolver inbound endpoint attempted deployment before its required subnet configuration was available.

### Root Cause

Terraform attempted parallel resource provisioning where deployment ordering was required.

### Resolution

Explicit resource references were used:

```hcl
azurerm_subnet.snet_dns_resolver_inbound.id
```

and `depends_on` was added where explicit sequential provisioning was required.

This ensured the DNS Resolver endpoint was created only after its required network resources were available.

---

# 🚧 Current Limitations & Roadmap

The project intentionally separates implemented functionality from future improvements.

### Physical On-Premises Integration

**Current:** Simulated using Azure Local Network Gateway.

**Future:** Integrate physical network equipment such as Cisco or Fortinet and validate redundant routing behavior.

### Multi-Spoke Network Architecture

**Current:** Infrastructure is centered around a single core Hub VNet.

**Future:** Add multiple Spoke VNets, automated VNet peering, and evaluate Azure Virtual WAN integration.

### CI/CD for Terraform

**Current:** Terraform deployment is executed through the local CLI.

**Future:** Integrate GitHub Actions to automatically execute:

```text
Pull Request
     │
     ▼
terraform plan
     │
     ▼
Review / Approval
     │
     ▼
Main Branch
     │
     ▼
terraform apply
```

---

# 🧰 Tech Stack

| Category | Technologies |
|---|---|
| Cloud Platform | Microsoft Azure |
| Networking | VNet, Subnets, VPN Gateway, Local Network Gateway |
| Hybrid Connectivity | Site-to-Site VPN, IPsec/IKEv2, BGP |
| DNS | Azure Private DNS Resolver |
| Security | NSG, Network Segmentation, Least-Privilege Access |
| Observability | Azure Log Analytics |
| Infrastructure as Code | Terraform, HCL, AzureRM Provider |
| Infrastructure Design | Hub Network, Zero-Trust-Oriented Network Architecture |

---

# 📂 Repository Structure

```text
infrastructure-blueprint-v2/
├── .github/
│   └── workflows/
├── azure-pipelines/
├── compute-ask/
├── images/
├── manifests/
├── network-foundation/
└── README.md
```

### Core Directories

- **`network-foundation/`** — Terraform configuration for the core Azure network infrastructure
- **`images/`** — Azure Portal and Terraform deployment evidence
- **`manifests/`** — Infrastructure-related configuration manifests
- **`compute-ask/`** — Compute/AKS-related project resources
- **`.github/workflows/`** — Workflow-related configuration
- **`azure-pipelines/`** — Pipeline-related project files

> Some repository directories represent supporting or experimental work. The validated core infrastructure described in this README is centered around the Terraform network foundation.

---

# 🚀 Deployment

## 1. Clone Repository

```bash
git clone https://github.com/stanisiu/infrastructure-blueprint-v2.git
cd infrastructure-blueprint-v2
```

## 2. Move to the Terraform Network Configuration

```bash
cd network-foundation
```

## 3. Initialize Terraform

```bash
terraform init
```

## 4. Review Infrastructure Changes

```bash
terraform plan
```

## 5. Deploy Infrastructure

```bash
terraform apply
```

> Azure authentication and the required Terraform/Azure CLI environment must be configured before deployment.

---

# 🎯 Project Outcomes

Through this project, the following infrastructure capabilities were implemented and validated:

- Terraform-based Azure infrastructure provisioning
- VNet and subnet segmentation
- Site-to-Site VPN architecture
- IPsec/IKEv2 security configuration
- BGP dynamic routing
- Zone-redundant VPN Gateway capability
- NSG-based least-privilege access controls
- Private DNS Resolver integration
- Hybrid DNS architecture
- Log Analytics-based diagnostics
- Terraform dependency management
- VPN and infrastructure troubleshooting

The project demonstrates practical experience integrating **Azure networking, Terraform infrastructure automation, hybrid connectivity, network security, DNS, and infrastructure troubleshooting**.

---

# 📌 Project Scope

This project is a controlled infrastructure lab focused on **Azure hybrid networking and network security architecture**.

The core engineering flow is:

**Terraform IaC → Network Segmentation → VPN Connectivity → IPsec/IKEv2 → BGP Routing → Network Security → Hybrid DNS → Observability → Troubleshooting**

The on-premises environment is currently simulated rather than connected to physical network hardware, and CI/CD-based Terraform deployment remains part of the future roadmap.
