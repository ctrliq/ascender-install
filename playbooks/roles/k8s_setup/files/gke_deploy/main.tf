resource "google_container_cluster" "primary" {
  name     = var.gke_cluster_name
  min_master_version = var.kubernetes_version
  location = var.zone
  initial_node_count = var.num_nodes

  node_config {
    machine_type = var.gcloud_vm_size
  }
}

output "cluster_name" {
  value = google_container_cluster.primary.name
}

output "cluster_endpoint" {
  value = google_container_cluster.primary.endpoint
}

output "cluster_ca_certificate" {
  value = google_container_cluster.primary.master_auth.0.cluster_ca_certificate
}

