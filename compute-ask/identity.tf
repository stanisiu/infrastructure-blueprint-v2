locals {
  k8s_namespace     = "workload-app"
  k8s_service_account = "app-workload-sa"
}

resource "azurerm_federated_identity_credential" "aks_kv_federated" {
  name                = "fed-cred-app-workload"
  resource_group_name = local.rg
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.aks_cluster.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.workload_identity.id
  subject             = "system:serviceaccount:${local.k8s_namespace}:${local.k8s_service_account}"
}

resource "azurerm_user_assigned_identity" "workload_identity" {
  name                = "id-workload-app-prod"
  resource_group_name = local.rg
  location            = local.loc
  tags                = var.tags
}

resource "azurerm_role_assignment" "kv_secrets_user" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.workload_identity.principal_id
}