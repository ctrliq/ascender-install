variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "eks_cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "ascender-eks-cluster"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.29"
}

variable "num_nodes" {
  description = "Number of nodes to create in the EKS node group"
  type        = number
  default     = 3
}

variable "aws_vm_size" {
  description = "Instance type for the EKS nodes"
  type        = string
  default     = "t3.large"
}

variable "volume_size" {
  description = "Disk size for each EKS worker node"
  type        = number
  default     = 100
}