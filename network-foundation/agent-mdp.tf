# =====================================================
# 1. Dev Center 및 Project 프로비저닝 (MDP 필수 종속성)
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

# =====================================================
# Managed DevOps Pool을 위한 User-Assigned Managed Identity
# =====================================================
resource "azurerm_user_assigned_identity" "devops_mi" {
  name                = "id-mdp-agent-v2-${local.safe_location_no_spaces}"
  resource_group_name = data.azurerm_resource_group.vpn_rg.name
  location            = local.safe_location
}

# =====================================================
# DevOpsInfrastructure 서비스 주체에 권한 부여
# =====================================================
data "azuread_service_principal" "devops_infra_sp" {
  display_name = "DevOpsInfrastructure"
}

resource "azurerm_role_assignment" "devops_vnet_contributor" {
  # 리소스 그룹 레벨에서 네트워크 참가자 권한을 부여하여 VNet 접근 허용
  scope                = data.azurerm_resource_group.vpn_rg.id
  role_definition_name = "Network Contributor"
  principal_id         = data.azuread_service_principal.devops_infra_sp.object_id
}

# =====================================================
# 2. Managed DevOps Pool 리소스 프로비저닝
# =====================================================
resource "azapi_resource" "devops_pool" {
  type      = "Microsoft.DevOpsInfrastructure/pools@2024-04-04-preview"
  name      = "mdp-private-pool"
  location  = local.safe_location
  parent_id = data.azurerm_resource_group.vpn_rg.id

  schema_validation_enabled = false

  body = jsonencode({
    identity = {
      type = "UserAssigned"
      userAssignedIdentities = {
        "${azurerm_user_assigned_identity.devops_mi.id}" = {}
      }
    }
    properties = {
      devCenterProjectResourceId = azurerm_dev_center_project.dcp.id
      
      organizationProfile = {
        kind = "AzureDevOps"
        organizations = [
          {
            url      = var.ado_url
            projects = [] 
          }
        ]
        permissionProfile = {
          kind = "Inherited"
        }
      }
      
      agentProfile = {
        kind = "Stateless"
      }
      fabricProfile = {
        kind = "Vmss"
        sku = {
          name = "Standard_B2s" 
        }
        images = [
          {
            wellKnownImageName = "ubuntu-22.04/latest"
          }
        ]
        networkProfile = {
          subnetId = azurerm_subnet.app_subnet.id
        }
      }
      
      maximumConcurrency = 1
    }
  })

  tags = var.tags

  depends_on = [
    azurerm_dev_center_project.dcp,
    azurerm_role_assignment.devops_vnet_contributor # ★ 이 권한이 부여된 이후에만 풀이 생성되도록 종속성 강제
  ]
}
