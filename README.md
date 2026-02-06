# Replicated → Cloud Marketplace

Examples and tools to automate the creation of AWS, GCP, and Azure Cloud marketplace images. For now, requires [Replicated Embedded Cluster](https://docs.replicated.com/vendor/embedded-overview):

- **Image Builder** ([embedded-cluster-image/](./embedded-cluster-image/)) - Packer automation to create cloud images with your application
- **AWS Example** ([aws/](./aws/)) - CloudFormation + Lambda with automated licensing (based on SlackerNews)
- **GCP Templates** ([gcp/](./gcp/)) - Terraform module with marketplace metadata
- **Azure Templates** ([azure/](./azure/)) - Bicep modules with Portal UI definition

## Getting Started

### Prerequisites

1. **Replicated Account** at [vendor.replicated.com](https://vendor.replicated.com)
2. **Cloud Provider Access** (AWS, GCP, or Azure credentials)
3. **Tools**: Packer, Terraform/Azure CLI, make, jq, yq

### Basic Workflow

```bash
# 1. Build your cloud image
cd embedded-cluster-image
# Follow instructions in embedded-cluster-image/README.md
make ami:your-app/stable    # or gcp:your-app/stable

# 2. Deploy marketplace infrastructure
cd ../aws  # or gcp, azure
# Follow platform-specific README instructions
```

**→ See detailed guides in each subdirectory's README**

## Platform Comparison

| Feature | AWS | GCP | Azure |
|---------|-----|-----|-------|
| **Sample App** | SlackerNews | (placeholder) | (placeholder) |
| **Licensing** | Automated (Lambda + SNS) | Manual | Manual |
| **Multi-node** | Single-node | HA + Workers | HA + Workers |
| **Image Builder** | Packer | Packer | Not included |


## To Customize…

### AWS (SlackerNews Example)
Replace SlackerNews-specific references with your application name.

**→ [See aws/README.md for detailed steps](./aws/)**

### GCP (marketplace-example Placeholder)
Build image and set variables - no manual find/replace needed.

**→ [See gcp/README.md for detailed steps](./gcp/)**

### Azure (APPLICATION Placeholder)
Replace placeholders throughout Bicep templates.

**→ [See azure/README.md for detailed steps](./azure/)**


## Marketplace Submission

Each platform requires different artifacts. See platform-specific READMEs for detailed submission guides:

- **AWS**: AMI + CloudFormation + Product Load Form → [aws/README.md](./aws/)
- **GCP**: Image + Terraform + metadata.yaml → [gcp/README.md](./gcp/)  
- **Azure**: Image + Bicep + UI definition → [azure/README.md](./azure/)


## License

Copyright 2025 Replicated, Inc. Licensed under Apache License 2.0.

See [LICENSE](./LICENSE) for details.
