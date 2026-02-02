# Copyright 2025 Replicated, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# ============================================================================
# Primary Controller Outputs (Backward Compatible)
# ============================================================================

output "instance_name" {
  description = "The name of the primary controller instance"
  value       = google_compute_instance.primary_controller.name
}

output "instance_id" {
  description = "The ID of the primary controller instance"
  value       = google_compute_instance.primary_controller.instance_id
}

output "instance_self_link" {
  description = "The self link of the primary controller instance"
  value       = google_compute_instance.primary_controller.self_link
}

output "instance_zone" {
  description = "The zone where the primary controller is deployed"
  value       = google_compute_instance.primary_controller.zone
}

output "instance_machine_type" {
  description = "The machine type of the primary controller"
  value       = google_compute_instance.primary_controller.machine_type
}

output "instance_nat_ip" {
  description = "The external IP address of the primary controller"
  value       = local.primary_controller_nat_ip
}

output "instance_private_ip" {
  description = "The private IP address of the primary controller"
  value       = local.primary_controller_private_ip
}

output "instance_network" {
  description = "The network the primary controller is attached to"
  value       = length(google_compute_instance.primary_controller.network_interface) > 0 ? google_compute_instance.primary_controller.network_interface[0].network : null
}

# ============================================================================
# Multi-Node Cluster Outputs
# ============================================================================

output "controller_names" {
  description = "Names of all controller instances"
  value = concat(
    [google_compute_instance.primary_controller.name],
    google_compute_instance.additional_controllers[*].name
  )
}

output "controller_private_ips" {
  description = "Private IP addresses of all controller instances"
  value = concat(
    [google_compute_instance.primary_controller.network_interface[0].network_ip],
    [for instance in google_compute_instance.additional_controllers : instance.network_interface[0].network_ip]
  )
}

output "controller_public_ips" {
  description = "Public IP addresses of all controller instances (if available)"
  value = concat(
    [local.primary_controller_nat_ip],
    [
      for instance in google_compute_instance.additional_controllers :
      length(instance.network_interface[0].access_config) > 0 ? instance.network_interface[0].access_config[0].nat_ip : null
    ]
  )
}

output "worker_names" {
  description = "Names of all worker instances grouped by pool"
  value = {
    for pool in var.worker_pools :
    pool.name => [
      for name, instance in google_compute_instance.workers :
      instance.name if instance.labels.pool == pool.name
    ]
  }
}

output "worker_private_ips" {
  description = "Private IP addresses of all worker instances grouped by pool"
  value = {
    for pool in var.worker_pools :
    pool.name => [
      for name, instance in google_compute_instance.workers :
      instance.network_interface[0].network_ip if instance.labels.pool == pool.name
    ]
  }
}

output "worker_public_ips" {
  description = "Public IP addresses of all worker instances grouped by pool (if available)"
  value = {
    for pool in var.worker_pools :
    pool.name => [
      for name, instance in google_compute_instance.workers :
      length(instance.network_interface[0].access_config) > 0 ? instance.network_interface[0].access_config[0].nat_ip : null
      if instance.labels.pool == pool.name
    ]
  }
}

# ============================================================================
# Replicated Embedded Cluster Access
# ============================================================================

output "admin_console_url" {
  description = "URL to access the Replicated admin console"
  value       = local.primary_controller_nat_ip != null ? "https://${local.primary_controller_nat_ip}:30000" : "Admin console accessible via private IP: https://${local.primary_controller_private_ip}:30000"
}

output "admin_console_password" {
  description = "Admin console password (stored on primary controller at /var/lib/embedded-cluster/admin-console-password)"
  value       = "SSH to primary controller and run: sudo cat /var/lib/embedded-cluster/admin-console-password"
}

output "application_url" {
  description = "URL to access the deployed application (HTTP)"
  value       = local.primary_controller_nat_ip != null ? "http://${local.primary_controller_nat_ip}" : "Application accessible via private IP: http://${local.primary_controller_private_ip}"
}

output "application_https_url" {
  description = "URL to access the deployed application (HTTPS)"
  value       = local.primary_controller_nat_ip != null ? "https://${local.primary_controller_nat_ip}" : "Application accessible via private IP: https://${local.primary_controller_private_ip}"
}

output "kubernetes_api_url" {
  description = "URL to access the Kubernetes API"
  value       = local.primary_controller_nat_ip != null ? "https://${local.primary_controller_nat_ip}:6443" : "Kubernetes API accessible via private IP: https://${local.primary_controller_private_ip}:6443"
}

# ============================================================================
# SSH Access
# ============================================================================

output "ssh_command" {
  description = "Command to SSH into the primary controller"
  value       = local.primary_controller_nat_ip != null ? "gcloud compute ssh ${google_compute_instance.primary_controller.name} --zone=${google_compute_instance.primary_controller.zone}" : "Instance has no external IP. Use gcloud compute ssh with IAP or internal access."
}

output "ssh_commands_all_nodes" {
  description = "Commands to SSH into all nodes"
  value = merge(
    {
      "primary-controller" = local.primary_controller_nat_ip != null ? "gcloud compute ssh ${google_compute_instance.primary_controller.name} --zone=${google_compute_instance.primary_controller.zone}" : "No external IP"
    },
    {
      for idx, instance in google_compute_instance.additional_controllers :
      "controller-${idx + 1}" => "gcloud compute ssh ${instance.name} --zone=${instance.zone}"
    },
    {
      for name, instance in google_compute_instance.workers :
      "worker-${name}" => "gcloud compute ssh ${instance.name} --zone=${instance.zone}"
    }
  )
}

# ============================================================================
# Deployment Information
# ============================================================================

output "deployment_name" {
  description = "The deployment name"
  value       = var.goog_cm_deployment_name
}

output "replicated_app_slug" {
  description = "The Replicated application slug"
  value       = var.replicated_app_slug
}

output "replicated_channel_slug" {
  description = "The Replicated channel slug"
  value       = var.replicated_channel_slug
}

output "cluster_size" {
  description = "Total number of nodes in the cluster"
  value = {
    controllers = var.controller_count
    workers     = length(var.worker_pools) > 0 ? sum([for pool in var.worker_pools : pool.count]) : 0
    total       = var.controller_count + (length(var.worker_pools) > 0 ? sum([for pool in var.worker_pools : pool.count]) : 0)
  }
}

# ============================================================================
# Post-deployment Instructions
# ============================================================================

output "next_steps" {
  description = "Next steps after deployment"
  value = <<-EOT
    Deployment complete! Follow these steps to access your Replicated Embedded Cluster:

    1. Access the Admin Console:
       ${local.primary_controller_nat_ip != null ? "https://${local.primary_controller_nat_ip}:30000" : "https://${local.primary_controller_private_ip}:30000"}

    2. SSH into the primary controller:
       ${local.primary_controller_nat_ip != null ? "gcloud compute ssh ${google_compute_instance.primary_controller.name} --zone=${google_compute_instance.primary_controller.zone}" : "Use gcloud compute ssh with appropriate access"}

    3. Get the admin console password (via SSH):
       sudo cat /var/lib/embedded-cluster/admin-console-password

    4. Upload your Replicated license file in the admin console

    5. Configure and deploy your application through the admin console

    Cluster Configuration:
    - Controllers: ${var.controller_count}
    - Worker Pools: ${length(var.worker_pools)}
    - Total Workers: ${length(var.worker_pools) > 0 ? sum([for pool in var.worker_pools : pool.count]) : 0}
    - Total Nodes: ${var.controller_count + (length(var.worker_pools) > 0 ? sum([for pool in var.worker_pools : pool.count]) : 0)}

    For more information, visit: https://docs.replicated.com/vendor/embedded-overview
  EOT
}
