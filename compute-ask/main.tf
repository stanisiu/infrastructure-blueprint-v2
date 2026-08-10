# =====================================================
# 1. 의존성 매핑 (Network 모듈의 Output 연결)
# =====================================================
locals {
  loc         = data.terraform_remote_state.network.outputs.safe_location
  rg          = data.terraform_remote_state.network.outputs.vpn_rg_name
  law         = data.terraform_remote_state.network.outputs.log_analytics_workspace_id
  snet        = data.terraform_remote_state.network.outputs.aks_subnet_id
  nw_name     = data.terraform_remote_state.network.outputs.nw_name
  nw_rg       = data.terraform_remote_state.network.outputs.nw_rg_name
  flowlog_sa  = data.terraform_remote_state.network.outputs.flowlog_sa_id
  vnet_cidr   = data.terraform_remote_state.network.outputs.vnet_address_space
  onprem_cidr = data.terraform_remote_state.network.outputs.onprem_address_space
}

# =====================================================
# 2. 네트워크 보안 그룹 (AKS 전용)
# =====================================================
resource "azurerm_network_security_group" "aks_nsg" {
  name                = "nsg-aks-subnet"
  location            = local.loc
  resource_group_name = local.rg

  security_rule {
    name                       = "Allow_AzureLoadBalancer_Inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  # 하드코딩이 제거된 동적 할당 규칙 
  security_rule {
    name                       = "Allow_Internal_And_VPN"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefixes    = concat(local.vnet_cidr, local.onprem_cidr)
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

# =====================================================
# 3. Flow Log (트래픽 관제)
# =====================================================
resource "azurerm_network_watcher_flow_log" "aks_nsg_flow_log" {
  name                 = "flowlog-aks-nsg"
  network_watcher_name = local.nw_name
  resource_group_name  = local.nw_rg

  network_security_group_id = azurerm_network_security_group.aks_nsg.id
  storage_account_id        = local.flowlog_sa
  enabled                   = true

  retention_policy {
    enabled = true
    days    = 30
  }

  traffic_analytics {
    enabled               = true
    workspace_id          = local.law
    workspace_region      = local.loc
    workspace_resource_id = local.law
    interval_in_minutes   = 10
  }
}

# =====================================================
# 3-1. NSG와 AKS 서브넷 연결 (추가된 부분)
# =====================================================
resource "azurerm_subnet_network_security_group_association" "aks_nsg_assoc" {
  subnet_id                 = local.snet
  network_security_group_id = azurerm_network_security_group.aks_nsg.id
}

# =====================================================
# 4. Azure Kubernetes Service (Private Cluster)
# =====================================================
resource "azurerm_kubernetes_cluster" "aks_cluster" {
  name                = var.aks_cluster_name
  location            = local.loc
  resource_group_name = local.rg
  dns_prefix          = var.aks_dns_prefix
  kubernetes_version  = var.aks_kubernetes_version

  private_cluster_enabled = true
  private_dns_zone_id     = "System"

  automatic_channel_upgrade = "node-image"
  workload_identity_enabled = true
  oidc_issuer_enabled       = true

  # 로컬 관리자 계정 전면 비활성화 (Entra ID RBAC 강제)
  local_account_disabled    = true

  depends_on = [azurerm_subnet_network_security_group_association.aks_nsg_assoc]

  default_node_pool {
    name                  = "systempool"
    vm_size               = "Standard_D4s_v3"
    vnet_subnet_id        = local.snet
    zones                 = var.aks_zones
    enable_node_public_ip = false
    max_pods              = 110
    auto_scaling_enabled  = true
    min_count             = 2
    max_count             = 4
    node_labels = {
      "node.kubernetes.io/workload-type" = "system"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  # Azure CNI Overlay 모델 적용
  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "azure"
    outbound_type       = "userDefinedRouting"
    pod_cidr            = var.aks_pod_cidr 
    dns_service_ip      = "172.16.0.10"
    service_cidr        = "172.16.0.0/16"
  }

  oms_agent {
    log_analytics_workspace_id = local.law
  }

  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  tags = var.tags
}

# User Node Pool (애플리케이션 전용 분리 추가)
resource "azurerm_kubernetes_cluster_node_pool" "user_pool" {
  name                  = "userpool"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks_cluster.id
  vm_size               = var.aks_vm_size
  vnet_subnet_id        = local.snet
  zones                 = var.aks_zones
  enable_node_public_ip = false
  max_pods              = 110
  auto_scaling_enabled  = true
  min_count             = var.aks_min_node_count
  max_count             = var.aks_max_node_count

  node_labels = {
    "node.kubernetes.io/workload-type" = "application"
  }

  tags = var.tags
}

# =====================================================
# 5. 제로 트러스트 감사 로그 (Control Plane Audit)
# =====================================================
# 보안 컴플라이언스 준수를 위한 컨트롤 플레인 감사(Audit) 로그 수집 활성화
resource "azurerm_monitor_diagnostic_setting" "aks_diag" {
  name                       = "diag-aks-control-plane"
  target_resource_id         = azurerm_kubernetes_cluster.aks_cluster.id
  log_analytics_workspace_id = local.law

  enabled_log {
    category = "kube-audit"
  }
  
  enabled_log {
    category = "kube-audit-admin"
  }
  
  enabled_log {
    category = "kube-apiserver"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# =====================================================
# 6. 권한 할당 및 AD 전파 지연(Propagation) 방어
# =====================================================
resource "time_sleep" "wait_for_ad_propagation" {
  depends_on      = [azurerm_kubernetes_cluster.aks_cluster]
  create_duration = "60s"
}

resource "azurerm_role_assignment" "aks_network_contributor" {
  scope                = local.snet
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.aks_cluster.identity[0].principal_id
  
  depends_on           = [time_sleep.wait_for_ad_propagation]
}

resource "azurerm_role_assignment" "aks_acr_pull" {
  count                = var.acr_id != "" ? 1 : 0
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  
  principal_id         = azurerm_kubernetes_cluster.aks_cluster.kubelet_identity[0].object_id
  depends_on           = [time_sleep.wait_for_ad_propagation]
}

# =====================================================
# 7. CI/CD 에이전트 VM에 AKS 접근 권한 부여 (RBAC)
# =====================================================
# 🚨 주의: 기존의 azurerm_role_assignment.agent_aks_admin 블록은 
# 보안 취약점(클러스터 전체 제어권 탈취 위험)이므로 완전히 삭제합니다.

resource "azurerm_role_assignment" "agent_aks_user" {
  scope                = azurerm_kubernetes_cluster.aks_cluster.id
  # 최소 권한 원칙 적용: Admin이 아닌 User 권한으로 Kubeconfig 획득만 허용
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = data.terraform_remote_state.network.outputs.devops_agent_principal_id
  
  depends_on = [time_sleep.wait_for_ad_propagation]
}

# =====================================================
# 8. 파이프라인 서비스 커넥션(OIDC/SP)에 AKS 기본 접속 권한 부여
# =====================================================
# 현재 Terraform을 실행하고 있는 주체의 정보를 동적으로 가져옵니다.
data "azurerm_client_config" "current" {}

# 🚨 [수정됨] 파이프라인(서비스 커넥션)이 클러스터 Admin이 되지 않도록 User 권한으로 강등
resource "azurerm_role_assignment" "pipeline_aks_user" {
  scope                = azurerm_kubernetes_cluster.aks_cluster.id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = data.azurerm_client_config.current.object_id
  
  depends_on = [time_sleep.wait_for_ad_propagation]
}