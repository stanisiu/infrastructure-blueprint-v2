# 🌐 enterprise-vpn-sec-v2
> **Enterprise Hybrid Cloud Network & Security Infrastructure**  
> Automated deployment of a safe, scalable Zero Trust architecture between On-Premises and Azure using Terraform (IaC).

---

## 📌 Project Summary
* Built a high-availability hybrid cloud infrastructure connecting an on-premises data center with Microsoft Azure.
* Established a Zero Trust security posture through strict network segregation and NSG-based least-privilege access controls.
* Created a robust hub network foundation integrating Azure Private DNS Resolver to support seamless bidirectional name resolution across hybrid environments.

---

## 🏗️ Architecture Overview & Components

This project is declaratively managed via Terraform, provisioning 17 core infrastructure resources within a central hub network (`10.0.0.0/16`):

* **Core Network (`vnet-hub-prod`):** VNet (`10.0.0.0/16`) split into 4 purpose-driven subnets:
  * `GatewaySubnet`: Dedicated subnet for Virtual Network Gateway.
  * `snet-applications`: Dedicated subnet for core application workloads.
  * `snet-aks-cluster`: Dedicated address range reserved for future container cluster expansion.
  * `snet-dns-resolver-inbound`: Exclusively allocated for Private DNS Resolver inbound endpoints.
* **Hybrid Connectivity (`vpngw-hub-prod` & `lng-onprem`):** Zone-redundant SKU (`VpnGw1AZ`) Virtual Network Gateway paired with Local Network Gateway and BGP dynamic routing.
* **Security & Governance (`nsg-app-subnet`):** Hierarchical NSG inbound/outbound rules and public-access-blocked diagnostic Storage Accounts.
* **Hybrid DNS (`dns-resolver-hub`):** Inbound endpoint (`10.0.4.4`) enabling conditional forwarding and bidirectional FQDN resolution.
* **Observability (`law-vpn-diagnostics`):** Integrated Log Analytics Workspace collecting network flow logs and diagnostic telemetry.

---

## 🖼️ Core Infrastructure Verification & Evidence

This section demonstrates the actual deployment state and security configurations verified directly from the Azure Portal and Terraform CLI.

### 1. Resource Group Inventory (`rg-enterprise-vpn-sec-v2`)
Verification of 10 core infrastructure resources declaratively provisioned in `Japan East`:

| Resource Name | Resource Type | Description |
| :--- | :--- | :--- |
| `vnet-core-network` | Virtual Network | Core Hub VNet (`10.0.0.0/16`) hosting 4 isolated subnets |
| `vng-core-vpn` | Virtual Network Gateway | High-availability VPN Gateway (`VpnGw1AZ` SKU) |
| `lng-onprem-datacenter` | Local Network Gateway | On-premises router representation (`192.168.0.0/16`) |
| `conn-azure-to-onprem` | Connection | Site-to-Site IPsec/IKE encrypted VPN connection |
| `dnspr-core-network` | Private DNS Resolver | Hybrid DNS endpoint (`10.0.4.4`) for inbound forwarding |
| `nsg-app-subnet` | Network Security Group | Least-privilege ACLs attached to `snet-applications` |
| `law-vpn-diagnostics` | Log Analytics Workspace | Centralized diagnostic logging & telemetry hub |
| `stvpnflowlogs...` | Storage Account | NSG Flow Logs storage with default public access disabled |

<br>

<details>
<summary><b>🔍 View Resource Group Screenshot</b></summary>
<br>

<img src="./images/rg-overview.png" width="850" alt="Resource Group Overview">

</details>

---

### 2. Infrastructure as Code (Terraform Provisioning & Outputs)
Successful execution of Terraform (`Apply complete!`) returning core attributes for downstream Spoke VNet integration:

<img src="./images/terraform-output.png" width="850" alt="Terraform Apply Output">

* **Inbound DNS Resolver IP**: `10.0.4.4`
* **VPN Gateway BGP Peer IP**: `10.0.254.30`
* **Hub VNet Address Space**: `10.0.0.0/16`
* **On-Premises Address Space**: `192.168.0.0/16`

---

### 3. IPsec/IKE Custom Encryption Policy (`conn-azure-to-onprem`)
Strict custom IPsec/IKE policies enforced over IKEv2 to secure public internet transit:

| Parameter | Configuration | Value |
| :--- | :--- | :--- |
| **IKE Phase 1** | Encryption / Integrity / DH Group | `AES256` / `SHA256` / `DHGroup14` |
| **IKE Phase 2 (IPsec)** | Encryption / Integrity / PFS Group | `AES256` / `SHA256` / `PFS2048` |
| **SA Lifetime & DPD** | SA Lifetime / DPD Timeout | `27000 sec` / `45 sec` |
| **Routing & Protocol** | BGP Status / Protocol | `Enabled` / `IKEv2` |

<br>

<details>
<summary><b>🔍 View Connection Policy Screenshot</b></summary>
<br>

<img src="./images/ipsec-policy.png" width="850" alt="IPsec Policy">

</details>

---

### 4. Zero Trust Network Access Control (`nsg-app-subnet`)
Strict inbound/outbound traffic filter rules applied to `snet-applications` (`10.0.1.0/24`):

| Priority | Name | Port | Protocol | Source | Destination | Action | Purpose |
| :---: | :--- | :---: | :---: | :---: | :---: | :---: | :--- |
| **100** | `Allow_SSH_From_OnPrem_Mgmt` | `22` | `TCP` | `192.168.1.0/24` | `Any` | **Allow** | Restricted SSH management from On-Prem |
| **200** | `Allow_VNet_Internal` | `Any` | `Any` | `10.0.0.0/16` | `Any` | **Allow** | Internal VNet intra-communication |
| **4096** | `Deny_All_Inbound` | `Any` | `Any` | `Any` | `Any` | **Deny** | Explicit Default Deny All |

<br>

<details>
<summary><b>🔍 View NSG Rules Screenshot</b></summary>
<br>

<img src="./images/nsg-rules.png" width="850" alt="NSG Rules">

</details>

---

### 5. Subnet Segregation & VNet Topology (`vnet-core-network`)
Core VNet (`10.0.0.0/16`) divided into 4 purpose-driven subnets:

* **`snet-applications`**: `10.0.1.0/24` (Bound to `nsg-app-subnet`)
* **`snet-dns-resolver-inbound`**: `10.0.4.0/28` (Allocated for DNS Inbound Endpoint)
* **`snet-aks-cluster`**: `10.0.8.0/22` (Reserved for AKS cluster)
* **`GatewaySubnet`**: `10.0.254.0/27` (Dedicated for `vng-core-vpn`)

<br>

<details>
<summary><b>🔍 View Topology & Subnet Screenshots</b></summary>
<br>

| VNet Topology | Subnet Details |
| :---: | :---: |
| <img src="./images/vnet-topology.png" width="400"> | <img src="./images/vnet-subnets.png" width="400"> |

</details>

---

## 🚀 Key Implementation Features

### 1. Design Phase
* **Enterprise Hybrid Network Topology:** Designed core VNet address space allocation and subnet segregation strategies.
* **Zero Trust Architecture:** Established least-privilege access policies via NSGs and public-access-restricted storage design.
* **IaC Standardization & Scalability:** Designed `outputs.tf` exposing VNet ID, Subnet IDs, and DNS Resolver IP for Spoke module integration via `terraform_remote_state`.
* **Hybrid Routing & DNS Strategy:** Defined BGP-based dynamic routing protocols and Private DNS Resolver conditional forwarding architecture.

### 2. Implementation Phase
* **Automated Provisioning with Terraform:** Managed full infrastructure lifecycle (create, update, destroy) using AzureRM Provider v5.1.0.
* **Zone-Redundant VPN Tunnel:** Integrated `VpnGw1AZ` gateway and Local Network Gateway with strict custom encryption policies.
* **Network Security & Hardening:** Enforced explicit deny rules on application subnets and set storage account default network access to `Deny`.
* **Bidirectional FQDN Name Resolution:** Assigned dedicated IP (`10.0.4.4`) in `snet-dns-resolver-inbound` for Azure–on-premises conditional DNS forwarding.

---

## 🚨 Troubleshooting & Issue Resolution

### ① Cloud Subscription Quota & SKU Restriction (`SkuNotAvailable`)
* **Issue:** `SkuNotAvailable` error occurred during `terraform apply` when deploying `VpnGw1AZ` for zone-redundant high availability.
* **Root Cause:** Exceeded regional subscription limits for public IPs and specific gateway SKUs.
* **Resolution / Workaround:** Temporarily defaulted to standard SKU (`VpnGw1`) to validate core network topology first. Parameterized the SKU in `variables.tf` to allow seamless production upgrades while minimizing technical debt.

### ② IPsec Tunnel IKE Negotiation Failure (`Phase 1 Negotiation Failure`)
* **Issue:** Connection status remained disconnected with packet drops after VPN Gateway deployment.
* **Root Cause:** Mismatch in DH Group and integrity hash algorithms between Azure default settings and the simulated on-premises router.
* **Resolution:** Analyzed IKE diagnostic logs in Log Analytics Workspace to pinpoint failure locations. Configured explicit custom IPsec policies (`AES256`, `SHA256`, `DHGroup14`, `PFS2048`) on both ends to successfully establish the tunnel.

### ③ Terraform Implicit Dependency Deadlock
* **Issue:** DNS Resolver inbound endpoint attempted deployment before subnet creation was complete, leading to deployment failure.
* **Root Cause:** Parallel execution engine attempted simultaneous resource provisioning without explicit dependency tracking.
* **Resolution:** Enforced explicit attribute references (`azurerm_subnet.snet_dns_resolver_inbound.id`) and added `depends_on` blocks where sequential provisioning was mandatory.

---

## 🚧 Unimplemented Features & Roadmap

* **Physical On-Premises Firewall Integration:** Currently simulated via `Local Network Gateway`. Future work includes physical hardware integration (e.g., Cisco/Fortinet) and Active-Active redundant routing testing.
* **Multi-Region Spoke Network Expansion:** Currently centered around a single Hub. Future plans involve automated peering with multiple Spoke VNets and integration with Azure Virtual WAN.
* **GitOps CI/CD Pipeline Construction:** Currently executed via local CLI. Future plans include GitHub Actions integration for automated PR `terraform plan` and main branch `apply` workflows.

---

## 🧰 Tech Stack
* **Cloud Platform:** Microsoft Azure (VNet, VPN Gateway, Private DNS Resolver, Log Analytics, NSG, Storage Account)
* **IaC (Infrastructure as Code):** Terraform (HCL, AzureRM Provider v5.1.0)
* **Protocols & Security:** IPsec/IKEv2, BGP, Zero Trust Architecture

---

❗We no longer provide this feature.
## 📂 Repository Structure
```text
enterprise-vpn-sec-v2/
├── modules/           # Network, VPN, DNS, and Security Group modules
├── main.tf            # Root infrastructure configuration
├── variables.tf       # Input variables definition
├── outputs.tf         # Output variables for downstream Spoke integration
└── README.md          # Project documentation

# 1. Clone the repository
git clone [https://github.com/your-username/enterprise-vpn-sec-v2.git](https://github.com/your-username/enterprise-vpn-sec-v2.git)
cd enterprise-vpn-sec-v2

# 2. Initialize Terraform
terraform init

# 3. Preview execution plan
terraform plan

# 4. Provision infrastructure
terraform apply
*
