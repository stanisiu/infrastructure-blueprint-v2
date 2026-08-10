variable "workload_rg_name" { default = "rg-enterprise-vpn-sec-v2" }
variable "onprem_gateway_ip" { type = string }
variable "onprem_address_space" { default = ["192.168.0.0/16"] }
variable "onprem_mgmt_subnet" { default = ["192.168.1.0/24"] }
variable "onprem_bgp_asn" { default = 65010 }
variable "onprem_bgp_peering_ip" { default = "192.168.1.254" }
variable "azure_bgp_asn" { default = 65515 }
variable "key_vault_id" { type = string }
variable "enable_active_active" { default = true }
variable "manage_network_watcher" { default = false }
variable "enable_delete_locks" { default = true }

variable "tags" {
  description = "실무 수준의 체계화된 공통 리소스 태그"
  type        = map(string)
  default = {
    Environment = "Production"
    Project     = "enterprise-vpn-sec-v2"
    ManagedBy   = "Terraform"
    Owner       = "Suhyun-Ju"
    CostCenter  = "CC-SEC-001"
    Department  = "Cloud-Infrastructure"
  }
} # <-- 여기서 tags 블록을 닫아줍니다.

variable "ado_url" {
  description = "Azure DevOps 조직 URL (예: https://dev.azure.com/myorganization)"
  type        = string
}

variable "ado_pool" {
  description = "에이전트를 등록할 Pool 이름"
  type        = string
  default     = "Private-AKS-Pool"
}