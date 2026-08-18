# =====================================================
# 0. 테라폼 프로바이더 및 버전 설정 (v4.68.0 이상 완벽 호환)
# =====================================================
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.68.0" 
    }
    azuread = {
      source  = "hashicorp/azuread"
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
  # ★ 리전 통합 및 학생 구독 제한 회피를 위해 koreasouth로 통일
  safe_location           = "koreasouth"
  safe_location_no_spaces = "koreasouth"

  vnet_cidr         = "10.0.0.0/16"
  app_subnet_cidr   = "10.0.1.0/24"
  aks_subnet_cidr   = "10.0.8.0/22" 
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
# 4. VPN 게이트웨이 및 연결 (Active-Active 비활성화로 IP 절약)
# =====================================================
resource "azurerm_public_ip" "vng_pip" {
  name                = "pip-vpn-gateway-1"
  location            = local.safe_location
  resource_group_name = data.azurerm_resource_group.vpn_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_virtual_network_gateway" "vng" {
  name                = "vng-core-vpn"
  location            = local.safe_location
  resource_group_name = data.azurerm_resource_group.vpn_rg.name
  type                = "Vpn"
  vpn_type            = "RouteBased"
  sku                 = "VpnGw1"
  generation          = "Generation1"
  active_active       = false
  
  bgp_settings { asn = var.azure_bgp_asn }
  
  ip_configuration {
    name                          = "vng-ip-config-1"
    public_ip_address_id          = azurerm_public_ip.vng_pip.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway_subnet.id
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
# 7. Dev Center 및 Managed DevOps Pool (쿼타 초과 방지를 위한 D 시리즈 적용)
# =====================================================
resource "azurerm_dev_center" "dc" {
  name                = "dc-core-network-v2"
  resource_group_name = data.azurerm_resource_group.vpn_rg.name
  location            = local.safe_location
}

resource "azurerm_dev_center_project" "dcp" {
  name                = "dcp-core-network-v2"
  resource_group_name = data.azurerm_resource_group.vpn_rg.name
  location            = local.safe_location
  dev_center_id       = azurerm_dev_center.dc.id
}

resource "azurerm_user_assigned_identity" "devops_mi" {
  name                = "id-mdp-agent-v2-${local.safe_location_no_spaces}"
  resource_group_name = data.azurerm_resource_group.vpn_rg.name
  location            = local.safe_location
}

resource "azurerm_role_assignment" "devops_vnet_contributor" {
  scope                = data.azurerm_resource_group.vpn_rg.id
  role_definition_name = "Network Contributor"
  principal_id         = "6854130e-96f3-4483-867b-2a9d45dfac2e"
}

resource "time_sleep" "wait_for_rbac_propagation" {
  depends_on      = [azurerm_role_assignment.devops_vnet_contributor]
  create_duration = "60s"
}

resource "azurerm_managed_devops_pool" "devops_pool" {
  name                  = "mdp-private-pool"
  location              = local.safe_location
  resource_group_name   = data.azurerm_resource_group.vpn_rg.name
  
  dev_center_project_id = azurerm_dev_center_project.dcp.id
  maximum_concurrency   = 1

  azure_devops_organization {
    organization {
      url         = var.ado_url
      projects    = []
      parallelism = 1
    }
  }

  stateless_agent {}

  virtual_machine_scale_set_fabric {
    # B 시리즈 할당량 제한(0)을 우회하기 위해 D 시리즈 표준 스펙 적용
    sku_name = "Standard_D2s_v3"
    
    image {
      well_known_image_name = "ubuntu-22.04/latest"
    }

    subnet_id = azurerm_subnet.app_subnet.id
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.devops_mi.id]
  }

  depends_on = [
    azurerm_dev_center_project.dcp,
    time_sleep.wait_for_rbac_propagation
  ]
}
