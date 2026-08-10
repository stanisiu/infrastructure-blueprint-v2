# Network Foundation 모듈이 생성한 코어 네트워크 정보를 안전하게 읽어옵니다.
data "terraform_remote_state" "network" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.remote_state_rg
    storage_account_name = var.remote_state_sa
    container_name       = var.remote_state_container
    key                  = var.remote_state_key
  }
}