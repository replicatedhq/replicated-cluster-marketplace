# Replicated Embedded Cluster - GCP Marketplace

This Terraform module deploys a Replicated Embedded Cluster on Google Cloud Platform (GCP). Replicated Embedded Cluster is a Kubernetes distribution that allows you to package and deploy your application along with a complete Kubernetes cluster, providing a turnkey deployment experience.

## Features

- **Pre-configured Kubernetes cluster** - Complete k8s environment ready for your application
- **Multi-node support** - Deploy single-node or multi-node clusters with HA controllers and worker pools
- **Built-in admin console** - Web-based management interface accessible on port 30000
- **Automated updates** - Simplified application updates and rollback capabilities
- **Integrated monitoring** - Built-in diagnostics and troubleshooting tools
- **Flexible networking** - Support for public and private deployments
- **Configurable firewall rules** - Fine-grained control over network access

## Architecture

### Single-Node Deployment (Default)

The default deployment creates:
- Single GCP Compute Instance with Replicated Embedded Cluster pre-installed
- Built-in Kubernetes cluster for hosting your application
- Admin console for application management (port 30000)
- Configurable firewall rules for:
  - Admin console access (port 30000)
  - Application traffic (port 8888)
  - Optional Kubernetes API access (port 6443)
- Google Cloud Logging and Monitoring integration (optional)

### Multi-Node Deployment (Optional)

For high availability and scalability, you can deploy:
- **Primary Controller** - Bootstraps the cluster, runs `install` command
- **Additional Controllers** - Join as controller nodes for HA (e.g., 3 total for HA)
- **Worker Pools** - One or more pools of worker nodes with configurable roles and machine types
- **Password Distribution** - Simple HTTP server on primary controller for secure password sharing
- **Internal Firewall Rules** - Automatic configuration for cluster communication (etcd, Kubernetes API, CNI)

**Multi-Node Architecture:**
1. Primary controller initializes cluster and generates admin password
2. Password is served via internal HTTP server (port 8888)
3. Additional controllers and workers fetch password and join cluster
4. All nodes communicate via private network with firewall-protected ports

## How It Works

### Automated Installation with Cloud-Init

When the GCP instance boots for the first time, cloud-init automatically:

1. **Writes the license file** to `/etc/replicated/license.yaml`
2. **Generates a secure admin password** (25 characters, stored at `/var/lib/embedded-cluster/admin-console-password`)
3. **Runs the Embedded Cluster installer** from `/var/lib/marketplace-example/marketplace-example` with the provided license and password
4. **Logs the installation process** to `/var/log/embedded-cluster-install.log`

The installation typically takes 5-10 minutes. Once complete, your application is ready to use through the admin console on port 30000.

### Installation Command

The cloud-init script executes:
```bash
sudo /var/lib/marketplace-example/marketplace-example install \
  --license /etc/replicated/license.yaml \
  --admin-console-password "$AUTO_GENERATED_PASSWORD" \
  --airgap-bundle marketplace-example.airgap
```

## Prerequisites

1. **GCP Project** with appropriate permissions
2. **Terraform** >= 1.2 installed (for manual deployment)
3. **Replicated Account** with application slug and channel
4. **Replicated License File** (YAML format - required for installation)

The Embedded Cluster image (`marketplace-example-stable-ubuntu-24-04-lts`) is pre-configured in this marketplace offering and built from the [embedded-cluster-image](https://github.com/replicatedhq/replicated-cluster-marketplace/tree/main/embedded-cluster-image) repository.

## Quick Start

### 1. Clone this repository

```bash
git clone https://github.com/replicatedhq/replicated-cluster-marketplace.git
cd replicated-cluster-marketplace/gcp
```

### 2. Create terraform.tfvars

Copy the example file and customize it:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your values:

```hcl
project_id              = "your-gcp-project-id"
goog_cm_deployment_name = "replicated-cluster-prod"
zone                    = "us-central1-a"
machine_type            = "n2-standard-4"

replicated_app_slug     = "your-app-slug"
replicated_channel_slug = "stable"

# Provide your Replicated license file content (REQUIRED)
# Option 1: Inline YAML
replicated_license_file = <<-EOT
apiVersion: kots.io/v1beta1
kind: License
metadata:
  name: your-license
spec:
  # Your license content here
EOT

# Option 2: Load from file (comment out Option 1 if using this)
# replicated_license_file = file("path/to/your/license.yaml")
```

Alternatively, you can provide the license via command line:

```bash
# Pass license file content via command line
terraform apply -var "replicated_license_file=$(cat /path/to/license.yaml)"

# Or use Terraform's file function
terraform apply -var 'replicated_license_file=file("/path/to/license.yaml")'
```

> **Note:** The `source_image` is pre-configured for this marketplace offering and uses the image `marketplace-example-stable-ubuntu-24-04-lts` built from the [embedded-cluster-image](https://github.com/replicatedhq/replicated-cluster-marketplace/tree/main/embedded-cluster-image) repository.

### 3. Initialize and Deploy

```bash
terraform init
terraform plan
terraform apply
```

### 4. Access the Admin Console

After deployment completes, get the access information:

```bash
terraform output admin_console_url
terraform output ssh_command
```

SSH into the instance and retrieve the admin console password:

```bash
# SSH into the instance
$(terraform output -raw ssh_command)

# Get the admin console password
sudo cat /var/lib/embedded-cluster/admin-console-password
```

### 5. Monitor Installation

The Embedded Cluster installation runs automatically on first boot via cloud-init. You can monitor the installation progress:

```bash
# SSH into the instance
$(terraform output -raw ssh_command)

# Watch installation logs
sudo tail -f /var/log/embedded-cluster-install.log

# Check cloud-init status
cloud-init status --wait
```

### 6. Access Your Application

Once installation completes (typically 5-10 minutes):

1. Navigate to the admin console URL in your browser
2. Accept the self-signed certificate warning
3. Enter the admin console password (retrieved in step 4)
4. Your application will be pre-configured with your license
5. Complete any additional application-specific configuration
6. Your application is ready to use!

## Configuration

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `project_id` | GCP project ID | `"my-gcp-project"` |
| `goog_cm_deployment_name` | Deployment and VM instance name | `"replicated-prod"` |
| `replicated_app_slug` | Replicated application slug | `"my-app"` |
| `replicated_license_file` | Replicated license file content (YAML) | `file("license.yaml")` |

**Notes:**
- The source image (`marketplace-example-stable-ubuntu-24-04-lts`) is pre-configured for this marketplace offering and is not user-configurable.
- The admin console password is auto-generated during installation and stored at `/var/lib/embedded-cluster/admin-console-password`

### Common Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `zone` | GCP zone for deployment | `"us-central1-a"` |
| `machine_type` | VM machine type | `"n2-standard-4"` |
| `boot_disk_type` | Boot disk type | `"pd-balanced"` |
| `boot_disk_size` | Boot disk size in GB | `100` |
| `replicated_channel_slug` | Release channel | `"stable"` |
| `enable_cloud_logging` | Enable Cloud Logging | `true` |
| `enable_cloud_monitoring` | Enable Cloud Monitoring | `true` |

### Multi-Node Configuration Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `controller_count` | Total number of controller nodes (1 for single-node, 3 for HA) | `1` |
| `worker_pools` | List of worker node pools (see example below) | `[]` |
| `admin_console_password` | Admin console password (leave empty to auto-generate) | `""` |
| `enable_internal_cluster_traffic` | Enable firewall rules for internal cluster communication | `true` |

**Worker Pool Object Structure:**
```hcl
worker_pools = [
  {
    name         = "pool-name"      # Required: Pool name
    count        = 3                # Required: Number of nodes in pool
    machine_type = "n2-standard-8"  # Optional: Override default machine_type
    roles        = "worker"         # Optional: Node roles (default: "worker")
  }
]
```

### Networking Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `networks` | Network names | `["default"]` |
| `sub_networks` | Subnetwork names | `[]` |
| `external_ips` | External IP configuration | `["EPHEMERAL"]` |

### Firewall Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `enable_admin_console` | Enable admin console access (30000) | `true` |
| `admin_console_source_ranges` | CIDR ranges for admin console | `""` (0.0.0.0/0) |
| `enable_8888` | Enable application access (8888) | `true` |
| `custom_8888_source_ranges` | CIDR ranges for port 8888 | `""` (0.0.0.0/0) |
| `enable_k8s_api` | Enable Kubernetes API access (6443) | `false` |
| `k8s_api_source_ranges` | CIDR ranges for K8s API | `""` (0.0.0.0/0) |

## Outputs

| Output | Description |
|--------|-------------|
| `instance_name` | Name of the compute instance |
| `instance_nat_ip` | External IP address |
| `instance_private_ip` | Private IP address |
| `admin_console_url` | URL to access admin console |
| `application_url` | Application URL (port 8888) |
| `ssh_command` | Command to SSH into instance |
| `next_steps` | Post-deployment instructions |

## Deployment Scenarios

### Single-Node Deployment (Default)

```hcl
project_id              = "my-project"
goog_cm_deployment_name = "single-node"
zone                    = "us-central1-a"

controller_count = 1
worker_pools     = []

replicated_app_slug     = "my-app"
replicated_license_file = file("license.yaml")
```

### High Availability (3 Controllers)

```hcl
project_id              = "my-project"
goog_cm_deployment_name = "ha-cluster"
zone                    = "us-central1-a"
machine_type            = "n2-standard-8"

controller_count = 3
worker_pools     = []

replicated_app_slug     = "my-app"
replicated_license_file = file("license.yaml")

# Optional: provide password instead of auto-generating
admin_console_password = "my-secure-password"
```

### Multi-Node Cluster (3 Controllers + 5 Workers)

```hcl
project_id              = "my-project"
goog_cm_deployment_name = "multi-node"
zone                    = "us-central1-a"
machine_type            = "n2-standard-8"

controller_count = 3

worker_pools = [
  {
    name  = "general"
    count = 3
    roles = "worker"
  },
  {
    name         = "compute"
    count        = 2
    roles        = "worker"
    machine_type = "n2-highcpu-16"  # Override machine type for this pool
  }
]

replicated_app_slug     = "my-app"
replicated_license_file = file("license.yaml")
```

### Production Deployment

```hcl
machine_type                = "n2-standard-8"
boot_disk_type              = "pd-ssd"
boot_disk_size              = 200
enable_cloud_logging        = true
enable_cloud_monitoring     = true
admin_console_source_ranges = "203.0.113.0/24"  # Restrict to your office IP
enable_k8s_api              = false  # Disable unless needed
```

### Development Deployment

```hcl
machine_type           = "n2-standard-4"
boot_disk_type         = "pd-balanced"
boot_disk_size         = 100
enable_cloud_logging   = false
enable_cloud_monitoring = false
# Leave firewall rules open for easy access
```

### Private Deployment (No External IP)

```hcl
external_ips         = ["NONE"]
enable_admin_console = false  # Access via Cloud VPN or IAP
enable_8888          = false
```

## Machine Type Recommendations

| Use Case | Machine Type | vCPUs | Memory | Notes |
|----------|-------------|-------|--------|-------|
| Development/Testing | `n2-standard-4` | 4 | 16 GB | Minimum recommended |
| Production (Small) | `n2-standard-8` | 8 | 32 GB | Good for small workloads |
| Production (Medium) | `n2-standard-16` | 16 | 64 GB | Recommended for production |
| Production (Large) | `n2-standard-32` | 32 | 128 GB | High-performance workloads |

## Security Best Practices

1. **Restrict Admin Console Access**
   ```hcl
   admin_console_source_ranges = "203.0.113.0/24,198.51.100.0/24"
   ```

2. **Use Private Deployment** for sensitive workloads
   ```hcl
   external_ips = ["NONE"]
   ```

3. **Disable Kubernetes API** unless explicitly needed
   ```hcl
   enable_k8s_api = false
   ```

4. **Enable Cloud Logging and Monitoring**
   ```hcl
   enable_cloud_logging    = true
   enable_cloud_monitoring = true
   ```

5. **Use OS Login** for SSH access management
   ```hcl
   enable_os_login = true
   ```

6. **Regular Updates** - Keep your Embedded Cluster image up to date

## Troubleshooting

### Cannot Access Admin Console

1. Verify firewall rules:
   ```bash
   gcloud compute firewall-rules list --filter="name~${deployment_name}"
   ```

2. Check instance external IP:
   ```bash
   terraform output instance_nat_ip
   ```

3. Verify admin console is running:
   ```bash
   $(terraform output -raw ssh_command)
   sudo systemctl status embedded-cluster
   ```

### Instance Not Starting

1. Check instance status:
   ```bash
   gcloud compute instances describe $(terraform output -raw instance_name) \
     --zone=$(terraform output -raw instance_zone)
   ```

2. View serial port output:
   ```bash
   gcloud compute instances get-serial-port-output $(terraform output -raw instance_name) \
     --zone=$(terraform output -raw instance_zone)
   ```

### Application Not Accessible

1. Check application status in admin console
2. Verify firewall rules for port 8888
3. Check application logs:
   ```bash
   $(terraform output -raw ssh_command)
   sudo kubectl get pods -A
   sudo kubectl logs <pod-name> -n <namespace>
   ```

### Multi-Node Cluster Issues

#### Nodes Not Joining

1. Check join logs on worker/additional controller:
   ```bash
   gcloud compute ssh <node-name> --zone=<zone>
   sudo tail -f /var/log/embedded-cluster-join.log
   ```

2. Verify password server is running on primary controller:
   ```bash
   gcloud compute ssh <primary-controller> --zone=<zone>
   sudo tail -f /var/log/password-server.log
   ps aux | grep "python3 -m http.server 8888"
   ```

3. Test connectivity from worker to primary controller:
   ```bash
   # On worker node
   curl http://<primary-controller-ip>:8888/password
   ```

4. Check internal firewall rules:
   ```bash
   gcloud compute firewall-rules describe ${deployment_name}-cluster-internal
   ```

#### Verify Cluster State

```bash
# SSH to any controller
gcloud compute ssh <controller-name> --zone=<zone>

# Check all nodes
k0s kubectl get nodes -o wide

# Verify node roles
k0s kubectl get nodes --show-labels
```

## Customizing for Different Marketplace Offerings

This Terraform configuration is designed to be used with different Embedded Cluster images. Each marketplace offering will have its own pre-configured image.

### To create a new marketplace offering:

1. **Build your custom image** using the [embedded-cluster-image](https://github.com/replicatedhq/replicated-cluster-marketplace/tree/main/embedded-cluster-image) repository
   - Follow the build process to create a GCP image for your specific app/channel
   - Note the image name (e.g., `marketplace-example-stable-ubuntu-24-04-lts`)

2. **Update the source_image default** in `variables.tf`:
   ```hcl
   variable "source_image" {
     description = "The source image for the boot disk. This is pre-configured for this marketplace offering."
     type        = string
     default     = "projects/YOUR_PROJECT/global/images/YOUR_IMAGE_NAME"
   }
   ```

3. **Update replicated_app_slug default** (optional) in `variables.tf`:
   ```hcl
   variable "replicated_app_slug" {
     description = "The Replicated application slug"
     type        = string
     default     = "your-app-slug"  # Set your app slug as default
   }
   ```

4. **Test and validate** the configuration with your custom image

5. **Submit to GCP Marketplace** through Producer Portal

This approach allows you to maintain one Terraform codebase while creating multiple marketplace offerings for different applications or channels.

## Resources

- [Replicated Documentation](https://docs.replicated.com/)
- [Embedded Cluster Overview](https://docs.replicated.com/vendor/embedded-overview)
- [Embedded Cluster Image Builder](https://github.com/replicatedhq/replicated-cluster-marketplace/tree/main/embedded-cluster-image)
- [GCP Marketplace Tools](https://github.com/GoogleCloudPlatform/marketplace-tools)

## Support

For issues related to:
- **This Terraform module**: Open an issue in this repository
- **Replicated Embedded Cluster**: Contact Replicated support or visit [docs.replicated.com](https://docs.replicated.com/)
- **GCP Infrastructure**: Refer to [GCP documentation](https://cloud.google.com/docs)

## License

Copyright 2025 Replicated, Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
