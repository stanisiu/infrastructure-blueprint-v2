# =====================================================
# 0. 테라폼 프로바이더 및 버전 설정 (v4.0.0 이상 완벽 호환)
# =====================================================
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0.0" 
    }
    azuread = {
      source  = "hashicorp/azuread"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 1.13.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# =====================================================
# 1. 데이터 소스 및 공통 변수(Locals) 중앙 통제
# =====================================================
data "azurerm_resource_group" "vpn_rg" { name = var.workload_rg_name }

locals {
  safe_location           = "japaneast"
  safe_location_no_spaces = "japaneast"

  # IP 대역(CIDR) 하드코딩 제거 및 중앙 관리
  vnet_cidr         = "10.0.0.0/16"
  app_subnet_cidr   = "10.0.1.0/24"
  # IP 대역 겹침 에러 해결을 위해 10.0.8.0/22로 변경 (10.0.8.0 ~ 10.0.11.255)
  aks_subnet_cidr   = "10.0.8.0/22" 
  fw_subnet_cidr    = "10.0.3.0/24"
  dns_subnet_cidr   = "10.0.4.0/28"
  gw_subnet_cidr    = "10.0.254.0/27"
}

data "azurerm_client_config" "current" {}

# =====================================================
# 2. 진단 로깅
# =====================================================
resource "azurerm_log_analytics_workspace" "law" {
  name                = "law-vpn-diagnostics"
  location            = local.safe_location
  resource_group_name = data.azurerm_resource_group.vpn_rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

# =====================================================
# 3. VNet 및 서브넷 생성
# =====================================================
resource "azurerm_virtual_network" "main_vnet" {
  name                = "vnet-core-network"
  location            = local.safe_location
  resource_group_name = data.azurerm_resource_group.vpn_rg.name
  address_space       = [local.vnet_cidr]
  tags                = var.tags
}

resource "azurerm_subnet" "app_subnet" {
  name                 = "snet-applications"
  resource_group_name  = data.azurerm_resource_group.vpn_rg.name
  virtual_network_name = azurerm_virtual_network.main_vnet.name
  address_prefixes     = [local.app_subnet_cidr]

  delegation {
    name = "mdp-delegation"
    service_delegation {
      name    = "Microsoft.DevOpsInfrastructure/pools"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet" "gateway_subnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = data.azurerm_resource_group.vpn_rg.name
  virtual_network_name = azurerm_virtual_network.main_vnet.name
  address_prefixes     = [local.gw_subnet_cidr]
}

resource "azurerm_subnet" "aks_subnet" {
  name                 = "snet-aks-cluster"
  resource_group_name  = data.azurerm_resource_group.vpn_rg.name
  virtual_network_name = azurerm_virtual_network.main_vnet.name
  address_prefixes     = [local.aks_subnet_cidr]
}

resource "azurerm_subnet" "dns_resolver_subnet" {
  name                 = "snet-dns-resolver-inbound"
  resource_group_name  = data.azurerm_resource_group.vpn_rg.name
  virtual_network_name = azurerm_virtual_network.main_vnet.name
  address_prefixes     = [local.dns_subnet_cidr]
  delegation {
    name = "dnsResolverDelegation"
    service_delegation {
      name    = "Microsoft.Network/dnsResolvers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# =====================================================
# 4. VPN 게이트웨이 및 연결
# =====================================================
resource "azurerm_public_ip" "vng_pip" {
  name                = "pip-vpn-gateway-1"
  location            = local.safe_location
  resource_group_name = data.azurerm_resource_group.vpn_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = var.tags
}

resource "azurerm_public_ip" "vng_pip_2" {
  count               = var.enable_active_active ? 1 : 0
  name                = "pip-vpn-gateway-2"
  location            = local.safe_location
  resource_group_name = data.azurerm_resource_group.vpn_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = var.tags
}

resource "azurerm_virtual_network_gateway" "vng" {
  name                = "vng-core-vpn"
  location            = local.safe_location
  resource_group_name = data.azurerm_resource_group.vpn_rg.name
  type                = "Vpn"
  vpn_type            = "RouteBased"
  sku                 = "VpnGw1AZ"
  generation          = "Generation1"
  active_active       = var.enable_active_active
  
  bgp_settings { asn = var.azure_bgp_asn }
  
  ip_configuration {
    name                          = "vng-ip-config-1"
    public_ip_address_id          = azurerm_public_ip.vng_pip.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway_subnet.id
  }
  
  dynamic "ip_configuration" {
    for_each = var.enable_active_active ? [1] : []
    content {
      name                          = "vng-ip-config-2"
      public_ip_address_id          = azurerm_public_ip.vng_pip_2[0].id
      private_ip_address_allocation = "Dynamic"
      subnet_id                     = azurerm_subnet.gateway_subnet.id
    }
  }
  tags = var.tags
}

resource "azurerm_local_network_gateway" "onprem_lng" {
  name                = "lng-onprem-datacenter"
  location            = local.safe_location
  resource_group_name = data.azurerm_resource_group.vpn_rg.name
  gateway_address     = var.onprem_gateway_ip
  address_space       = var.onprem_address_space
  bgp_settings {
    asn                 = var.onprem_bgp_asn
    bgp_peering_address = var.onprem_bgp_peering_ip
  }
  tags = var.tags
}

resource "azurerm_virtual_network_gateway_connection" "vpn_connection" {
  name                       = "conn-azure-to-onprem"
  location                   = local.safe_location
  resource_group_name        = data.azurerm_resource_group.vpn_rg.name
  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.vng.id
  local_network_gateway_id   = azurerm_local_network_gateway.onprem_lng.id
  
  shared_key                 = "MyTemporarySecretKey123!"
  
  ipsec_policy {
    dh_group         = "DHGroup14"
    ike_encryption   = "AES256"
    ike_integrity    = "SHA256"
    ipsec_encryption = "AES256"
    ipsec_integrity  = "SHA256"
    pfs_group        = "PFS2048"
    sa_lifetime      = 27000
  }
  tags = var.tags
}

# =====================================================
# 5. 앱 전용 NSG 및 Flow Log 스토리지
# =====================================================
resource "azurerm_network_security_group" "app_nsg" {
  name                = "nsg-app-subnet"
  location            = local.safe_location
  resource_group_name = data.azurerm_resource_group.vpn_rg.name

  security_rule {
    name                       = "Allow_SSH_From_OnPrem_Mgmt"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefixes    = var.onprem_mgmt_subnet
    destination_address_prefix = "*"
  }
  
  security_rule {
    name                       = "Allow_VNet_Internal"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = local.vnet_cidr 
    destination_address_prefix = "*"
  }
  
  security_rule {
    name                       = "Deny_All_Inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  tags = var.tags
}

resource "azurerm_subnet_network_security_group_association" "app_nsg_assoc" {
  subnet_id                 = azurerm_subnet.app_subnet.id
  network_security_group_id = azurerm_network_security_group.app_nsg.id
}

resource "azurerm_storage_account" "flowlog_sa" {
  name                            = "stvpnflowlogs${substr(md5(data.azurerm_resource_group.vpn_rg.id), 0, 8)}"
  resource_group_name             = data.azurerm_resource_group.vpn_rg.name
  location                        = local.safe_location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  account_kind                    = "StorageV2"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }
  tags = var.tags
}

# =====================================================
# 6. DNS Private Resolver (온프레미스 연동용)
# =====================================================
resource "azurerm_private_dns_resolver" "resolver" {
  name                = "dnspr-core-network"
  resource_group_name = data.azurerm_resource_group.vpn_rg.name
  location            = local.safe_location
  virtual_network_id  = azurerm_virtual_network.main_vnet.id
  tags                = var.tags
}

resource "azurerm_private_dns_resolver_inbound_endpoint" "inbound" {
  name                    = "inbound-endpoint"
  private_dns_resolver_id = azurerm_private_dns_resolver.resolver.id
  location                = local.safe_location
  ip_configurations {
    private_ip_allocation_method = "Static"
    private_ip_address           = "10.0.4.4" 
    subnet_id                    = azurerm_subnet.dns_resolver_subnet.id
  }
  tags = var.tags
}

# =====================================================
# 7. 아웃바운드(Egress) 중앙 통제: Azure Firewall 및 UDR
# =====================================================
resource "azurerm_subnet" "fw_subnet" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = data.azurerm_resource_group.vpn_rg.name
  virtual_network_name = azurerm_virtual_network.main_vnet.name
  address_prefixes     = [local.fw_subnet_cidr]
}

resource "azurerm_public_ip" "fw_pip" {
  name                = "pip-fw-core"
  location            = local.safe_location
  resource_group_name = data.azurerm_resource_group.vpn_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_firewall" "fw" {
  name                = "fw-core-network"
  location            = local.safe_location
  resource_group_name = data.azurerm_resource_group.vpn_rg.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard" 

  ip_configuration {
    name                 = "fw-ip-config"
    subnet_id            = azurerm_subnet.fw_subnet.id
    public_ip_address_id = azurerm_public_ip.fw_pip.id
  }
  tags = var.tags
}

resource "azurerm_route_table" "aks_udr" {
  name                          = "rt-aks-egress"
  location                      = local.safe_location
  resource_group_name           = data.azurerm_resource_group.vpn_rg.name
  bgp_route_propagation_enabled = true

  route {
    name                   = "Route_To_Firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.fw.ip_configuration[0].private_ip_address
  }
  tags = var.tags
}

resource "azurerm_subnet_route_table_association" "aks_udr_assoc" {
  subnet_id      = azurerm_subnet.aks_subnet.id
  route_table_id = azurerm_route_table.aks_udr.id
}

resource "azurerm_subnet_route_table_association" "app_udr_assoc" {
  subnet_id      = azurerm_subnet.app_subnet.id
  route_table_id = azurerm_route_table.aks_udr.id
}

# =====================================================
# 8. Azure Firewall 필수 허용 규칙
# =====================================================
resource "azurerm_firewall_network_rule_collection" "aks_required_net" {
  name                = "aks-required-network-rules"
  azure_firewall_name = azurerm_firewall.fw.name
  resource_group_name = data.azurerm_resource_group.vpn_rg.name
  priority            = 100
  action              = "Allow"

  rule {
    name                  = "Allow_NTP"
    source_addresses      = [local.vnet_cidr, "100.64.0.0/16"] 
    destination_ports     = ["123"]
    destination_addresses = ["*"]
    protocols             = ["UDP"]
  }

  rule {
    name                  = "Allow_Azure_Cloud"
    source_addresses      = [local.vnet_cidr, "100.64.0.0/16"]
    destination_ports     = ["443"]
    destination_addresses = ["AzureCloud"] 
    protocols             = ["TCP"]
  }
}

resource "azurerm_firewall_application_rule_collection" "aks_required_app" {
  name                = "aks-required-app-rules"
  azure_firewall_name = azurerm_firewall.fw.name
  resource_group_name = data.azurerm_resource_group.vpn_rg.name
  priority            = 100
  action              = "Allow"

  rule {
    name             = "Allow_AKS_Core_Dependencies"
    source_addresses = [local.vnet_cidr, "100.64.0.0/16"]
    target_fqdns     = [
      "*.azmk8s.io",
      "mcr.microsoft.com",
      "*.data.mcr.microsoft.com",
      "management.azure.com",
      "login.microsoftonline.com",
      "packages.microsoft.com",
      "acs-mirror.azureedge.net"
    ]
    protocol {
      port = "443"
      type = "Https"
    }
  }

  rule {
    name             = "Allow_Ubuntu_Updates"
    source_addresses = [local.vnet_cidr, "100.64.0.0/16"]
    target_fqdns     = [
      "security.ubuntu.com",
      "azure.archive.ubuntu.com",
      "changelogs.ubuntu.com"
    ]
    protocol {
      port = "80"
      type = "Http"
    }
    protocol {
      port = "443"
      type = "Https"
    }
  }

  rule {
    name             = "Allow_DevOps_and_GitHub"
    source_addresses = [local.vnet_cidr, "100.64.0.0/16"]
    target_fqdns     = [
      "dev.azure.com",
      "*.dev.azure.com",
      "github.com",
      "*.github.com",
      "api.github.com",
      "pypi.org",
      "files.pythonhosted.org"
    ]
    protocol {
      port = "443"
      type = "Https"
    }
  }
  
  # 방화벽 규칙 충돌(409) 방지를 위한 순서 강제 옵션
  depends_on = [
    azurerm_firewall_network_rule_collection.aks_required_net
  ]
}
