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

# Instance Details
output "instance_name" {
  description = "The name of the compute instance"
  value       = google_compute_instance.replicated_cluster.name
}

output "instance_id" {
  description = "The ID of the compute instance"
  value       = google_compute_instance.replicated_cluster.instance_id
}

output "instance_self_link" {
  description = "The self link of the compute instance"
  value       = google_compute_instance.replicated_cluster.self_link
}

output "instance_zone" {
  description = "The zone where the instance is deployed"
  value       = google_compute_instance.replicated_cluster.zone
}

output "instance_machine_type" {
  description = "The machine type of the instance"
  value       = google_compute_instance.replicated_cluster.machine_type
}

# Network Details
output "instance_nat_ip" {
  description = "The external IP address of the instance"
  value       = local.instance_nat_ip
}

output "instance_private_ip" {
  description = "The private IP address of the instance"
  value       = local.instance_private_ip
}

output "instance_network" {
  description = "The network the instance is attached to"
  value       = length(google_compute_instance.replicated_cluster.network_interface) > 0 ? google_compute_instance.replicated_cluster.network_interface[0].network : null
}

# Replicated Embedded Cluster Access
output "admin_console_url" {
  description = "URL to access the Replicated admin console"
  value       = local.instance_nat_ip != null ? "https://${local.instance_nat_ip}:30000" : "Admin console accessible via private IP: https://${local.instance_private_ip}:30000"
}

output "application_url" {
  description = "URL to access the deployed application (HTTP)"
  value       = local.instance_nat_ip != null ? "http://${local.instance_nat_ip}" : "Application accessible via private IP: http://${local.instance_private_ip}"
}

output "application_https_url" {
  description = "URL to access the deployed application (HTTPS)"
  value       = local.instance_nat_ip != null ? "https://${local.instance_nat_ip}" : "Application accessible via private IP: https://${local.instance_private_ip}"
}

output "kubernetes_api_url" {
  description = "URL to access the Kubernetes API"
  value       = local.instance_nat_ip != null ? "https://${local.instance_nat_ip}:6443" : "Kubernetes API accessible via private IP: https://${local.instance_private_ip}:6443"
}

# SSH Access
output "ssh_command" {
  description = "Command to SSH into the instance"
  value       = local.instance_nat_ip != null ? "gcloud compute ssh ${google_compute_instance.replicated_cluster.name} --zone=${google_compute_instance.replicated_cluster.zone}" : "Instance has no external IP. Use gcloud compute ssh with IAP or internal access."
}

# Deployment Information
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

# Post-deployment Instructions
output "next_steps" {
  description = "Next steps after deployment"
  value = <<-EOT
    Deployment complete! Follow these steps to access your Replicated Embedded Cluster:

    1. Access the Admin Console:
       ${local.instance_nat_ip != null ? "https://${local.instance_nat_ip}:30000" : "https://${local.instance_private_ip}:30000"}

    2. SSH into the instance:
       ${local.instance_nat_ip != null ? "gcloud compute ssh ${google_compute_instance.replicated_cluster.name} --zone=${google_compute_instance.replicated_cluster.zone}" : "Use gcloud compute ssh with appropriate access"}

    3. Get the admin console password (via SSH):
       sudo cat /var/lib/embedded-cluster/admin-console-password

    4. Upload your Replicated license file in the admin console

    5. Configure and deploy your application through the admin console

    For more information, visit: https://docs.replicated.com/vendor/embedded-overview
  EOT
}
