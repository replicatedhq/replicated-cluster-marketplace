# Replicated Embedded Cluster Image Generator

This project automates the creation of cloud images (AWS AMIs, vSphere OVAs, and GCP Compute Images) for Replicated Embedded Cluster applications. It simplifies the process of packaging and distributing Replicated applications across multiple cloud platforms, enabling seamless deployment of air-gapped installations.

## Overview

The image generator uses Packer to build customized images that include:

- A specific Replicated application and channel
- The Embedded Cluster components
- Cloud-init configuration for initial setup

This allows customers to easily launch instances with your Replicated application pre-installed and ready to run in an air-gapped environment.

## Usage

### Prerequisites

1. Infrastructure account with appropriate permissions (currently supports AWS,
   vSphere, and Google Cloud Platform)
2. Replicated vendor account and API token
3. Application configured in the Replicated vendor portal
4. `make`, `packer`, `jq`, and `yq`. For AWS, you will need the AWS CLI
   tools installed locally. For vSphere, you will need the `ovftool`. For GCP,
   you will need the `gcloud` CLI tools. Note: there is a `Brewfile` and a
   `shell.nix` to help you with these dependencies.

Note that there is not longer a Brew formulat for `ovftool` and the Nix
packager for `ovftool` does not install on MacOS with Apple Silicon. You will
have to [Download it from
Broadcom](https://developer.broadcom.com/tools/open-virtualization-format-ovf-tool/latest/)
and install it manually.

### Preparing Parameters

**Security Warning:** The `secrets/params.yaml` file will contain sensitive credentials in plain text. Ensure this file is included in `.gitignore` and never committed to version control. Set restrictive file permissions: `chmod 600 secrets/params.yaml`

1. Copy `secrets/REDACTED-params.yaml` to `secrets/params.yaml`
2. Update `params.yaml` with your AWS/vSphere/GCP and Replicated credentials:

```yaml
aws:
  access_key_id: YOUR_AWS_ACCESS_KEY
  secret_access_key: YOUR_AWS_SECRET_KEY
  regions: 
    - us-east-1
    - us-west-2

replicated:
  api_token: YOUR_REPLICATED_API_TOKEN

instance_type: t3.large
volume_size: 100
source_ami: ami-12345678

vsphere:
  server: vcenter.lab.shortrib.net
  username: administrator@vsphere.local
  password: REDACTED
  datacenter: <YOUR VSPHERE DATA CENTER>
  cluster: <A VSPHERE/VSAN CLUSTER>
  host: <AN ESXI HOST IN YOUR CLUSTER>
  resource_pool: <YOUR RESOURCE POOL>
  network: <YOUR VSPHERE NETWORK>
  datastore: <YOUR DATASTORE>

ssh:
    authorized_keys:
      - <YOUR SSH PUBLIC KEY(S)

gcp:
    project_id: your-gcp-project-id
    credentials_file: /path/to/service-account-key.json
    zone: us-central1-a
    source_image: ubuntu-2404-noble-amd64-v20260117
    machine_type: n2-standard-4
```

Note: For GCP, you'll need a service account with the following permissions:
- `roles/compute.instanceAdmin.v1`
- `roles/iam.serviceAccountUser`

### Generating an image

The Makefile dynamically generates targets based on your Replicated Vendor Portal applications and channels. To build an AMI for a specific application and channel:

```
make ami:APP_SLUG/CHANNEL_SLUG
```

to build an OVA

```
make ova:APP_SLUG/CHANNEL_SLUG
```

and to build a GCP image

```
make gcp:APP_SLUG/CHANNEL_SLUG
```

For example:

```
make ami:my-app/stable
```

To see all available targets:

```
make -qp | grep -E '^ami:'
make -qp | grep -E '^ova:'
make -qp | grep -E '^gcp:'
```

This will list all the dynamically generated `ami:APP_SLUG/CHANNEL_SLUG`,
`ova:APP_SLUG/CHANNEL_SLUG`, and `gcp:APP_SLUG/CHANNEL_SLUG` targets based on
your current Replicated Vendor Portal configuration.

## Components

- **Makefile**: Orchestrates the entire process, dynamically generating targets based on your Replicated applications and channels
- **Packer**: Defines the image configuration and build process for all platforms
- **Cloud-init**: Configures the instance on first boot, including Replicated application setup
- **Replicated Vendor Portal**: Provides application metadata and release artifacts
- **AWS**: Hosts the resulting AMIs and allows for multi-region distribution
- **vSphere**: Hosts the resulting OVA files
- **Google Cloud Platform**: Hosts the resulting Compute Images

## How It Works

1. The Makefile queries the Replicated Vendor Portal to get all applications and channels
2. It dynamically generates make targets for each application/channel combination
3. When a target is invoked, it generates a Packer variables file with the necessary configuration
4. Packer uses this configuration to launch an instance (EC2/VM/GCE) and customize it
5. Cloud-init scripts run on first boot to set up the Replicated application
6. Packer creates an image from the configured instance (AMI/OVA/GCP Compute Image)
7. For AMIs, they are shared to specified AWS regions and accounts. For OVAs,
   they are stored in the `work` directory. For GCP images, they are registered
   in your GCP project.

## Key Makefile Features

- **Dynamic Target Generation**: Automatically creates targets for all your Replicated applications and channels
- **Parameter Management**: Handles the creation and encryption of parameter files
- **Packer Integration**: Prepares variables for and executes Packer builds

## Resulting Images

The generated images are specifically tailored for running your Replicated application in an air-gapped environment. Key features of the images include:

- **Base OS**: Ubuntu 24.04 LTS
- **Pre-installed Components**:
  - Replicated Embedded Cluster
  - Your specific application (based on the chosen channel)
  - All necessary dependencies
- **Configuration**:
  - Cloud-init scripts for first-boot setup
  - Customized user data for Replicated application initialization
  - SSH hardening (custom sshd_config)
- **Default User**: A user named after your application slug
- **Volume**: Customized volume size (as specified in params.yaml)
- **Security**:
  - Root login disabled
  - SSH password authentication disabled
- **Distribution**:
  - AWS AMIs are replicated to all specified AWS regions
  - GCP images are registered in your GCP project and can be shared across projects
  - vSphere OVAs are stored locally in the `work` directory for distribution

These images allow your customers to quickly deploy your application in an
air-gapped environment with minimal additional configuration required. They are
designed to be secure, efficient, and ready for production use across AWS,
vSphere, and GCP platforms.

## Disclaimer

This project is provided as an example and is not officially supported by Replicated. Use at your own risk and adapt as needed for your specific requirements.
