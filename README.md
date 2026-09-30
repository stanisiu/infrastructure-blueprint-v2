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

## 🖼️ Core Infrastructure Verification Points

| Key Component | Description | Screenshot |
| :--- | :--- | :--- |
| **1. Resource Group Inventory (`rg-enterprise-vpn-sec-v2`)** | Verification of 17 core resources (VNet, VPN Gateway, DNS Resolver, Log Analytics, etc.) declaratively provisioned via Terraform. | <img src="docs/images/rg-inventory.png" width="350" alt="Resource Group Inventory"> |
| **2. Custom IPsec/IKE Security Policy (`conn-azure-to-onprem`)** | Application of `AES256`, `SHA256`, `DHGroup14`, and `PFS2048` across IKE Phase 1/2 for public transit encryption and Perfect Forward Secrecy (PFS). | <img src="docs/images/ipsec-policy.png" width="350" alt="IPsec Policy"> |
| **3. Network Security Group Rules (`nsg-app-subnet`)** | Enforcement of least privilege via **Priority 100** (On-Prem SSH), **Priority 200** (Internal VNet), and **Priority 4096** (Default Deny All). | <img src="docs/images/nsg-rules.png" width="350" alt="NSG Rules"> |

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
