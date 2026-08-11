# AKS 모듈이 원격 상태(remote_state)로 읽어갈 핵심 연결 고리들
output "vpn_rg_name" { value = data.azurerm_resource_group.vpn_rg.name }
output "safe_location" { value = local.safe_location }
output "aks_subnet_id" { value = azurerm_subnet.aks_subnet.id }
output "log_analytics_workspace_id" { value = azurerm_log_analytics_workspace.law.id }
output "flowlog_sa_id" { value = azurerm_storage_account.flowlog_sa.id }
output "dns_resolver_inbound_ip" { value = azurerm_private_dns_resolver_inbound_endpoint.inbound.ip_configurations[0].private_ip_address }
output "vnet_address_space" {
  description = "코어 가상 네트워크의 주소 대역"
  value       = azurerm_virtual_network.main_vnet.address_space
}

output "onprem_address_space" {
  description = "온프레미스 VPN 주소 대역"
  value       = var.onprem_address_space
}

# =====================================================
#  온프레미스 라우터 BGP 설정용 피어 IP 출력
# =====================================================
output "vpn_gateway_bgp_peer_ip_1" {
  description = "온프레미스 라우터에 설정할 첫 번째 인스턴스의 BGP 피어 IP"
  value = one([
    for p in azurerm_virtual_network_gateway.vng.bgp_settings[0].peering_addresses :
    p.default_addresses[0] if p.ip_configuration_name == "vng-ip-config-1"
  ])
}

output "vpn_gateway_bgp_peer_ip_2" {
  description = "온프레미스 라우터에 설정할 두 번째 인스턴스(Active-Active)의 BGP 피어 IP"
  value = var.enable_active_active ? one([
    for p in azurerm_virtual_network_gateway.vng.bgp_settings[0].peering_addresses :
    p.default_addresses[0] if p.ip_configuration_name == "vng-ip-config-2"
  ]) : null
}

# =====================================================
# Managed DevOps Pool의 Managed Identity 참조
# =====================================================
output "devops_agent_principal_id" {
  description = "CI/CD 에이전트(Managed DevOps Pool)의 Managed Identity Principal ID"
  
  # azapi_resource의 identity 블록을 직접 참조하는 방식
  value = azurerm_user_assigned_identity.devops_mi.principal_id 
  
  # 참고: 만약 agent-mdp.tf 내에서 azapi_resource가 response_export_values를 통해 
  # JSON 형태로 값을 반환하도록 구성되어 있다면 아래 주석 처리된 방식을 사용해야 함.
  # value     = jsondecode(azapi_resource.devops_pool.output).identity.principalId
}

output "current_subscription_id" {
  description = "현재 연결된 Azure 구독 ID"
  value       = data.azurerm_client_config.current.subscription_id
}

output "current_client_id" {
  description = "현재 연결된 서비스 주체(앱) ID"
  value       = data.azurerm_client_config.current.client_id
}
