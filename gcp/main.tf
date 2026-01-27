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

locals {
  network_interfaces = [
    for i, network in var.networks : {
      network     = network
      subnetwork  = length(var.sub_networks) > i ? var.sub_networks[i] : null
      external_ip = length(var.external_ips) > i ? var.external_ips[i] : "NONE"
      nat_ip      = length(var.external_ips) > i && var.external_ips[i] != "NONE" && var.external_ips[i] != "EPHEMERAL" ? var.external_ips[i] : null
    }
  ]

  instance_nat_ip     = length(google_compute_instance.replicated_cluster.network_interface) > 0 ? google_compute_instance.replicated_cluster.network_interface[0].access_config[0].nat_ip : null
  instance_private_ip = length(google_compute_instance.replicated_cluster.network_interface) > 0 ? google_compute_instance.replicated_cluster.network_interface[0].network_ip : null
  instance_ip         = coalesce(local.instance_nat_ip, local.instance_private_ip)

  metadata = {
    # SSH configuration
    enable-oslogin = var.enable_os_login ? "TRUE" : "FALSE"

    # Cloud monitoring
    google-logging-enabled    = var.enable_cloud_logging ? "TRUE" : "FALSE"
    google-monitoring-enabled = var.enable_cloud_monitoring ? "TRUE" : "FALSE"

    # Replicated Embedded Cluster configuration
    replicated-app-slug     = var.replicated_app_slug
    replicated-channel-slug = var.replicated_channel_slug
    replicated-license-file = var.replicated_license_file

    # Cloud-init user data
    user-data = templatefile("${path.module}/cloud-init.yaml", {
      replicated_app_slug     = var.replicated_app_slug
      replicated_channel_slug = var.replicated_channel_slug
      replicated_license_file = var.replicated_license_file
    })
  }
}

# Compute Instance
resource "google_compute_instance" "replicated_cluster" {
  name         = var.goog_cm_deployment_name
  machine_type = var.machine_type
  zone         = var.zone

  tags = ["${var.goog_cm_deployment_name}-deployment"]

  boot_disk {
    initialize_params {
      image = var.source_image
      size  = var.boot_disk_size
      type  = var.boot_disk_type
    }
    auto_delete = true
  }

  dynamic "network_interface" {
    for_each = local.network_interfaces
    content {
      network    = network_interface.value.network
      subnetwork = network_interface.value.subnetwork

      dynamic "access_config" {
        for_each = network_interface.value.external_ip != "NONE" ? [1] : []
        content {
          nat_ip = network_interface.value.nat_ip
        }
      }
    }
  }

  metadata = local.metadata

  service_account {
    email  = var.service_account_email
    scopes = var.service_account_scopes
  }

  labels = {
    goog-dm = var.goog_cm_deployment_name
  }

  lifecycle {
    ignore_changes = [
      metadata["ssh-keys"]
    ]
  }
}

# Firewall rule for Embedded Cluster admin console (port 30000)
resource "google_compute_firewall" "admin_console" {
  count   = var.enable_admin_console ? 1 : 0
  name    = "${var.goog_cm_deployment_name}-tcp-30000"
  network = var.networks[0]

  allow {
    protocol = "tcp"
    ports    = ["30000"]
  }

  source_ranges = var.admin_console_source_ranges != "" ? split(",", var.admin_console_source_ranges) : ["0.0.0.0/0"]
  target_tags   = ["${var.goog_cm_deployment_name}-deployment"]
}

# Firewall rule for application HTTP traffic (port 80)
resource "google_compute_firewall" "http" {
  count   = var.enable_http ? 1 : 0
  name    = "${var.goog_cm_deployment_name}-tcp-80"
  network = var.networks[0]

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = var.http_source_ranges != "" ? split(",", var.http_source_ranges) : ["0.0.0.0/0"]
  target_tags   = ["${var.goog_cm_deployment_name}-deployment"]
}

# Firewall rule for application HTTPS traffic (port 443)
resource "google_compute_firewall" "https" {
  count   = var.enable_https ? 1 : 0
  name    = "${var.goog_cm_deployment_name}-tcp-443"
  network = var.networks[0]

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  source_ranges = var.https_source_ranges != "" ? split(",", var.https_source_ranges) : ["0.0.0.0/0"]
  target_tags   = ["${var.goog_cm_deployment_name}-deployment"]
}

# Firewall rule for Kubernetes API (port 6443)
resource "google_compute_firewall" "k8s_api" {
  count   = var.enable_k8s_api ? 1 : 0
  name    = "${var.goog_cm_deployment_name}-tcp-6443"
  network = var.networks[0]

  allow {
    protocol = "tcp"
    ports    = ["6443"]
  }

  source_ranges = var.k8s_api_source_ranges != "" ? split(",", var.k8s_api_source_ranges) : ["0.0.0.0/0"]
  target_tags   = ["${var.goog_cm_deployment_name}-deployment"]
}
