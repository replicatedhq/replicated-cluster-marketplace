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

# Core GCP Configuration
variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "goog_cm_deployment_name" {
  description = "The name of the deployment and VM instance"
  type        = string
}

variable "zone" {
  description = "The GCP zone for the deployment"
  type        = string
  default     = "us-central1-a"
}

# Compute Instance Configuration
variable "machine_type" {
  description = "The machine type for the Replicated Embedded Cluster instance"
  type        = string
  default     = "n2-standard-4"
}

variable "source_image" {
  description = "The source image for the boot disk. This is pre-configured for this marketplace offering."
  type        = string
  default     = "projects/replicated-dev-environment/global/images/slackernews-mackerel-stable-ubuntu-24-04-lts"
}

variable "boot_disk_type" {
  description = "The boot disk type (pd-standard, pd-ssd, pd-balanced)"
  type        = string
  default     = "pd-balanced"
}

variable "boot_disk_size" {
  description = "The boot disk size in GB"
  type        = number
  default     = 100
  validation {
    condition     = var.boot_disk_size >= 50 && var.boot_disk_size <= 10000
    error_message = "Boot disk size must be between 50 and 10000 GB."
  }
}

# Network Configuration
variable "networks" {
  description = "The network names to attach the instance to"
  type        = list(string)
  default     = ["default"]
}

variable "sub_networks" {
  description = "The subnetwork names corresponding to the networks"
  type        = list(string)
  default     = []
}

variable "external_ips" {
  description = "The external IPs assigned to the instance. Can be EPHEMERAL, NONE, or a static IP address."
  type        = list(string)
  default     = ["EPHEMERAL"]
}

# Service Account Configuration
variable "service_account_email" {
  description = "Service account email to use for the instance"
  type        = string
  default     = "default"
}

variable "service_account_scopes" {
  description = "Service account scopes for the instance"
  type        = list(string)
  default = [
    "https://www.googleapis.com/auth/cloud-platform",
    "https://www.googleapis.com/auth/logging.write",
    "https://www.googleapis.com/auth/monitoring.write",
  ]
}

# Firewall Configuration - Admin Console
variable "enable_admin_console" {
  description = "Enable firewall rule for Embedded Cluster admin console (port 30000)"
  type        = bool
  default     = true
}

variable "admin_console_source_ranges" {
  description = "Source IP ranges that can access the admin console (comma-separated). Leave empty for 0.0.0.0/0"
  type        = string
  default     = ""
}

# Firewall Configuration - HTTP
variable "enable_http" {
  description = "Enable firewall rule for HTTP traffic (port 80)"
  type        = bool
  default     = true
}

variable "http_source_ranges" {
  description = "Source IP ranges for HTTP traffic (comma-separated). Leave empty for 0.0.0.0/0"
  type        = string
  default     = ""
}

# Firewall Configuration - HTTPS
variable "enable_https" {
  description = "Enable firewall rule for HTTPS traffic (port 443)"
  type        = bool
  default     = true
}

variable "https_source_ranges" {
  description = "Source IP ranges for HTTPS traffic (comma-separated). Leave empty for 0.0.0.0/0"
  type        = string
  default     = ""
}

# Firewall Configuration - Kubernetes API
variable "enable_k8s_api" {
  description = "Enable firewall rule for Kubernetes API (port 6443)"
  type        = bool
  default     = false
}

variable "k8s_api_source_ranges" {
  description = "Source IP ranges that can access the Kubernetes API (comma-separated). Leave empty for 0.0.0.0/0"
  type        = string
  default     = ""
}

# Cloud Operations
variable "enable_cloud_logging" {
  description = "Enable Google Cloud Logging"
  type        = bool
  default     = true
}

variable "enable_cloud_monitoring" {
  description = "Enable Google Cloud Monitoring"
  type        = bool
  default     = true
}

variable "enable_os_login" {
  description = "Enable OS Login for the instance"
  type        = bool
  default     = true
}

# Replicated Embedded Cluster Configuration
variable "replicated_app_slug" {
  description = "The Replicated application slug"
  type        = string
}

variable "replicated_channel_slug" {
  description = "The Replicated channel slug (e.g., stable, beta)"
  type        = string
  default     = "stable"
}

variable "replicated_license_file" {
  description = "The Replicated license file content (YAML format)"
  type        = string
  sensitive   = true
}

# Multi-Node Configuration
variable "controller_count" {
  description = "Total number of controller nodes (1 primary + N additional for HA). Set to 1 for single-node, 3 for HA."
  type        = number
  default     = 1
  validation {
    condition     = var.controller_count >= 1
    error_message = "Must have at least 1 controller node."
  }
}

variable "worker_pools" {
  description = "List of worker node pools. Each pool has: name, count, machine_type (optional), roles (optional, defaults to 'worker')"
  type = list(object({
    name         = string
    count        = number
    machine_type = optional(string)
    roles        = optional(string, "worker")
  }))
  default = []
  validation {
    condition     = alltrue([for pool in var.worker_pools : pool.count >= 1])
    error_message = "Each worker pool must have at least 1 node."
  }
}

variable "admin_console_password" {
  description = "Admin console password for KOTS. Leave empty to auto-generate on primary controller."
  type        = string
  sensitive   = true
  default     = ""
}

variable "enable_internal_cluster_traffic" {
  description = "Enable firewall rules for internal cluster communication between nodes"
  type        = bool
  default     = true
}
