import {
  to = azurerm_dev_center.dc
  id = "/subscriptions/5df9d2ab-f232-4a36-8e8e-63998eaf120a/resourceGroups/rg-enterprise-vpn-sec-v2/providers/Microsoft.DevCenter/devCenters/dc-core-network-v2"
}

import {
  to = azurerm_user_assigned_identity.devops_mi
  id = "/subscriptions/5df9d2ab-f232-4a36-8e8e-63998eaf120a/resourceGroups/NetworkWatcherRG/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-mdp-agent-v2-NetworkWatcher_koreacentral"
}

import {
  to = azurerm_log_analytics_workspace.law
  id = "/subscriptions/5df9d2ab-f232-4a36-8e8e-63998eaf120a/resourceGroups/rg-enterprise-vpn-sec-v2/providers/Microsoft.OperationalInsights/workspaces/law-vpn-diagnostics"
}

import {
  to = azurerm_virtual_network.main_vnet
  id = "/subscriptions/5df9d2ab-f232-4a36-8e8e-63998eaf120a/resourceGroups/rg-enterprise-vpn-sec-v2/providers/Microsoft.Network/virtualNetworks/vnet-core-network"
}

import {
  to = azurerm_public_ip.vng_pip
  id = "/subscriptions/5df9d2ab-f232-4a36-8e8e-63998eaf120a/resourceGroups/rg-enterprise-vpn-sec-v2/providers/Microsoft.Network/publicIPAddresses/pip-vpn-gateway-1"
}

import {
  to = azurerm_public_ip.vng_pip_2[0]
  id = "/subscriptions/5df9d2ab-f232-4a36-8e8e-63998eaf120a/resourceGroups/rg-enterprise-vpn-sec-v2/providers/Microsoft.Network/publicIPAddresses/pip-vpn-gateway-2"
}

import {
  to = azurerm_local_network_gateway.onprem_lng
  id = "/subscriptions/5df9d2ab-f232-4a36-8e8e-63998eaf120a/resourceGroups/rg-enterprise-vpn-sec-v2/providers/Microsoft.Network/localNetworkGateways/lng-onprem-datacenter"
}

import {
  to = azurerm_network_security_group.app_nsg
  id = "/subscriptions/5df9d2ab-f232-4a36-8e8e-63998eaf120a/resourceGroups/rg-enterprise-vpn-sec-v2/providers/Microsoft.Network/networkSecurityGroups/nsg-app-subnet"
}

import {
  to = azurerm_storage_account.flowlog_sa
  id = "/subscriptions/5df9d2ab-f232-4a36-8e8e-63998eaf120a/resourceGroups/rg-enterprise-vpn-sec-v2/providers/Microsoft.Storage/storageAccounts/stvpnflowlogsaf521ffb"
}

import {
  to = azurerm_public_ip.fw_pip
  id = "/subscriptions/5df9d2ab-f232-4a36-8e8e-63998eaf120a/resourceGroups/rg-enterprise-vpn-sec-v2/providers/Microsoft.Network/publicIPAddresses/pip-fw-core"
}

import {
  to = azurerm_dev_center_project.dcp
  id = "/subscriptions/5df9d2ab-f232-4a36-8e8e-63998eaf120a/resourceGroups/rg-enterprise-vpn-sec-v2/providers/Microsoft.DevCenter/projects/dcp-core-network-v2"
}

import {
  to = azurerm_subnet.app_subnet
  id = "/subscriptions/5df9d2ab-f232-4a36-8e8e-63998eaf120a/resourceGroups/rg-enterprise-vpn-sec-v2/providers/Microsoft.Network/virtualNetworks/vnet-core-network/subnets/snet-applications"
}

import {
  to = azurerm_subnet.gateway_subnet
  id = "/subscriptions/5df9d2ab-f232-4a36-8e8e-63998eaf120a/resourceGroups/rg-enterprise-vpn-sec-v2/providers/Microsoft.Network/virtualNetworks/vnet-core-network/subnets/GatewaySubnet"
}

import {
  to = azurerm_subnet.aks_subnet
  id = "/subscriptions/5df9d2ab-f232-4a36-8e8e-63998eaf120a/resourceGroups/rg-enterprise-vpn-sec-v2/providers/Microsoft.Network/virtualNetworks/vnet-core-network/subnets/snet-aks-cluster"
}

import {
  to = azurerm_subnet.dns_resolver_subnet
  id = "/subscriptions/5df9d2ab-f232-4a36-8e8e-63998eaf120a/resourceGroups/rg-enterprise-vpn-sec-v2/providers/Microsoft.Network/virtualNetworks/vnet-core-network/subnets/snet-dns-resolver-inbound"
}

import {
  to = azurerm_private_dns_resolver.resolver
  id = "/subscriptions/5df9d2ab-f232-4a36-8e8e-63998eaf120a/resourceGroups/rg-enterprise-vpn-sec-v2/providers/Microsoft.Network/dnsResolvers/dnspr-core-network"
}

import {
  to = azurerm_subnet.fw_subnet
  id = "/subscriptions/5df9d2ab-f232-4a36-8e8e-63998eaf120a/resourceGroups/rg-enterprise-vpn-sec-v2/providers/Microsoft.Network/virtualNetworks/vnet-core-network/subnets/AzureFirewallSubnet"
}