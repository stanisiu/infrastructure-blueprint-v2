# =====================================================
# 1. Dev Center 및 Project 프로비저닝 (MDP 필수 종속성)
# =====================================================
resource "azurerm_dev_center" "dc" {
  # 👉 [수정됨] 찌꺼기 충돌(409)을 피하기 위해 이름에 -v2 추가
  name                = "dc-core-network-v2"
  resource_group_name = data.azurerm_resource_group.vpn_rg.name
  location            = local.safe_location
}

resource "azurerm_dev_center_project" "dcp" {
  # 👉 [수정됨] Project 이름에도 동일하게 -v2 추가
  name                = "dcp-core-network-v2"
  resource_group_name = data.azurerm_resource_group.vpn_rg.name
  location            = local.safe_location
  dev_center_id       = azurerm_dev_center.dc.id
}

# =====================================================
# Managed DevOps Pool을 위한 User-Assigned Managed Identity
# =====================================================
resource "azurerm_user_assigned_identity" "devops_mi" {
  name                = "id-mdp-agent-v2-${local.nw_name}"
  resource_group_name = local.nw_rg
  location            = local.safe_location
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
          name = "Standard_D2ds_v5" 
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
      
      maximumConcurrency = 2
    }
  })

  tags = var.tags

  # 👉 권한 부여 블록을 제거하고 Dev Center 순서만 보장
  depends_on = [
    azurerm_dev_center_project.dcp
  ]
}