# 네트워크 모듈 상태(State) 참조 변수 (필수)
remote_state_rg        = "rg-terraform-state-prod"
remote_state_sa        = "sttfstateprod123"
remote_state_container = "tfstate"
remote_state_key       = "vpn-sec-network.terraform.tfstate"

# AKS 클러스터 변수 세팅 (필수 주입 및 오버라이드)
aks_cluster_name       = "aks-secure-prod"
aks_dns_prefix         = "aksprod"
aks_kubernetes_version = "1.28.5" # [핵심] 지원되는 최신 버전 명시
aks_vm_size            = "Standard_D4s_v3"
aks_zones              = ["1", "2", "3"]
aks_min_node_count     = 2
aks_max_node_count     = 5
aks_pod_cidr           = "100.64.0.0/16"
acr_id                 = "" # ACR이 없다면 빈 문자열 유지