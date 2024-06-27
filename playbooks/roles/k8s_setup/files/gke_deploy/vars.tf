/*
variable "use_existing_project" {
  description = "Boolean to decide whether to use an existing project or create a new one."
  type        = bool
  default     = false
}
*/

variable "project_id" {
  description = "The ID of the existing project to use. Only required if use_existing_project is true."
  type        = string
  default     = "dummy_project"
}

variable "kubernetes_version" {
  description = "The Kubernetes version for the master and nodes."
  type        = string
  default     = "1.27.11-gke.1062004" 
}

variable "zone" {
  description = "The zone to deploy the GKE cluster."
  type        = string
  default     = "us-central1-a"
}

variable "gke_cluster_name" {
  description = "The name of the GKE cluster"
  type        = string
  default     = "ascender-gke-cluster"
}

variable "num_nodes" {
  description = "The number of nodes in the node pool."
  type        = number
  default     = 3
}

variable "gcloud_vm_size" {
  description = "The size of the instance (machine type) for the worker nodes."
  type        = string
  default     = "n1-standard-1"
}

variable "volume_size" {
  description = "The size of the boot disk for the worker nodes, in GB."
  type        = number
  default     = 100
}

variable "home_dir" {
  description = "Home directory path"
  type        = string
  default     = "/home/default"
}
