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

# Data source to get project information
data "google_project" "project" {
  project_id = var.project_id
}

locals {
  # Resolve the actual service account email (handle "default" case)
  actual_service_account_email = var.service_account_email == "default" ? "${data.google_project.project.number}-compute@developer.gserviceaccount.com" : var.service_account_email

  network_interfaces = [
    for i, network in var.networks : {
      network     = network
      subnetwork  = length(var.sub_networks) > i ? var.sub_networks[i] : null
      external_ip = length(var.external_ips) > i ? var.external_ips[i] : "NONE"
      nat_ip      = length(var.external_ips) > i && var.external_ips[i] != "NONE" && var.external_ips[i] != "EPHEMERAL" ? var.external_ips[i] : null
    }
  ]

  # Resolve the actual admin password (provided or generated)
  admin_password = var.admin_console_password != "" ? var.admin_console_password : random_password.admin_password[0].result

  # Primary controller metadata
  primary_controller_metadata = {
    # SSH configuration
    enable-oslogin = var.enable_os_login ? "TRUE" : "FALSE"

    # Cloud monitoring
    google-logging-enabled    = var.enable_cloud_logging ? "TRUE" : "FALSE"
    google-monitoring-enabled = var.enable_cloud_monitoring ? "TRUE" : "FALSE"

    # Replicated Embedded Cluster configuration
    replicated-app-slug     = var.replicated_app_slug
    replicated-channel-slug = var.replicated_channel_slug
    replicated-license-file = var.replicated_license_file

    # Cloud-init user data for primary controller
    user-data = templatefile("${path.module}/cloud-init-controller.yaml", {
      replicated_app_slug     = var.replicated_app_slug
      replicated_channel_slug = var.replicated_channel_slug
      replicated_license_file = var.replicated_license_file
      admin_console_password  = local.admin_password
      project_id              = var.project_id
      deployment_name         = var.goog_cm_deployment_name
    })
  }

  # Flatten worker pools for easier iteration
  worker_nodes = flatten([
    for pool in var.worker_pools : [
      for i in range(pool.count) : {
        pool_name    = pool.name
        index        = i
        machine_type = coalesce(pool.machine_type, var.machine_type)
        roles        = pool.roles
        name         = "${var.goog_cm_deployment_name}-${pool.name}-${i}"
      }
    ]
  ])

  # Primary controller IPs (for outputs and backward compatibility)
  primary_controller_nat_ip     = length(google_compute_instance.primary_controller.network_interface) > 0 && length(google_compute_instance.primary_controller.network_interface[0].access_config) > 0 ? google_compute_instance.primary_controller.network_interface[0].access_config[0].nat_ip : null
  primary_controller_private_ip = length(google_compute_instance.primary_controller.network_interface) > 0 ? google_compute_instance.primary_controller.network_interface[0].network_ip : null
  primary_controller_ip         = coalesce(local.primary_controller_nat_ip, local.primary_controller_private_ip)
}

# Generate random password if not provided by user
# Use only alphanumeric + safe special chars (no shell metacharacters)
resource "random_password" "admin_password" {
  count            = var.admin_console_password == "" ? 1 : 0
  length           = 25
  special          = true
  override_special = "-_."  # Only use safe characters that won't break shell scripts
}

# Secret Manager Secret for Admin Console Password
resource "google_secret_manager_secret" "admin_password" {
  project   = var.project_id
  secret_id = "${var.goog_cm_deployment_name}-admin-password"

  replication {
    auto {}
  }

  labels = {
    deployment = var.goog_cm_deployment_name
  }
}

# Store the password in Secret Manager (for users to retrieve later)
resource "google_secret_manager_secret_version" "admin_password" {
  secret      = google_secret_manager_secret.admin_password.id
  secret_data = local.admin_password
}

# Primary Controller (always exactly 1)
resource "google_compute_instance" "primary_controller" {
  name         = "${var.goog_cm_deployment_name}-controller-0"
  machine_type = var.machine_type
  zone         = var.zone

  tags = ["${var.goog_cm_deployment_name}-deployment", "${var.goog_cm_deployment_name}-controller"]

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

  metadata = local.primary_controller_metadata

  service_account {
    email  = var.service_account_email
    scopes = var.service_account_scopes
  }

  labels = {
    goog-dm = var.goog_cm_deployment_name
    role    = "controller"
  }

  # Ensure secret and password are stored before primary controller starts (for user retrieval)
  depends_on = [
    google_secret_manager_secret.admin_password,
    google_secret_manager_secret_version.admin_password
  ]

  lifecycle {
    ignore_changes = [
      metadata["ssh-keys"]
    ]
  }
}

# Additional Controller Nodes for HA (join as controller role)
resource "google_compute_instance" "additional_controllers" {
  count        = var.controller_count - 1
  name         = "${var.goog_cm_deployment_name}-controller-${count.index + 1}"
  machine_type = var.machine_type
  zone         = var.zone

  tags = ["${var.goog_cm_deployment_name}-deployment", "${var.goog_cm_deployment_name}-controller"]

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

  metadata = {
    # SSH configuration
    enable-oslogin = var.enable_os_login ? "TRUE" : "FALSE"

    # Cloud monitoring
    google-logging-enabled    = var.enable_cloud_logging ? "TRUE" : "FALSE"
    google-monitoring-enabled = var.enable_cloud_monitoring ? "TRUE" : "FALSE"

    # Cloud-init user data for joining as controller
    user-data = templatefile("${path.module}/cloud-init-node.yaml", {
      controller_url         = "https://${google_compute_instance.primary_controller.network_interface[0].network_ip}:30000"
      controller_ip          = google_compute_instance.primary_controller.network_interface[0].network_ip
      node_roles             = "controller"
      admin_console_password = local.admin_password
    })
  }

  service_account {
    email  = var.service_account_email
    scopes = var.service_account_scopes
  }

  labels = {
    goog-dm = var.goog_cm_deployment_name
    role    = "controller"
  }

  # Additional controllers depend on primary controller
  depends_on = [google_compute_instance.primary_controller]

  lifecycle {
    ignore_changes = [
      metadata["ssh-keys"]
    ]
  }
}

# Worker Nodes
resource "google_compute_instance" "workers" {
  for_each = { for idx, node in local.worker_nodes : node.name => node }

  name         = each.value.name
  machine_type = each.value.machine_type
  zone         = var.zone

  tags = ["${var.goog_cm_deployment_name}-deployment", "${var.goog_cm_deployment_name}-worker"]

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

  metadata = {
    # SSH configuration
    enable-oslogin = var.enable_os_login ? "TRUE" : "FALSE"

    # Cloud monitoring
    google-logging-enabled    = var.enable_cloud_logging ? "TRUE" : "FALSE"
    google-monitoring-enabled = var.enable_cloud_monitoring ? "TRUE" : "FALSE"

    # Cloud-init user data for joining as worker
    user-data = templatefile("${path.module}/cloud-init-node.yaml", {
      controller_url         = "https://${google_compute_instance.primary_controller.network_interface[0].network_ip}:30000"
      controller_ip          = google_compute_instance.primary_controller.network_interface[0].network_ip
      node_roles             = each.value.roles
      admin_console_password = local.admin_password
    })
  }

  service_account {
    email  = var.service_account_email
    scopes = var.service_account_scopes
  }

  labels = {
    goog-dm = var.goog_cm_deployment_name
    role    = "worker"
    pool    = each.value.pool_name
  }

  # Worker nodes depend on primary controller
  depends_on = [google_compute_instance.primary_controller]

  lifecycle {
    ignore_changes = [
      metadata["ssh-keys"]
    ]
  }
}

# Firewall rule for internal cluster communication
resource "google_compute_firewall" "cluster_internal" {
  count   = var.enable_internal_cluster_traffic ? 1 : 0
  name    = "${var.goog_cm_deployment_name}-cluster-internal"
  network = var.networks[0]

  allow {
    protocol = "tcp"
    ports    = ["2379-2380", "6443", "8132", "8888", "9443", "10250-10252", "30000"]
  }

  allow {
    protocol = "udp"
    ports    = ["8472"] # VXLAN for CNI
  }

  source_tags = ["${var.goog_cm_deployment_name}-deployment"]
  target_tags = ["${var.goog_cm_deployment_name}-deployment"]
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

# Firewall rule for application custom traffic (port 8888)
resource "google_compute_firewall" "custom_8888" {
  count   = var.enable_8888 ? 1 : 0
  name    = "${var.goog_cm_deployment_name}-tcp-8888"
  network = var.networks[0]

  allow {
    protocol = "tcp"
    ports    = ["8888"]
  }

  source_ranges = var.custom_8888_source_ranges != "" ? split(",", var.custom_8888_source_ranges) : ["0.0.0.0/0"]
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
