# ---------------------------------------------------
# Remote State (Network Foundation) 참조 변수
# ---------------------------------------------------
variable "remote_state_rg" {
  description = "Network 모듈의 Terraform 상태 파일이 있는 리소스 그룹"
  type        = string
}

variable "remote_state_sa" {
  description = "Network 모듈의 Terraform 상태 파일이 있는 스토리지 계정"
  type        = string
}

variable "remote_state_container" {
  description = "상태 파일 컨테이너 이름"
  type        = string
  default     = "tfstate"
}

variable "remote_state_key" {
  description = "Network 모듈의 상태 파일 이름 (Key)"
  type        = string
  default     = "vpn-sec-network.terraform.tfstate"
}

# ---------------------------------------------------
# AKS 클러스터 변수
# ---------------------------------------------------
variable "aks_cluster_name" {
  description = "AKS 클러스터 리소스 이름"
  type        = string
  default     = "aks-secure-prod"
}

variable "aks_dns_prefix" {
  description = "AKS 클러스터 DNS 접두사"
  type        = string
  default     = "aksprod"
}

variable "aks_kubernetes_version" {
  description = "AKS Kubernetes 버전 (지원 종료 버전 방지를 위해 주입 강제)"
  type        = string
}

variable "aks_vm_size" {
  description = "AKS System Node Pool의 VM 사이즈"
  type        = string
  # 👉 [수정됨] 코어 할당량 부족 에러 방지를 위해 4코어(D4s) -> 2코어(D2s)로 안전하게 하향 조정
  default     = "Standard_D2s_v3"
}

variable "aks_zones" {
  description = "AKS 고가용성 가용 영역"
  type        = list(string)
  default     = ["1", "2", "3"]
}

variable "aks_min_node_count" {
  description = "Autoscaler 최소 노드 수"
  type        = number
  default     = 2
}

variable "aks_max_node_count" {
  description = "Autoscaler 최대 노드 수"
  type        = number
  default     = 5
}

variable "aks_pod_cidr" {
  description = "Azure CNI Overlay 파드 전용 CIDR"
  type        = string
  default     = "100.64.0.0/16"
}

# ---------------------------------------------------
# 엔터프라이즈 Tagging 표준
# ---------------------------------------------------
variable "tags" {
  description = "실무 수준의 체계화된 공통 리소스 태그"
  type        = map(string)
  default = {
    Environment = "Production"
    # 👉 [수정됨] 앞서 수정했던 네트워크 모듈의 프로젝트 이름과 동일하게 v2로 맞춤
    Project     = "enterprise-vpn-sec-v2"
    ManagedBy   = "Terraform"
    Owner       = "Suhyun-Ju"
    CostCenter  = "CC-SEC-001"
    Department  = "Cloud-Infrastructure"
  }
}

variable "acr_id" {
  description = "AKS가 이미지를 가져올 Azure Container Registry(ACR)의 리소스 ID. 아직 없다면 비워둡니다."
  type        = string
  default     = "" 
}